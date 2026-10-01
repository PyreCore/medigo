import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Le dispatch "rôle → écran" n'est plus écrit ici : il vit dans
// RoutageRole, que l'accueil public réutilise pour renvoyer un
// utilisateur déjà connecté vers le bon espace. Voir routage_role.dart.
import 'routage_role.dart';
import 'inscription_patient_loader.dart';

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

      // Lecture ROBUSTE du rôle : cf. RoutageRole.lireRole, qui tolère une
      // espace parasite en FIN du nom du champ Firestore et trim() la
      // valeur. On ne réimplémente pas cette logique ici.
      final role = await RoutageRole.lireRole(result.user!.uid);

      if (!mounted) return;

      final ecran = RoutageRole.ecranPourRole(role, userData);
      if (ecran == null) {
        setState(() {
          _erreur = 'Aucun espace ne correspond à ce compte';
          _isLoading = false;
        });
        return;
      }

      // pushAndRemoveUntil : après connexion, l'accueil public ne doit plus
      // rester dans la pile sous l'espace privé. Sinon le bouton "retour"
      // depuis l'espace patient renverrait vers un écran d'accueil qui, lui,
      // suppose encore qu'aucun espace n'est ouvert.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => ecran),
        (route) => false,
      );
    } on FirebaseAuthException {
      // On masque volontairement le détail de l'erreur (Firebase renvoie
      // "ERROR_INVALID_CREDENTIAL" en anglais) : message unique, plus sûr.
      setState(() {
        _erreur = 'Email ou mot de passe incorrect';
        _isLoading = false;
      });
    }
  }

  // Ouvre l'écran d'inscription. Navigator.push (et non pushReplacement)
  // car l'utilisateur doit pouvoir revenir à la connexion sans être
  // déconnecté.
  void _ouvrirInscription() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InscriptionPatientLoader()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Avant l'espace Patient, ce titre disait "Connexion Admin" alors
        // que le même écran servait déjà aux médecins et aux secrétaires.
        title: const Text('Medigo — Connexion'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        // SingleChildScrollView : la Column est centrée verticalement, ce
        // qui la rendait instable sur les petits écrans (dépassement). Le
        // scroll garantit que le bouton d'inscription reste atteignable.
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            const Icon(Icons.lock_outline, size: 80, color: Color(0xFF2E7D32)),
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
                  textAlign: TextAlign.center,
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
                  backgroundColor: const Color(0xFF2E7D32),
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
            const SizedBox(height: 8),
            // Ajout (espace Patient) : c'est le seul rôle qui s'inscrit
            // lui-même. Les comptes admin / médecin / secrétaire restent
            // créés par un admin (voir admin_dashboard.dart), il n'y a donc
            // pas d'équivalent de ce lien pour eux.
            TextButton.icon(
              onPressed: _ouvrirInscription,
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Créer un compte patient'),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
