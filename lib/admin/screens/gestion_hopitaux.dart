import 'package:flutter/material.dart';

import '../../shared/models/hopital_model.dart';
import '../../shared/services/firestore_service.dart';
import 'gestion_specialites.dart';

class GestionHopitaux extends StatefulWidget {
  const GestionHopitaux({super.key});

  @override
  State<GestionHopitaux> createState() => _GestionHopitauxState();
}

class _GestionHopitauxState extends State<GestionHopitaux> {
  final FirestoreService _firestoreService = FirestoreService();

  void _ajouterHopital() {
    final nomController = TextEditingController();
    final adresseController = TextEditingController();
    final telephoneController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un hopital'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomController, decoration: const InputDecoration(labelText: 'Nom')),
            TextField(controller: adresseController, decoration: const InputDecoration(labelText: 'Adresse')),
            TextField(controller: telephoneController, decoration: const InputDecoration(labelText: 'Telephone')),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Hopital hopital = Hopital(
                id: '', nom: nomController.text, adresse: adresseController.text,
                telephone: telephoneController.text, email: emailController.text,
              );
              await _firestoreService.ajouterHopital(hopital);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hopitaux'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Hopital>>(
        future: _firestoreService.getHopitaux(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          List<Hopital> hopitaux = snapshot.data ?? [];
          if (hopitaux.isEmpty) {
            return const Center(child: Text('Aucun hopital trouve'));
          }
          return ListView.builder(
            itemCount: hopitaux.length,
            itemBuilder: (context, index) {
              Hopital hopital = hopitaux[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GestionSpecialites(hopitalId: hopital.id, hopitalNom: hopital.nom),
                      ),
                    );
                  },
                  title: Text(hopital.nom),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hopital.adresse),
                      Text(hopital.email),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(hopital.telephone),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Supprimer cet hopital ?'),
                              content: Text('Voulez-vous supprimer ${hopital.nom} ?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Non')),
                                ElevatedButton(
                                  onPressed: () async {
                                    await _firestoreService.supprimerHopital(hopital.id);
                                    if (mounted) {
                                      Navigator.pop(context);
                                      setState(() {});
                                    }
                                  },
                                  child: const Text('Oui'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _ajouterHopital,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}