import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../medecin/screens/medecin_home_loader.dart';
import '../../secretaire/screens/secretaire_home_loader.dart';

/// Écran de connexion, point d'entrée de l'application (route '/login'
/// dans main.dart). Après une connexion réussie, on va chercher le champ
/// "role" du document utilisateur dans Firestore (collection "users",
/// voir la note d'architecture dans medecin_service.dart) et on redirige
/// vers l'espace correspondant.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controllerEmail = TextEditingController();
  final _controllerMotDePasse = TextEditingController();

  // "true" pendant qu'une tentative de connexion est en cours, pour
  // afficher un indicateur de chargement et désactiver le bouton
  // (évite que l'utilisateur clique plusieurs fois par impatience).
  bool _enCours = false;

  @override
  void dispose() {
    _controllerEmail.dispose();
    _controllerMotDePasse.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    if (_controllerEmail.text.trim().isEmpty ||
        _controllerMotDePasse.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci de renseigner email et mot de passe')),
      );
      return;
    }

    setState(() => _enCours = true);

    // "try/catch" : Firebase Auth lance une exception si les identifiants
    // sont invalides (mauvais mot de passe, compte inexistant...). On
    // "attrape" cette erreur pour afficher un message clair plutôt que
    // de laisser l'application planter.
    try {
      // Étape 1 : authentification via Firebase Auth.
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _controllerEmail.text.trim(),
            password: _controllerMotDePasse.text,
          );

      // Étape 2 : on va chercher le document Firestore correspondant à
      // cet utilisateur (même uid), pour connaître son rôle.
      final uid = credential.user!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        throw Exception('Profil utilisateur introuvable dans Firestore');
      }

      final role = doc.data()?['role'];

      // "if (!mounted) return;" : bonne pratique après un "await" dans
      // un State : vérifie que l'écran est toujours affiché avant de
      // naviguer (l'utilisateur pourrait avoir quitté l'écran entre
      // temps, ce qui provoquerait un crash sinon).
      if (!mounted) return;

      // Étape 3 : redirection selon le rôle. Navigator.pushReplacement
      // (et pas Navigator.push) remplace l'écran de connexion dans la
      // pile de navigation, pour qu'un retour arrière ne ramène pas
      // au formulaire de connexion.
      switch (role) {
        case 'medecin':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MedecinHomeLoader()),
          );
          break;
        case 'secretaire':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SecretaireHomeLoader()),
          );
          break;
        // TODO (équipe) : brancher ici les redirections vers les espaces
        // 'admin' et 'adminHopital' une fois leurs écrans principaux
        // identifiés (voir lib/admin/screens/ et lib/adminHopital/screens/).
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rôle non reconnu ou pas encore géré : $role')),
          );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connexion échouée : ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      // "finally" s'exécute TOUJOURS, que ça ait réussi ou échoué,
      // pour être sûr de désactiver l'indicateur de chargement.
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Medigo',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controllerEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controllerMotDePasse,
                obscureText: true, // masque le mot de passe à l'écran
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  // Si _enCours est vrai, onPressed vaut null : le bouton
                  // est automatiquement désactivé le temps de la requête.
                  onPressed: _enCours ? null : _seConnecter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _enCours
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Se connecter'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
