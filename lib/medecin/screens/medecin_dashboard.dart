import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MedecinDashboard extends StatefulWidget {
  const MedecinDashboard({super.key});

  @override
  State<MedecinDashboard> createState() => _MedecinDashboardState();
}

class _MedecinDashboardState extends State<MedecinDashboard> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _chargerProfil();
  }

  void _chargerProfil() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _userData = doc.data() as Map<String, dynamic>;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace Medecin'),
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
      body: _userData == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dr. ${_userData!['prenom'] ?? ''} ${_userData!['nom'] ?? ''}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text('Email: ${_userData!['email'] ?? ''}'),
                          Text('Hopital ID: ${_userData!['hopitalId'] ?? ''}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Mes rendez-vous', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Expanded(
                    child: Center(
                      child: Text('Aucun rendez-vous pour le moment'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
