import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../admin/screens/admin_dashboard.dart';
import '../../adminHopital/screens/admin_hopital_dashboard.dart';
// Correction (Étudiant 2) : l'écran "medecin_dashboard.dart" n'existe pas
// dans le dépôt, il ne compile pas. L'écran d'entrée réel du médecin est
// MedecinHomeLoader (il charge le profil + les rendez-vous, puis affiche
// EspaceMedecin).
import '../../medecin/screens/medecin_home_loader.dart';
// Ajout (Étudiant 2) : le secrétaire avait AUCUNE branche dans ce switch —
// il tombait dans le "else" et ne pouvait jamais entrer dans son espace.
import '../../secretaire/screens/secretaire_home_loader.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _erreur;

  Future<void> _connecter() async {
    setState(() {
      _isLoading = true;
      _erreur = null;
    });

    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      DocumentSnapshot userDoc = await _db
          .collection('users')
          .doc(result.user!.uid)
          .get();

      if (!userDoc.exists) {
        setState(() {
          _erreur = 'Aucun profil trouve pour cet utilisateur';
          _isLoading = false;
        });
        return;
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      // 🔎 DEBUG — à SUPPRIMER avant la soutenance.
      // Affiche les données brutes du profil pour vérifier le rôle lu
      // (repère un éventuel espace parasite dans le nom du champ "role").
      print('DONNEES RECUES : ${userDoc.data()}');

      // Lecture ROBUSTE du rôle (Étudiant 2) :
      // - on tolère une espace parasite en FIN du nom du champ Firestore
      //   (le vrai champ s'appelle "role" mais une faute de frappe en
      //   ajouterait une espace invisible → userData['role'] vaudrait
      //   null et le rôle ne serait jamais reconnu) ;
      // - on trim() aussi la VALEUR pour la même raison.
      final cleRole = userData.keys.firstWhere(
        (cle) => cle.trim() == 'role',
        orElse: () => '',
      );
      String role = cleRole.isEmpty
          ? ''
          : (userData[cleRole] ?? '').toString().trim();

      if (!mounted) return;

      if (role == 'adminSysteme') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminSystemeDashboard(),
          ),
        );
      } else if (role == 'adminHopital') {
        String hopitalId = userData['hopitalId'] ?? '';
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminHopitalDashboard(hopitalId: hopitalId),
          ),
        );
      } else if (role == 'medecin') {
        // Correction (Étudiant 2) : MedecinDashboard n'existe pas →
        // redirection vers MedecinHomeLoader, la vraie entrée du médecin.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MedecinHomeLoader(),
          ),
        );
      } else if (role == 'secretaire') {
        // Ajout (Étudiant 2) : sans cette branche, un secrétaire voyait
        // « Vous n'avez pas les droits d'administration » et ne pouvait
        // pas tester l'espace secrétaire.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const SecretaireHomeLoader(),
          ),
        );
      } else {
        setState(() {
          _erreur = 'Vous n\'avez pas les droits d\'administration';
          _isLoading = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _erreur = 'Email ou mot de passe incorrect';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexion Admin'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.deepPurple),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            if (_erreur != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _erreur!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _connecter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Se connecter',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
