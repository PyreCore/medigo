import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hopital_model.dart';
import '../../models/specialite.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Lire tous les hopitaux
  Future<List<Hopital>> getHopitaux() async {
    QuerySnapshot snapshot = await _db.collection('hopitaux').get();
    return snapshot.docs.map((doc) {
      return Hopital.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  // Ajouter un hopital
  Future<void> ajouterHopital(Hopital hopital) async {
    await _db.collection('hopitaux').add(hopital.toMap());
  }

  // Supprimer un hopital
  Future<void> supprimerHopital(String id) async {
    await _db.collection('hopitaux').doc(id).delete();
  }

  // Modifier un hopital
  Future<void> modifierHopital(String id, Hopital hopital) async {
    await _db.collection('hopitaux').doc(id).update(hopital.toMap());
  }

  /// Toutes les spécialités de tous les hôpitaux, pour l'accueil public.
  ///
  /// Contrairement à PatientService.getSpecialites (qui filtre sur un
  /// hopitalId), ici on veut la carte complète du catalogue telle qu'un
  /// visiteur non connecté peut la consulter. Aucun filtre "where" => aucun
  /// index composite requis. Les specialties sont triées par nom pour un
  /// affichage stable d'un lancement à l'autre (Firestore ne garantit aucun
  /// ordre sans orderBy).
  Future<List<Specialite>> getSpecialites() async {
    // Le paramètre de type est indispensable ici : sans lui le snapshot est
    // un QuerySnapshot<dynamic>, doc.data() vaut un Map<dynamic, dynamic> et
    // son étalement dans une map<String, dynamic> est refusé par l'analyseur.
    QuerySnapshot<Map<String, dynamic>> snapshot =
        await _db.collection('specialites').get();

    final liste = snapshot.docs
        .map((doc) => Specialite.fromJson({'id': doc.id, ...doc.data()}))
        .toList();

    liste.sort(
      (a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()),
    );
    return liste;
  }
}