// On importe le package officiel qui permet de parler à Firestore
// (la base de données de Firebase) depuis Flutter.
import 'package:cloud_firestore/cloud_firestore.dart';
// Ajouté pour pouvoir récupérer l'uid de l'utilisateur actuellement
// connecté (FirebaseAuth.instance.currentUser), comme le fait déjà
// l'Étudiant 3 dans medecin_dashboard.dart.
import 'package:firebase_auth/firebase_auth.dart';
// On importe nos propres modèles, définis dans d'autres fichiers.
// Le chemin "../models/..." veut dire "remonte d'un dossier, puis va dans models".
import '../models/medecin.dart';
import '../models/rendez_vous.dart';
import 'creneau_service.dart';

/// Un "service" regroupe toute la logique qui va chercher/écrit des
/// données dans Firestore pour la partie Médecin. Les écrans (screens)
/// ne parlent jamais directement à Firestore : ils passent toujours
/// par ce service. Ça sépare "l'affichage" (screens) de "l'accès aux
/// données" (services), ce qui rend le code plus facile à maintenir.
class MedecinService {
  // On récupère l'instance unique de Firestore fournie par le SDK Firebase.
  // "_db" est privé (le underscore _ devant le nom) : utilisable seulement
  // à l'intérieur de cette classe, pas depuis l'extérieur.
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CreneauService _creneaux = CreneauService();

  // "Future<Medecin>" veut dire : cette fonction est ASYNCHRONE, elle
  // ne retourne pas un Medecin immédiatement (interroger Firestore prend
  // du temps, c'est une requête réseau), mais une "promesse" de Medecin
  // qui sera prête plus tard. "async" active le mot-clé "await" en dessous.
  //
  // Choix d'architecture aligné avec l'Étudiant 3 (17/09) : une SEULE
  // collection Firestore "users" regroupe tous les rôles (patient,
  // médecin, secrétaire...), chaque document étant identifié par l'uid
  // Firebase Auth. On ne garde donc plus de collection "medecins" à part.
  // Ce choix est provisoire tant que l'équipe ne l'a pas confirmé, mais
  // on s'aligne dessus pour rester compatible avec ce qui est déjà poussé.
  Future<Medecin> getProfil(String medecinId) async {
    // .collection('users') = LA collection unique pour tous les comptes.
    // .doc(medecinId) = ici, medecinId est en fait l'uid Firebase Auth
    // du médecin connecté (ex: FirebaseAuth.instance.currentUser!.uid).
    final doc = await _db.collection('users').doc(medecinId).get();

    // ".exists" est vrai si un document avec cet id existe réellement
    // dans Firestore (l'id pourrait être invalide/périmé).
    if (!doc.exists) {
      // "throw" déclenche une erreur qui remonte à l'écran appelant,
      // pour qu'il puisse par exemple afficher un message à l'utilisateur.
      throw Exception('Médecin introuvable');
    }

    // doc.data()! récupère le contenu du document sous forme de Map.
    // Le "!" dit à Dart "je suis sûr que ce n'est pas null, fais-moi confiance"
    // (on peut se le permettre ici car on vient de vérifier doc.exists).
    // "{'id': doc.id, ...doc.data()!}" construit un nouveau Map qui contient
    // l'id du document PLUS tous les champs du document (le "..." étale
    // le contenu d'un Map dans un autre, comme un copier-coller).
    // On passe ce Map à notre constructeur Medecin.fromJson vu plus tôt.
    return Medecin.fromJson({'id': doc.id, ...doc.data()!});
  }

