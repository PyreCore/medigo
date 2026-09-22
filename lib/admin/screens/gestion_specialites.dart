import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GestionSpecialites extends StatefulWidget {
  final String hopitalId;
  final String hopitalNom;

  const GestionSpecialites({super.key, required this.hopitalId, required this.hopitalNom});

  @override
  State<GestionSpecialites> createState() => _GestionSpecialitesState();
}

class _GestionSpecialitesState extends State<GestionSpecialites> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void _ajouterSpecialite() {
    final nomController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter une specialite'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomController,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _db.collection('specialites').add({
                'nom': nomController.text,
                'description': descriptionController.text,
                'hopitalId': widget.hopitalId,
              });
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _supprimerSpecialite(String id) async {
    await _db.collection('specialites').doc(id).delete();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Specialites - ${widget.hopitalNom}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('specialites').where('hopitalId', isEqualTo: widget.hopitalId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Aucune specialite dans cet hopital'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var doc = docs[index];
              var data = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(data['nom'] ?? ''),
                  subtitle: Text(data['description'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _supprimerSpecialite(doc.id),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _ajouterSpecialite,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
