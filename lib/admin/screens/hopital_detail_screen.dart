import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HopitalDetailScreen extends StatefulWidget {
  final String hopitalId;
  final String hopitalNom;

  const HopitalDetailScreen({super.key, required this.hopitalId, required this.hopitalNom});

  @override
  State<HopitalDetailScreen> createState() => _HopitalDetailScreenState();
}

class _HopitalDetailScreenState extends State<HopitalDetailScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hopitalNom),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _currentTab == 0 ? _buildMedecins() : _buildSpecialites(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
        selectedItemColor: Colors.deepPurple,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Medecins'),
          BottomNavigationBarItem(icon: Icon(Icons.star_outline), label: 'Specialites'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _currentTab == 0 ? _ajouterMedecin : _ajouterSpecialite,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildMedecins() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('medecins').where('hopitalId', isEqualTo: widget.hopitalId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('Aucun medecin dans cet hopital'));
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  child: Text(
                    '${(data['prenom'] ?? '')[0]}${(data['nom'] ?? '')[0]}'.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text('${data['prenom'] ?? ''} ${data['nom'] ?? ''}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email: ${data['email'] ?? ''}'),
                    _buildSpecialiteName(data['specialiteId'] ?? ''),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await _db.collection('medecins').doc(docs[index].id).delete();
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSpecialiteName(String specId) {
    if (specId.isEmpty) return const Text('Specialite: Non assignee');
    return FutureBuilder<DocumentSnapshot>(
      future: _db.collection('specialites').doc(specId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text('Specialite: ...');
        if (!snapshot.data!.exists) return const Text('Specialite: Inconnue');
        var data = snapshot.data!.data() as Map<String, dynamic>;
        return Text('Specialite: ${data['nom'] ?? ''}');
      },
    );
  }

  Widget _buildSpecialites() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('specialites').where('hopitalId', isEqualTo: widget.hopitalId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('Aucune specialite'));
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.star_outline, color: Colors.deepPurple),
                title: Text(data['nom'] ?? ''),
                subtitle: Text(data['description'] ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await _db.collection('specialites').doc(docs[index].id).delete();
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

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
            TextField(controller: nomController, decoration: const InputDecoration(labelText: 'Nom')),
            TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              await _db.collection('specialites').add({
                'nom': nomController.text,
                'description': descriptionController.text,
                'hopitalId': widget.hopitalId,
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _ajouterMedecin() {
    final nomController = TextEditingController();
    final prenomController = TextEditingController();
    final emailController = TextEditingController();
    final telephoneController = TextEditingController();
    final passwordController = TextEditingController(text: 'medico123');
    String? selectedSpecId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter un medecin'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: prenomController, decoration: const InputDecoration(labelText: 'Prenom')),
                TextField(controller: nomController, decoration: const InputDecoration(labelText: 'Nom')),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
                TextField(controller: telephoneController, decoration: const InputDecoration(labelText: 'Telephone')),
                TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Mot de passe')),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: _db.collection('specialites').where('hopitalId', isEqualTo: widget.hopitalId).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    var specs = snapshot.data!.docs;
                    return DropdownButtonFormField<String>(
                      value: selectedSpecId,
                      hint: const Text('Specialite'),
                      items: specs.map((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem(value: doc.id, child: Text(data['nom'] ?? ''));
                      }).toList(),
                      onChanged: (value) => setDialogState(() => selectedSpecId = value),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                try {
                  UserCredential result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                    email: emailController.text.trim(),
                    password: passwordController.text,
                  );

                  await _db.collection('users').doc(result.user!.uid).set({
                    'prenom': prenomController.text,
                    'nom': nomController.text,
                    'email': emailController.text.trim(),
                    'telephone': telephoneController.text,
                    'role': 'medecin',
                    'hopitalId': widget.hopitalId,
                    'specialiteId': selectedSpecId ?? '',
                  });

                  await _db.collection('medecins').add({
                    'prenom': prenomController.text,
                    'nom': nomController.text,
                    'email': emailController.text.trim(),
                    'telephone': telephoneController.text,
                    'specialiteId': selectedSpecId ?? '',
                    'hopitalId': widget.hopitalId,
                    'userId': result.user!.uid,
                  });

                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  debugPrint('Erreur: $e');
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}
