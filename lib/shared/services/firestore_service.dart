import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hopital_model.dart';

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
}