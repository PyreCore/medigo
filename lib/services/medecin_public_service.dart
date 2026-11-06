import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/medecin.dart';

/// Fiche PUBLIQUE des médecins : la seule source de médecins pour les
/// visiteurs et les patients.
///
/// Pourquoi une collection à part : une règle Firestore autorise ou refuse
/// la lecture d'un document ENTIER, elle ne peut pas masquer un champ. Or
/// `medecins` et `users` contiennent l'email et le téléphone personnels du
/// médecin. Les rendre lisibles par un visiteur (ou par n'importe quel
/// compte patient, que chacun peut créer) exposait ces coordonnées à qui
/// interrogeait la base directement, même si l'application ne les affichait
/// pas.
///
/// `medecins_publics/{uid}` ne contient QUE [champsPublics] ; firestore.rules
/// refuse tout document qui porterait un autre champ. L'id du document est
/// l'uid du COMPTE du médecin, sous lequel sont rangées ses disponibilités
/// et ses créneaux occupés.
///
/// Elle est écrite par les administrateurs : à la création d'un médecin, à
/// sa suppression, et par [synchroniser] à l'ouverture des tableaux de bord
/// (rattrapage des médecins créés avant cette collection).
class MedecinPublicService {
  MedecinPublicService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const collection = 'medecins_publics';

  /// Les SEULS champs publiés. Toute modification doit être reportée dans
  /// la règle `medecins_publics` de firestore.rules (hasOnly).
  static const champs = ['nom', 'prenom', 'specialiteId', 'hopitalId'];

  /// Extrait la partie publique d'une fiche `medecins` : nom, prénom,
  /// spécialité, hôpital. Jamais l'email ni le téléphone.
  static Map<String, dynamic> champsPublics(Map<String, dynamic> medecin) => {
        for (final champ in champs) champ: (medecin[champ] ?? '').toString(),
      };

  /// Publie (ou met à jour) la fiche publique d'un médecin. [medecin] est
  /// la fiche `medecins` ; sans `userId`, rien n'est publié.
  ///
  /// Ne lève jamais d'exception : l'appel suit la création du compte du
  /// médecin dans un écran admin, qui ne doit pas échouer pour autant. Une
  /// fiche manquée est rattrapée par [synchroniser].
  Future<void> publier(Map<String, dynamic> medecin) async {
    final uid = (medecin['userId'] ?? '').toString();
    if (uid.isEmpty) return;
    try {
      await _db.collection(collection).doc(uid).set(champsPublics(medecin));
    } catch (e) {
      debugPrint('Publication medecins_publics/$uid impossible : $e');
    }
  }

  /// Retire la fiche publique d'un médecin supprimé.
  ///
  /// Ne lève jamais d'exception : la fiche peut ne pas exister (médecin
  /// créé avant medecins_publics), et la suppression du médecin, déjà faite,
  /// ne doit pas paraître échouer.
  Future<void> retirer(String? uid) async {
    if (uid == null || uid.isEmpty) return;
    try {
      await _db.collection(collection).doc(uid).delete();
    } catch (e) {
      debugPrint('Retrait medecins_publics/$uid impossible : $e');
    }
  }

  /// Republie les fiches `medecins` données. Appelé à l'ouverture des
  /// tableaux de bord admin, ce qui rattrape les médecins créés avant la
  /// collection publique.
  ///
  /// Ne lève jamais d'exception : un échec (règles pas encore déployées,
  /// réseau) ne doit pas casser le tableau de bord, il sera retenté à la
  /// prochaine ouverture.
  Future<void> synchroniser(Iterable<Map<String, dynamic>> medecins) async {
    try {
      // Firestore limite un lot à 500 écritures : on envoie par 400.
      var lot = _db.batch();
      var nombre = 0;
      for (final m in medecins) {
        final uid = (m['userId'] ?? '').toString();
        if (uid.isEmpty) continue;
        lot.set(_db.collection(collection).doc(uid), champsPublics(m));
        if (++nombre % 400 == 0) {
          await lot.commit();
          lot = _db.batch();
        }
      }
      if (nombre % 400 != 0) await lot.commit();
    } catch (e) {
      debugPrint('Synchronisation medecins_publics impossible : $e');
    }
  }

  /// Médecins d'un hôpital, lisibles sans compte. Un seul filtre
  /// d'égalité : aucun index composite n'est nécessaire.
  Future<List<Medecin>> getMedecins(String hopitalId) async {
    final snapshot = await _db
        .collection(collection)
        .where('hopitalId', isEqualTo: hopitalId)
        .get();
    final liste = snapshot.docs
        .map((doc) => Medecin.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
    liste.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    return liste;
  }
}
