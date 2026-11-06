import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'routage_role.dart';

/// Écran de connexion DÉDIÉ à l'administrateur système, servi uniquement
/// par le site admin (medigo-f2fd5-admin.web.app, point d'entrée
/// main_admin.dart).
///
/// Différences avec LoginScreen (le site public) :
/// 1. AUCUNE inscription : les comptes admin système sont créés depuis la
///    console, pas depuis un formulaire public.
/// 2. Toute autre connexion est REFUSÉE : patient, médecin, secrétaire,
///    admin hôpital qui saisiraient leurs identifiants ici sont
///    déconnectés (`signOut`) et reçoivent un message clair. Ce lien est
///    la porte d'entrée exclusivement dédiée à l'administrateur système.
/// 3. Si la session de ce navigateur contient déjà un compte non-admin
///    système (ouvert ailleurs), elle n'est pas réutilisée : seuls des
///    identifiants valides d'admin système ouvrent l'espace.
///
/// Même mécanismes que le site public : déconnexion au "retour" via
/// EspaceAvecRetourDeconnexion, écran bloqué sous 900 px via la garde
/// de ecranPourRole, lecture robuste du rôle via RoutageRole.lireRole.
class LoginAdminSystemeScreen extends StatefulWidget {
  const LoginAdminSystemeScreen({super.key});

  @override
  State<LoginAdminSystemeScreen> createState() =>
      _LoginAdminSystemeScreenState();
}

class _LoginAdminSystemeScreenState extends State<LoginAdminSystemeScreen> {
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
      final result = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Lecture ROBUSTE du rôle (tolère une espace parasite dans le nom
      // du champ Firestore) : cf. RoutageRole.lireRole.
      final role = await RoutageRole.lireRole(result.user!.uid);

      // Lien réservé à l'administrateur système : tout autre rôle est
      // déconnecté immédiatement. On ne affiche jamais quel rôle le
      // compte possède (pas d'information au visiteur).
      if (role != 'adminSysteme') {
        await _auth.signOut();
        if (!mounted) return;
        setState(() {
          _erreur = 'Ce lien est réservé à l\'administrateur système';
          _isLoading = false;
        });
        return;
      }

      final userDoc = await _db.collection('users').doc(result.user!.uid).get();
      final userData = userDoc.data() ?? const <String, dynamic>{};

      // Garde "ordinateur seul" (900 px) incluse : ecranPourRole renvoie
      // _AdminSystemeOrdinateurSeul pour ce rôle.
      final ecran = RoutageRole.ecranPourRole(role, userData);

      if (!mounted) return;
      if (ecran == null) {
        setState(() {
          _erreur = 'Aucun espace ne correspond à ce compte';
          _isLoading = false;
        });
        return;
      }

      // La connexion quitte la pile : on ne garde AUCUNE route derrière
      // (le formulaire est déjà validé, pas de "retour" utile ici).
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => EspaceAvecRetourDeconnexion(enfant: ecran),
        ),
        (route) => false,
      );
    } on FirebaseAuthException {
      // Message unique, comme sur le site public : on ne révèle pas si
      // l'email existe ("wrong-password" vs "user-not-found").
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
        title: const Text('Medigo — Espace Système'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            // Sur un grand écran, le formulaire ne s'étire pas sur toute
            // la largeur.
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Icon(Icons.admin_panel_settings_outlined,
                      size: 80, color: Color(0xFF6A1B9A)),
                  const SizedBox(height: 16),
                  const Text(
                    'Administration du système',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(() {
                          _obscurePassword = !_obscurePassword;
                        }),
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
                        backgroundColor: const Color(0xFF6A1B9A),
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Accéder à l\'espace système',
                              style: TextStyle(fontSize: 17),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Lien réservé à l\'administrateur système de Medigo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
