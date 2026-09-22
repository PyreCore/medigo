import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'hopital_detail_screen.dart';

class AdminSystemeDashboard extends StatefulWidget {
  const AdminSystemeDashboard({super.key});

  @override
  State<AdminSystemeDashboard> createState() => _AdminSystemeDashboardState();
}

class _AdminSystemeDashboardState extends State<AdminSystemeDashboard> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medigo - Admin Systeme'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: _currentTab == 0 ? _buildHopitaux() : _buildUtilisateurs(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
        selectedItemColor: Colors.deepPurple,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.local_hospital), label: 'Hopitaux'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Utilisateurs'),
        ],
      ),
    );
  }

  Widget _buildHopitaux() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _ajouterHopital,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un hopital'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('hopitaux').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('Aucun hopital'));
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  var docId = docs[index].id;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HopitalDetailScreen(hopitalId: docId, hopitalNom: data['nom'] ?? ''),
                          ),
                        );
                      },
                      leading: const Icon(Icons.local_hospital, color: Colors.deepPurple),
                      title: Text(data['nom'] ?? ''),
                      subtitle: Text(data['adresse'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _supprimerHopital(docId, data['nom']),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUtilisateurs() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _ajouterAdminHopital,
            icon: const Icon(Icons.person_add),
            label: const Text('Ajouter un admin d\'hopital'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('Aucun utilisateur'));
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  String role = data['role'] ?? '';
                  IconData icon;
                  Color color;
                  if (role == 'adminSysteme') {
                    icon = Icons.shield;
                    color = Colors.purple;
                  } else if (role == 'adminHopital') {
                    icon = Icons.local_hospital;
                    color = Colors.blue;
                  } else {
                    icon = Icons.person;
                    color = Colors.grey;
                  }
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: Icon(icon, color: color),
                      title: Text('${data['prenom'] ?? ''} ${data['nom'] ?? ''}'),
                      subtitle: Text('$role - ${data['email'] ?? ''}'),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

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
              await _db.collection('hopitaux').add({
                'nom': nomController.text,
                'adresse': adresseController.text,
                'telephone': telephoneController.text,
                'email': emailController.text,
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _ajouterAdminHopital() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nomController = TextEditingController();
    final prenomController = TextEditingController();
    String? selectedHopitalId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajouter un admin d\'hopital'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: prenomController, decoration: const InputDecoration(labelText: 'Prenom')),
                TextField(controller: nomController, decoration: const InputDecoration(labelText: 'Nom')),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
                TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Mot de passe'), obscureText: true),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: _db.collection('hopitaux').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    var hopitaux = snapshot.data!.docs;
                    return DropdownButtonFormField<String>(
                      value: selectedHopitalId,
                      hint: const Text('Choisir un hopital'),
                      items: hopitaux.map((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem(value: doc.id, child: Text(data['nom'] ?? ''));
                      }).toList(),
                      onChanged: (value) => setDialogState(() => selectedHopitalId = value),
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
                if (selectedHopitalId == null) return;
                try {
                  UserCredential result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                    email: emailController.text.trim(),
                    password: passwordController.text,
                  );
                  await _db.collection('users').doc(result.user!.uid).set({
                    'prenom': prenomController.text,
                    'nom': nomController.text,
                    'email': emailController.text.trim(),
                    'role': 'adminHopital',
                    'hopitalId': selectedHopitalId,
                  });
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  debugPrint('Erreur: $e');
                }
              },
              child: const Text('Creer'),
            ),
          ],
        ),
      ),
    );
  }

  void _supprimerHopital(String id, String nom) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet hopital ?'),
        content: Text('Voulez-vous supprimer $nom ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Non')),
          ElevatedButton(
            onPressed: () async {
              await _db.collection('hopitaux').doc(id).delete();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Oui'),
          ),
        ],
      ),
    );
  }
}
