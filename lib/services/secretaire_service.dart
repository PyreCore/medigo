import 'package:cloud_firestore/cloud_firestore.dart';
// Ajouté pour récupérer l'uid de l'utilisateur actuellement connecté.
import 'package:firebase_auth/firebase_auth.dart';
import '../models/secretaire.dart';
import '../models/patient.dart';
import '../models/rendez_vous.dart';
import '../models/medecin.dart';

/// Service qui regroupe tout l'accès à Firestore pour la partie
/// Secrétaire. Même principe que MedecinService : les écrans ne parlent
/// jamais directement à Firestore, ils passent toujours par ce service.
class SecretaireService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
  Future<List<RendezVous>> getRendezVousDuJour(String hopitalId) async {
    final debutJour = DateTime.now();
    final debut = DateTime(debutJour.year, debutJour.month, debutJour.day);
    final fin = debut.add(const Duration(days: 1));

    final snapshot = await _db
        .collection('rendez_vous')
        // Différence clé avec MedecinService : on filtre par hopitalId,
        // pas par medecinId, pour voir TOUS les médecins de l'hôpital.
        .where('hopitalId', isEqualTo: hopitalId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(debut))
        .where('date', isLessThan: Timestamp.fromDate(fin))
        .orderBy('date')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return RendezVous.fromJson({
        'id': doc.id,
        'patient_nom': data['patientNom'],
        'patient_prenom': data['patientPrenom'],
        'date': (data['date'] as Timestamp).toDate().toIso8601String(),
        'heure': data['heure'],
        'statut': data['statut'],
        'motif': data['motif'],
        'medecin_id': data['medecinId'],
        'medecin_nom': data['medecinNom'],
        'hopital_id': data['hopitalId'],
      });
    }).toList();
  }

  /// Récupère tous les patients enregistrés dans cet hôpital.
  Future<List<Patient>> getPatients(String hopitalId) async {
    final snapshot = await _db
        .collection('patients')
        .where('hopitalId', isEqualTo: hopitalId)
        // Tri alphabétique par nom, pratique pour une longue liste.
        .orderBy('nom')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Patient.fromJson({
        'id': doc.id,
        'nom': data['nom'],
        'prenom': data['prenom'],
        'telephone': data['telephone'],
        'hopital_id': data['hopitalId'],
        // On ne convertit le Timestamp en texte ISO QUE s'il existe,
        // sinon Patient.fromJson recevrait un texte "null" invalide.
        'date_naissance': data['dateNaissance'] != null
            ? (data['dateNaissance'] as Timestamp).toDate().toIso8601String()
            : null,
        'groupe_sanguin': data['groupeSanguin'],
      });
    }).toList();
  }

  /// Calcule quelques statistiques simples pour le tableau de bord secrétaire.
  Future<Map<String, int>> getStatistiques(String hopitalId) async {
    final rdvAujourdhui = await getRendezVousDuJour(hopitalId);

    final enAttenteSnapshot = await _db
        .collection('rendez_vous')
        .where('hopitalId', isEqualTo: hopitalId)
        .where('statut', isEqualTo: 'en_attente')
        .get();

    final patientsSnapshot = await _db
        .collection('patients')
        .where('hopitalId', isEqualTo: hopitalId)
        .get();

    return {
      'rdvAujourdhui': rdvAujourdhui.length,
      'enAttente': enAttenteSnapshot.docs.length,
      // Pas besoin de compter les patients uniques ici : contrairement
      // au médecin (qui ne voit ses patients qu'à travers ses rendez-vous),
      // la secrétaire a une vraie collection "patients" à disposition.
      'totalPatients': patientsSnapshot.docs.length,
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
    await _db.collection('rendez_vous').add({
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
  }

  /// Confirme un rendez-vous (change son statut).
  Future<void> confirmerRendezVous(String rdvId) async {
    await _db.collection('rendez_vous').doc(rdvId).update({
      'statut': 'confirme',
    });
  }

  /// Annule un rendez-vous (change son statut).
  Future<void> annulerRendezVous(String rdvId, {String? motif}) async {
    await _db.collection('rendez_vous').doc(rdvId).update({
      'statut': 'annule',
      if (motif != null) 'motifAnnulation': motif,
    });
  }
}