  /// Raccourci pratique : récupère directement le profil du médecin
  /// ACTUELLEMENT CONNECTÉ, sans avoir à connaître son id à l'avance.
  /// Utile au démarrage de l'app, juste après la connexion.
  Future<Medecin> getProfilConnecte() async {
    // FirebaseAuth.instance.currentUser donne l'utilisateur Firebase
    // actuellement connecté sur cet appareil, ou null si personne n'est
    // connecté.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Aucun utilisateur connecté');
    }
    // "user.uid" est l'identifiant unique de ce compte, qui correspond
    // exactement à l'id du document dans la collection "users".
    return getProfil(user.uid);
  }

  /// Récupère les rendez-vous du médecin pour la date d'aujourd'hui,
  /// triés par heure.
  ///
  /// Le filtre sur la journée et le tri sont faits EN DART, pas par
  /// Firestore. Une requête "where(medecinId) + where(date >=) +
  /// where(date <) + orderBy(date)" exigerait un INDEX COMPOSITE créé
  /// à la main dans la console Firebase ; sans lui, Firestore renvoie
  /// l'erreur "cloud_firestore/failed-precondition : The query requires
  /// an index" et BLOQUE la connexion à l'espace médecin. Une requête
  /// à UN seul filtre d'égalité n'a besoin d'aucun index supplémentaire.
  Future<List<RendezVous>> getRendezVousDuJour(String medecinId) async {
    // "minuit aujourd'hui" (année/mois/jour seulement) et "minuit demain"
    // : l'intervalle [debut, fin[ couvre toute la journée.
    final debutJour = DateTime.now();
    final debut = DateTime(debutJour.year, debutJour.month, debutJour.day);
    final fin = debut.add(const Duration(days: 1));

    // Requête SIMPLE : un seul filtre d'égalité → aucun index à créer.
    final snapshot = await _db
        .collection('rendez_vous')
        // Chaque médecin ne voit que SES rendez-vous.
        .where('medecinId', isEqualTo: medecinId)
        .get();

    // CORBEILLE : les rendez-vous mis à la corbeille par le médecin
    // n'apparaissent plus dans ses listes normales. Filtre EN DART (et
    // non where('corbeilleMedecinLe', isNull: true)) pour garder une
    // requête à UN seul filtre d'égalité : un second filtre exigerait un
    // index composite, et son absence bloquait déjà la connexion
    // (failed-precondition, cf. le commentaire ci-dessus).
    final docsVisibles = snapshot.docs
        .where((doc) => doc.data()['corbeilleMedecinLe'] == null);

    // Conversion document → objet RendezVous ("traduction" des champs).
    final liste = docsVisibles.map((doc) {
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
      });
    }).toList();

    // Filtre de la journée [debut, fin[ fait en mémoire (le volume de
    // rendez-vous d'un médecin est faible : coût négligeable).
    final duJour = liste
        .where((rdv) => !rdv.date.isBefore(debut) && rdv.date.isBefore(fin))
        .toList();

    // Tri croissant (les plus tôt en premier) : l'équivalent de
    // l'ancien orderBy('date') exécuté côté Firestore.
    duJour.sort((a, b) => a.date.compareTo(b.date));
    return duJour;
  }

  /// Récupère tous les rendez-vous du médecin, TOUTES dates et TOUS
  /// statuts confondus, triés par date.
  ///
  /// Contrairement à getRendezVousDuJour, cette méthode ne filtre pas par
  /// date : elle retourne aussi les rendez-vous passés et futurs. C'est
  /// indispensable pour que le médecin voie les RDV confirmés par la
  /// secrétaire à des dates ultérieures.
  Future<List<RendezVous>> getTousRendezVous(String medecinId) async {
    final snapshot = await _db
        .collection('rendez_vous')
        .where('medecinId', isEqualTo: medecinId)
        .get();

    // CORBEILLE : idem getRendezVousDuJour — exclusion faite en DART
    // pour ne jamais dépendre d'un index composite.
    final docsVisibles = snapshot.docs
        .where((doc) => doc.data()['corbeilleMedecinLe'] == null);

    final liste = docsVisibles.map((doc) {
      final data = doc.data();
      return RendezVous.fromJson({
        'id': doc.id,
        'patient_nom': data['patientNom'],
        'patient_prenom': data['patientPrenom'],
        'date': (data['date'] as Timestamp).toDate().toIso8601String(),
        'heure': data['heure'],
        'statut': data['statut'],
        'motif': data['motif'],
      });
    }).toList();

    liste.sort((a, b) => a.date.compareTo(b.date));
    return liste;
  }

  /// Calcule quelques statistiques simples pour le tableau de bord.
  Future<Map<String, int>> getStatistiques(String medecinId) async {
    // On réutilise la fonction déjà écrite au-dessus plutôt que de
    // dupliquer la requête : moins de code, moins de bugs possibles.
    final rdvAujourdhui = await getRendezVousDuJour(medecinId);

    // Deuxième requête Firestore : tous les rendez-vous "en_attente"
    // de ce médecin, peu importe la date (pas de filtre sur "date" ici).
    final enAttenteSnapshot = await _db
        .collection('rendez_vous')
        .where('medecinId', isEqualTo: medecinId)
        .where('statut', isEqualTo: 'en_attente')
        .get();

    // Troisième requête : TOUS les rendez-vous de ce médecin (toutes dates,
    // tous statuts confondus), pour ensuite compter les patients distincts.
    final patientsSnapshot = await _db
        .collection('rendez_vous')
        .where('medecinId', isEqualTo: medecinId)
        .get();

    // .map() extrait juste le champ patientId de chaque document.
    // .toSet() transforme la liste en un "ensemble" : les doublons sont
    // automatiquement supprimés (un Set ne peut pas contenir 2 fois la
    // même valeur). .length compte combien il en reste : le nombre de
    // patients DIFFÉRENTS suivis par ce médecin.
    final patientsUniques = patientsSnapshot.docs
        .map((d) => d.data()['patientId'])
        .toSet()
        .length;

    // On retourne un Map (dictionnaire clé → valeur) avec les 3 chiffres
    // dont le tableau de bord a besoin.
    return {
      'rdvAujourdhui': rdvAujourdhui.length,
      'enAttente': enAttenteSnapshot.docs.length,
      'patientsSuivis': patientsUniques,
    };
  }

  /// Accepte un rendez-vous (change son statut).
  // "Future<void>" = fonction asynchrone qui ne renvoie aucune valeur utile,
  // elle fait juste une action (ici : modifier un document).
  Future<void> accepterRendezVous(String rdvId) async {
    // .update() modifie SEULEMENT les champs indiqués dans le Map,
    // sans toucher au reste du document (contrairement à .set() qui
    // remplacerait tout le document).
    await _db.collection('rendez_vous').doc(rdvId).update({
      'statut': 'confirme',
    });
  }

  /// Refuse un rendez-vous (change son statut).
  // "{String? motif}" = paramètre nommé optionnel : on peut appeler
  // refuserRendezVous('abc') seul, ou refuserRendezVous('abc', motif: '...').
  //
  // Le refus libère aussi le créneau : une heure refusée redevient
  // reservable par un autre patient.
  Future<void> refuserRendezVous(String rdvId, {String? motif}) async {
    await _db.collection('rendez_vous').doc(rdvId).update({
      'statut': 'refuse',
      'motifRefus': ?motif,
    });
    await _creneaux.liberer(rdvId);
  }

  // ─────────────────────────────────────────────────────────────────
  // AJOUTS (maquette — espaces Médecin/Secrétaire). Aucune méthode
  // existante n'est modifiée ni supprimée, les nouveaux paramètres
  // restent optionnels.
  // ─────────────────────────────────────────────────────────────────

  /// Termine la consultation d'un rendez-vous CONFIRMÉ (statut « termine »).
  ///
  /// Règles Firestore : un médecin ne peut updater que SES rendez-vous
  /// (resource.data.medecinId == uid), ce qui est le cas ici.
  /// Le créneau reste occupé : une consultation terminée est une
  /// archive, pas une heure de nouveau libre.
  Future<void> terminerRendezVous(String rdvId) async {
    await _db.collection('rendez_vous').doc(rdvId).update({
      'statut': 'termine',
    });
  }

  /// (AJOUT) Marque une consultation comme NON terminée.
  ///
  /// Arbitrage : l'enum StatutRendezVous (lib/models — hors périmètre)
  /// n'a que 5 valeurs et convertirait 'non_termine' en « en attente »
  /// partout. On écrit donc statut « termine » + booléen
  /// `consultationTerminee: false` à côté. Seul l'espace médecin
  /// affiche « Non terminé » (via getConsultationsNonTerminees) ;
  /// les autres espaces voient « Terminé », sans risque.
  Future<void> marquerConsultationNonTerminee(String rdvId) async {
    await _db.collection('rendez_vous').doc(rdvId).update({
      'statut': 'termine',
      'consultationTerminee': false,
    });
  }

  /// (AJOUT) Motif de refus d'un rendez-vous, pour la notification
  /// « RDV refusé » de l'espace médecin (point 4c).
  ///
  /// Lecture ciblée d'un SEUL document : le mapping de
  /// getTousRendezVous (inchangé) ne transporte pas motifRefus, et
  /// modifier cette méthode existante serait hors du périmètre
  /// « ajouts seuls ». Appelé uniquement lorsqu'un refus est détecté
  /// (événement rare) : une lecture Firestore de plus, pas une requête
  /// supplémentaire à chaque chargement.
  Future<String?> getMotifRefus(String rdvId) async {
    final doc = await _db.collection('rendez_vous').doc(rdvId).get();
    final motif = doc.data()?['motifRefus'];
    // Champ absent ou vide → null (le texte par défaut sera affiché).
    return (motif is String && motif.isNotEmpty) ? motif : null;
  }

  /// (AJOUT) Ids des consultations du médecin marquées « non terminées ».
  ///
  /// Requête à deux filtres d'égalité (medecinId + consultationTerminee)
  /// : servie par fusion d'index simples, sans index composite. Seuls
  /// les documents ÉCRITS explicitement avec consultationTerminee=false
  /// reviennent (les consultations normales n'ont pas ce champ).
  Future<Set<String>> getConsultationsNonTerminees(String medecinId) async {
    final snapshot = await _db
        .collection('rendez_vous')
        .where('medecinId', isEqualTo: medecinId)
        .where('consultationTerminee', isEqualTo: false)
        .get();
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  /// (AJOUT) Informations patient d'un rendez-vous, pour l'écran de
  /// détail : téléphone, date de naissance et groupe sanguin.
  ///
  /// Le document « rendez_vous » porte le champ "patientId" (id du
  /// dossier dans la collection "patients", cf. getStatistiques et
  /// SecretaireService.getPatientsPourHopital). On lit CE dossier (et
  /// non users/{uid} : les règles Firestore interdisent à un médecin de
  /// lire le profil users d'un patient).
  ///
  /// Renvoie null si le rendez-vous est introuvable ou s'il ne pointe
  /// vers aucun dossier patient ; l'écran affiche alors « Non
  /// renseigné » plutôt que de planter.
  Future<({String? telephone, DateTime? dateNaissance, String? groupeSanguin})?>
      getInfosPatientRendezVous(String rdvId) async {
    final rdvDoc = await _db.collection('rendez_vous').doc(rdvId).get();
    if (!rdvDoc.exists) return null;

    final patientId = (rdvDoc.data()!['patientId'] ?? '').toString();
    if (patientId.isEmpty) return null;

    final patientDoc = await _db.collection('patients').doc(patientId).get();
    if (!patientDoc.exists) return null;

    final data = patientDoc.data()!;
    final naissance = data['dateNaissance'];
    return (
      telephone: (data['telephone'] ?? '') as String?,
      dateNaissance: naissance is Timestamp ? naissance.toDate() : null,
      groupeSanguin: (data['groupeSanguin'] ?? '') as String?,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // CORBEILLE DU MÉDECIN (ajout) — indépendante de celle de la
  // secrétaire : chaque rôle porte SON champ (corbeilleMedecinLe /
  // corbeilleSecretaireLe), donc un rendez-vous peut être corbeillé par
  // l'un sans l'être par l'autre.
  //
  // Le médecin ne met à la corbeille que SES rendez-vous TERMINÉS (il
  // n'affiche déjà que confirmés et terminés). Même mécanique que
  // SecretaireService : Timestamp posé au serveur à la mise en
  // corbeille, retiré à la restauration, purges et exclusions sans
  // index composite (filtres Dart post-requête).
  // ─────────────────────────────────────────────────────────────────

  /// Statuts éligibles à la corbeille côté médecin : uniquement
  /// « termine » (les refusés/annulés sont gérés par la secrétaire et
  /// n'apparaissent pas dans ses listes).
  static const Set<String> statutsCorbeilleMedecin = {'termine'};

  /// (AJOUT) Traduit un document « rendez_vous » en objet RendezVous :
  /// exactement le mappage de getTousRendezVous, factorisé pour la
  /// corbeille (le modèle, hors périmètre, ignore les champs corbeille).
  static RendezVous _versRendezVous(String id, Map<String, dynamic> data) {
    return RendezVous.fromJson({
      'id': id,
      'patient_nom': data['patientNom'],
      'patient_prenom': data['patientPrenom'],
      'date': (data['date'] as Timestamp).toDate().toIso8601String(),
      'heure': data['heure'],
      'statut': data['statut'],
      'motif': data['motif'],
    });
  }

  /// (AJOUT) Contenu de la corbeille du médecin, avec la date de mise à
  /// la corbeille de chaque rendez-vous (du plus récent au plus
  /// ancien). Record structurel : le modèle ne transporte pas
  /// corbeilleMedecinLe (hors périmètre).
  Future<List<({RendezVous rdv, DateTime corbeilleLe})>> getCorbeille(
    String medecinId,
  ) async {
    final snapshot = await _db
        .collection('rendez_vous')
        .where('medecinId', isEqualTo: medecinId)
        .get();

    final entrees = <({RendezVous rdv, DateTime corbeilleLe})>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final corbeilleLe = data['corbeilleMedecinLe'];
      // Dans la corbeille = champ posé (Timestamp), absent = liste normale.
      if (corbeilleLe is! Timestamp) continue;
      entrees.add((
        rdv: _versRendezVous(doc.id, data),
        corbeilleLe: corbeilleLe.toDate(),
      ));
    }
    entrees.sort((a, b) => b.corbeilleLe.compareTo(a.corbeilleLe));
    return entrees;
  }

  /// (AJOUT) Met un rendez-vous TERMINÉ du médecin dans sa corbeille.
  ///
  /// Statut relu avant écriture (seul « termine » est éligible) ; la
  /// règle Firestore impose en plus que le document appartienne bien au
  /// médecin connecté (resource.data.medecinId == uid) — mise à jour et
  /// suppression refusées sinon.
  Future<void> mettreALaCorbeille(String rdvId) async {
    final doc = _db.collection('rendez_vous').doc(rdvId);
    final snapshot = await doc.get();
    final statut = snapshot.data()?['statut'];
    if (!statutsCorbeilleMedecin.contains(statut)) {
      throw StateError(
        'Seuls les rendez-vous terminés peuvent être mis à la '
        'corbeille (statut actuel : $statut).',
      );
    }
    await doc.update({'corbeilleMedecinLe': FieldValue.serverTimestamp()});
  }

  /// (AJOUT) Sort un rendez-vous de la corbeille du médecin : le champ
  /// est retiré (FieldValue.delete) et il réapparaît dans ses listes.
  Future<void> restaurer(String rdvId) async {
    await _db
        .collection('rendez_vous')
        .doc(rdvId)
        .update({'corbeilleMedecinLe': FieldValue.delete()});
  }

  /// (AJOUT) Suppression DÉFINITIVE du document (confirmation obligatoire
  /// dans l'écran avant l'appel).
  Future<void> supprimerDefinitivement(String rdvId) async {
    await _db.collection('rendez_vous').doc(rdvId).delete();
  }

  /// (AJOUT) Purge de la corbeille du médecin, appelée à l'ouverture de
  /// l'onglet : supprime les documents corbeillisés depuis PLUS de 30
  /// jours, SEULEMENT au statut « annule » ou « refuse » (la règle
  /// commune des deux corbeilles) — un « termine » reste en base pour
  /// l'historique patient.
  ///
  /// En pratique la corbeille du médecin ne contient que des
  /// « termine » : la méthode renverra0, elle existe pour respecter la
  /// règle commune et rester si le périmètre s'élargit un jour.
  Future<int> purgerCorbeille(String medecinId) async {
    final snapshot = await _db
        .collection('rendez_vous')
        .where('medecinId', isEqualTo: medecinId)
        .get();

    final limite = DateTime.now().subtract(const Duration(days: 30));
    final aSupprimer = <String>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final corbeilleLe = data['corbeilleMedecinLe'];
      if (corbeilleLe is! Timestamp) continue; // pas dans la corbeille
      if (corbeilleLe.toDate().isAfter(limite)) continue; // < 30 jours
      if (data['statut'] != 'annule' && data['statut'] != 'refuse') {
        continue; // « termine » reste en base (historique patient)
      }
      aSupprimer.add(doc.id);
    }

    // Lots de 400 : un batch Firestore plafonne à 500 opérations.
    const tailleLot = 400;
    for (var debut = 0; debut < aSupprimer.length; debut += tailleLot) {
      final batch = _db.batch();
      final fin = debut + tailleLot < aSupprimer.length
          ? debut + tailleLot
          : aSupprimer.length;
      for (var i = debut; i < fin; i++) {
        batch.delete(_db.collection('rendez_vous').doc(aSupprimer[i]));
      }
      await batch.commit();
    }
    return aSupprimer.length;
  }
}
