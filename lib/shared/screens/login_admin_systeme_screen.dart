import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/admin_theme.dart';
import 'routage_role.dart';

/// Écran de connexion DÉDIÉ à l'administrateur système, servi uniquement
/// par le site admin (medigo-f2fd5-admin.web.app, point d'entrée
/// main_admin.dart). Mise en page "console" inspirée des back-offices
/// modernes : panneau de marque à gauche (violet Medigo) + formulaire à
/// droite. Sur mobile (< 720 px), seul le formulaire occupe l'écran.
///
/// Comportement (identique à la première version) :
/// 1. AUCUNE inscription : les comptes admin système sont créés depuis
///    l'espace lui-même (ou la console), jamais depuis un formulaire public.
/// 2. Toute autre connexion est REFUSÉE : patient, médecin, secrétaire,
///    admin hôpital sont déconnectés (`signOut`) avec un message clair.
/// 3. Les mécanismes du site public sont conservés : déconnexion au
///    "retour" via EspaceAvecRetourDeconnexion, garde "ordinateur seul"
///    (< 900 px) de ecranPourRole, lecture robuste du rôle.
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
      // déconnecté immédiatement. On ne révèle jamais quel rôle possède
      // le compte (aucune information au visiteur).
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

  // ── Habillage "console deux panneaux" ───────────────────────────────

  static const _fondCreme = Color(0xFFFAF6F1);
  static const _champ = Color(0xFFF2EDE5);

  InputDecoration _decoChamp({
    required String libelle,
    required IconData icone,
    Widget? suffixe,
  }) {
    return InputDecoration(
      labelText: libelle,
      filled: true,
      fillColor: _champ,
      prefixIcon: Icon(icone, color: AdminCouleurs.violet),
      suffixIcon: suffixe,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(26),
        borderSide: const BorderSide(color: AdminCouleurs.violet, width: 1.8),
      ),
    );
  }

  Widget _panneauMarque() {
    return Container(
      color: const Color(0xFF2A1A3E),
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pastille de marque : cercle violet clair avec icône admin.
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              gradient: AdminCouleurs.degrade,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: Colors.white,
              size: 34,
            ),
          ),
          const Spacer(),
          const Text(
            'Medigo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Espace Administrateur système',
            style: TextStyle(
              color: Colors.purple.shade200,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 28),
          // Points forts de la console, comme Les back-offices modernes.
          _entreeSection(Icons.local_hospital_outlined, 'Hôpitaux & provinces'),
          const SizedBox(height: 14),
          _entreeSection(Icons.manage_accounts_outlined, 'Comptes admin hôpital'),
          const SizedBox(height: 14),
          _entreeSection(Icons.insights_outlined, 'Statistiques du système'),
        ],
      ),
    );
  }

  Widget _entreeSection(IconData icone, String texte) {
    return Row(
      children: [
        Icon(icone, color: Colors.purple.shade200, size: 20),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            texte,
            style: TextStyle(color: Colors.purple.shade100, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _formulaire(double largeurUtile) {
    return Container(
      color: _fondCreme,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Connexion',
              style: TextStyle(
                color: Colors.grey.shade900,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Accès réservé à l\'administrateur système.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _decoChamp(libelle: 'E-mail', icone: Icons.email_outlined),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: _decoChamp(
                libelle: 'Mot de passe',
                icone: Icons.lock_outline,
                suffixe: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: Colors.grey.shade500,
                  ),
                  onPressed: () => setState(() {
                    _obscurePassword = !_obscurePassword;
                  }),
                ),
              ),
            ),
            if (_erreur != null) ...[
              const SizedBox(height: 14),
              Text(
                _erreur!,
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _connecter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminCouleurs.violet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      )
                    : const Text(
                        'Se connecter',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined,
                    size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lien réservé à l\'administrateur système : '
                    'tout autre compte est refusé ici.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondCreme,
      appBar: AppBar(
        title: const Text('Medigo — Espace Système'),
        backgroundColor: const Color(0xFF2A1A3E),
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, contraintes) {
          if (contraintes.maxWidth >= 720) {
            // Ordinateur : deux panneaux, comme les consoles admin.
            return Row(
              children: [
                Expanded(flex: 5, child: _panneauMarque()),
                Expanded(flex: 7, child: _formulaire(contraintes.maxWidth * 7 / 12)),
              ],
            );
          }
          // Téléphone : le formulaire seul, avec une en-tête compacte.
          return ListView(
            children: [
              Container(
                color: const Color(0xFF2A1A3E),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        gradient: AdminCouleurs.degrade,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Medigo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Espace Administrateur système',
                      style: TextStyle(
                        color: Colors.purple.shade200,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _formulaire(contraintes.maxWidth),
            ],
          );
        },
      ),
    );
  }
}
