import 'package:cloud_firestore/cloud_firestore.dart';
// Ajouté pour récupérer l'uid de l'utilisateur actuellement connecté.
import 'package:firebase_auth/firebase_auth.dart';
import '../models/secretaire.dart';
import '../models/patient.dart';
import '../models/rendez_vous.dart';
import '../models/medecin.dart';
import 'creneau_service.dart';

/// Service qui regroupe tout l'accès à Firestore pour la partie
/// Secrétaire. Même principe que MedecinService : les écrans ne parlent
/// jamais directement à Firestore, ils passent toujours par ce service.
class SecretaireService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CreneauService _creneaux = CreneauService();

  /// Récupère le profil de la secrétaire connectée.
  //
  // Choix d'architecture aligné avec l'Étudiant 3 (17/09) : une SEULE
  // collection Firestore "users" regroupe tous les rôles, chaque document
  // étant identifié par l'uid Firebase Auth. Ce choix est provisoire tant
  // que l'équipe ne l'a pas confirmé, mais on s'aligne dessus pour rester
  // compatible avec ce qui est déjà poussé sur GitHub.
  Future<Secretaire> getProfil(String secretaireId) async {
    // secretaireId est en fait l'uid Firebase Auth de la secrétaire.
    final doc = await _db.collection('users').doc(secretaireId).get();

    if (!doc.exists) {
      throw Exception('Secrétaire introuvable');
    }

    return Secretaire.fromJson({'id': doc.id, ...doc.data()!});
  }

  /// Raccourci pratique : récupère directement le profil de la
  /// secrétaire ACTUELLEMENT CONNECTÉE, sans connaître son id à l'avance.
  Future<Secretaire> getProfilConnecte() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Aucun utilisateur connecté');
    }
    return getProfil(user.uid);
  }

  /// Récupère tous les médecins rattachés à cet hôpital, pour pouvoir
  /// les proposer dans le formulaire "Programmer un rendez-vous".
  Future<List<Medecin>> getMedecinsHopital(String hopitalId) async {
    // On interroge la MÊME collection "users" que pour le profil, mais
    // en filtrant sur role == 'medecin' ET hopitalId == cet hôpital.
    final snapshot = await _db
        .collection('users')
        .where('role', isEqualTo: 'medecin')
        .where('hopitalId', isEqualTo: hopitalId)
        .get();

    return snapshot.docs
        .map((doc) => Medecin.fromJson({'id': doc.id, ...doc.data()}))
        .toList();
  }

  /// Récupère tous les rendez-vous de l'hôpital (tous médecins confondus)
  /// pour la journée en cours, triés par heure.
  ///
  /// Filtre jour + tri effectués EN DART : voir l'explication détaillée
  /// dans MedecinService.getRendezVousDuJour. Une requête avec plage de
  /// dates + orderBy exigerait un index composite à créer dans la console
  /// Firebase, et son absence BLOQUE la connexion à l'espace secrétaire
  /// avec l'erreur "cloud_firestore/failed-precondition : The query
  /// requires an index".
  Future<List<RendezVous>> getRendezVousDuJour(String hopitalId) async {
    // "minuit aujourd'hui" et "minuit demain" : [debut, fin[ = la journée.
    final debutJour = DateTime.now();
    final debut = DateTime(debutJour.year, debutJour.month, debutJour.day);
    final fin = debut.add(const Duration(days: 1));

    // Requête SIMPLE : UN seul filtre d'égalité (hopitalId, et non
    // medecinId, pour voir TOUS les médecins de l'hôpital) → aucun
    // index composite requis, donc aucune erreur au démarrage.
    final snapshot = await _db
        .collection('rendez_vous')
        .where('hopitalId', isEqualTo: hopitalId)
        .get();

    final liste = snapshot.docs.map((doc) {
      final data = doc.data();
      return RendezVous.fromJson({
        'id': doc.id,
        'patient_nom': data['patientNom'],
        'patient_prenom': data['patientPrenom'],
        // Timestamp → DateTime → texte ISO, format lu par fromJson.
        'date': (data['date'] as Timestamp).toDate().toIso8601String(),
        'heure': data['heure'],
        'statut': data['statut'],
        'motif': data['motif'],
        'medecin_id': data['medecinId'],
        'medecin_nom': data['medecinNom'],
        'hopital_id': data['hopitalId'],
      });
    }).toList();

    // Filtre de la journée fait en mémoire : le nombre de rendez-vous
    // d'un hôpital reste faible, le coût est négligeable.
    final duJour = liste
        .where((rdv) => !rdv.date.isBefore(debut) && rdv.date.isBefore(fin))
        .toList();

    // Tri croissant par heure (l'équivalent de l'ancien orderBy('date')).
    duJour.sort((a, b) => a.date.compareTo(b.date));
    return duJour;
  }

  /// Récupère les patients que cette secrétaire doit voir.
  ///
  /// Deux origines, fusionnées et dédoublonnées :
  ///  1. les dossiers ouverts à SON guichet (`hopitalId` renseigné) ;
  ///  2. les patients ayant AU MOINS UN rendez-vous chez elle.
  ///
  /// Le 2e cas est indispensable : depuis que le patient choisit son
  /// hôpital au moment de réserver, un patient auto-inscrit n'est rattaché à
  /// aucun établissement. Le seul endroit où figure son hôpital est son
  /// rendez-vous — c'est donc par là qu'on le retrouve. Sans ce 2e cas, un
  /// patient pourrait s'inscrire, prendre rendez-vous, et rester invisible
  /// de toutes les secrétaires.
  Future<List<Patient>> getPatientsPourHopital(String hopitalId) async {
    // 1. Dossiers du guichet. UN seul filtre d'égalité = aucun index
    // composite requis. L'ancien .orderBy('nom') exigeait un index
    // patients(hopitalId, nom) créé à la main dans la console → erreur
    // failed-precondition qui bloquait le chargement de l'espace secrétaire
    // après le login.
    final snapshot = await _db
        .collection('patients')
        .where('hopitalId', isEqualTo: hopitalId)
        .get();

    // Indexé par id de document : c'est ce qui sert à dédoublonner ensuite.
    final parId = <String, Patient>{};
    for (final doc in snapshot.docs) {
      final patient = await _versPatient(doc);
      parId[doc.id] = patient;
    }

    // 2. Patients ayant un rendez-vous ici. On ne lit que le champ patientId
    // en pratique, mais cloud_firestore 6.10 n'expose pas de projection
    // ("select") sur une Query : la requête télécharge le document entier.
    // C'est le prix de S1, et il ne paie que sur les rendez-vous.
    final rdv = await _db
        .collection('rendez_vous')
        .where('hopitalId', isEqualTo: hopitalId)
        .get();

    // Un Set supprime les doublons : un patient avec 5 rendez-vous chez nous
    // n'est chargé qu'une fois.
    final idsRdv = <String>{};
    for (final doc in rdv.docs) {
      final id = (doc.data()['patientId'] ?? '').toString();
      if (id.isNotEmpty) idsRdv.add(id);
    }

    // On ne lit que les dossiers qu'on n'a pas déjà : un patient passé au
    // guichet ET ayant un rendez-vous ici ne coûte pas deux lectures.
    idsRdv.removeWhere(parId.containsKey);

    if (idsRdv.isNotEmpty) {
      // "whereIn" est plafonné à 30 valeurs par requête : au-delà on découpe
      // en lots successifs. Sans ce découpage, Firestore refuse la requête.
      const tailleLot = 30;
      final ids = idsRdv.toList();
      for (var debut = 0; debut < ids.length; debut += tailleLot) {
        final fin = (debut + tailleLot < ids.length) ? debut + tailleLot : ids.length;
        final lot = await _db
            .collection('patients')
            .where(FieldPath.documentId, whereIn: ids.sublist(debut, fin))
            .get();
        for (final doc in lot.docs) {
          parId[doc.id] = await _versPatient(doc);
        }
      }
    }

    final liste = parId.values.toList();

    // Tri alphabétique côté Dart, insensible à la casse
    // ("dupont" et "Dupont" sont classés ensemble).
    liste.sort(
      (a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()),
    );
    return liste;
  }

  /// Traduit un document de la collection "patients" en objet Patient.
  ///
  /// Commun à tous les chemins de lecture du service, pour qu'un dossier
  /// saisi au guichet et un dossier d'auto-inscrit soient construits
  /// exactement de la même façon.
  Future<Patient> _versPatient(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    return Patient.fromJson({
      'id': doc.id,
      'nom': data['nom'],
      'prenom': data['prenom'],
      'telephone': data['telephone'],
      // Absent pour une auto-inscription : reste null (cf. Patient.hopitalId).
      'hopital_id': data['hopitalId'],
      // Champs ajoutés par l'espace Patient : la secrétaire voit ainsi
      // l'email du patient et sait s'il possède déjà un compte connecté
      // (userId) ou s'il a seulement été enregistré à l'accueil.
      'email': data['email'],
      'user_id': data['userId'],
      // On ne convertit le Timestamp en texte ISO QUE s'il existe,
      // sinon Patient.fromJson recevrait un texte "null" invalide.
      'date_naissance': data['dateNaissance'] != null
          ? (data['dateNaissance'] as Timestamp).toDate().toIso8601String()
          : null,
      'groupe_sanguin': data['groupeSanguin'],
    });
  }

  /// Calcule quelques statistiques simples pour le tableau de bord secrétaire.
  ///
  /// 'totalPatients' n'est PAS calculé ici : le compter demanderait de
  ///charger toute la liste des patients, alors que l'appelant
  /// (SecretaireHomeLoader) la possède déjà pour alimenter l'onglet
  /// « Patients ». Il l'ajoute donc lui-même, ce qui nous fait une lecture
  /// Firestore de moins à chaque ouverture de l'espace.
  Future<Map<String, int>> getStatistiques(String hopitalId) async {
    final rdvAujourdhui = await getRendezVousDuJour(hopitalId);

    final enAttenteSnapshot = await _db
        .collection('rendez_vous')
        .where('hopitalId', isEqualTo: hopitalId)
        .where('statut', isEqualTo: 'en_attente')
        .get();

    return {
      'rdvAujourdhui': rdvAujourdhui.length,
      'enAttente': enAttenteSnapshot.docs.length,
    };
  }

  /// Enregistre un nouveau patient à l'accueil.
  // On reçoit les champs un par un (plutôt qu'un objet Patient déjà
  // construit) car au moment de l'enregistrement, on n'a pas encore
  // d'id : c'est Firestore qui va le générer automatiquement.
  Future<void> enregistrerPatient({
    required String nom,
    required String prenom,
    required String telephone,
    required String hopitalId,
    DateTime? dateNaissance,
    String? groupeSanguin,
  }) async {
    // .add() (au lieu de .doc(id).set()) crée un NOUVEAU document avec
    // un id généré automatiquement par Firestore, puisqu'on n'en a pas.
    await _db.collection('patients').add({
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'hopitalId': hopitalId,
      // On ne convertit en Timestamp que si une date a été fournie.
      if (dateNaissance != null)
        'dateNaissance': Timestamp.fromDate(dateNaissance),
      if (groupeSanguin != null) 'groupeSanguin': groupeSanguin,
    });
  }

  /// Programme un nouveau rendez-vous pour un patient avec un médecin.
  ///
  /// Comme PatientService, on écrit le rendez-vous PUIS son occupation de
  /// créneau : sans la seconde écriture, l'heure programmée au guichet
  /// resterait affichée comme disponible en ligne, et deux patients
  /// pourraient la prendre.
  Future<void> programmerRendezVous({
    required String patientId,
    required String patientNom,
    required String patientPrenom,
    required String medecinId,
    required String medecinNom,
    required String hopitalId,
    required DateTime date,
    required String heure,
    String? motif,
  }) async {
    final ref = await _db.collection('rendez_vous').add({
      'patientId': patientId,
      'patientNom': patientNom,
      'patientPrenom': patientPrenom,
      'medecinId': medecinId,
      'medecinNom': medecinNom,
      'hopitalId': hopitalId,
      'date': Timestamp.fromDate(date),
      'heure': heure,
      // Un rendez-vous programmé par la secrétaire démarre "en_attente",
      // comme quand un patient le prend lui-même : c'est ensuite confirmé.
      'statut': 'en_attente',
      if (motif != null) 'motif': motif,
    });

    await _creneaux.reserver(
      rdvId: ref.id,
      medecinId: medecinId,
      date: date,
      heure: heure,
    );
  }

  /// Confirme un rendez-vous (change son statut).
  Future<void> confirmerRendezVous(String rdvId) async {
    await _db.collection('rendez_vous').doc(rdvId).update({
      'statut': 'confirme',
    });
  }

  /// Annule un rendez-vous (change son statut).
  ///
  /// Libère aussi le créneau, sinon l'heure annulée au guichet resterait
  /// masquée pour les patients en ligne.
  Future<void> annulerRendezVous(String rdvId, {String? motif}) async {
    await _db.collection('rendez_vous').doc(rdvId).update({
      'statut': 'annule',
      if (motif != null) 'motifAnnulation': motif,
    });
    await _creneaux.liberer(rdvId);
  }
}
