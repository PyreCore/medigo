import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/patient_service.dart';
import 'inscription_patient_screen.dart';
import '../../patient/screens/patient_home_loader.dart';

/// Écran "intermédiaire" de l'inscription : crée le compte puis affiche
/// InscriptionPatientScreen, qui lui ne fait que du formulaire. Même
/// découpage que MedecinHomeLoader / SecretaireHomeLoader : le loader parle à
/// Firebase Auth et Firestore, l'écran affiche.
///
/// Rien n'est chargé à l'ouverture : le formulaire ne demande plus d'hôpital,
/// il n'a donc besoin d'aucune donnée préalable.
class InscriptionPatientLoader extends StatefulWidget {
  const InscriptionPatientLoader({super.key});

  @override
  State<InscriptionPatientLoader> createState() =>
      _InscriptionPatientLoaderState();
}

class _InscriptionPatientLoaderState extends State<InscriptionPatientLoader> {
  final _service = PatientService();

  // Message d'erreur renvoyé par Firebase Auth, affiché par l'écran.
  String? _erreur;

  // Vrai pendant un envoi de formulaire, pour éviter un double clic
  // (deux inscriptions avec le même email en quelques secondes).
  bool _envoi = false;

  Future<void> _inscrire({
    required String nom,
    required String prenom,
    required String email,
    required String motDePasse,
    required String telephone,
    DateTime? dateNaissance,
    String? groupeSanguin,
  }) async {
    setState(() {
      _envoi = true;
      _erreur = null;
    });

    try {
      await _service.inscrire(
        nom: nom,
        prenom: prenom,
        email: email,
        motDePasse: motDePasse,
        telephone: telephone,
        dateNaissance: dateNaissance,
        groupeSanguin: groupeSanguin,
      );

      // createUserWithEmailAndPassword connecte l'utilisateur : on peut
      // enchaîner directement sur son espace, sans repasser par l'écran
      // de connexion. pushReplacement remplace l'inscription dans la pile
      // de navigation, pour que le bouton "retour" ne ramène pas à un
      // formulaire déjà validé.
      if (mounted) {
        setState(() => _envoi = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PatientHomeLoader()),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Erreurs d'authentification : on les traduit en français, car les
      // messages par défaut de Firebase sont en anglais et mentionnent des
      // codes techniques ("ERROR_EMAIL_ALREADY_IN_USE").
      setState(() {
        _erreur = _messageAuth(e);
        _envoi = false;
      });
    } catch (e) {
      setState(() {
        _erreur = 'Inscription impossible : $e';
        _envoi = false;
      });
    }
  }

  String _messageAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé par un autre compte';
      case 'invalid-email':
        return 'Cet email n\'est pas valide';
      case 'weak-password':
        return 'Mot de passe trop faible (6 caractères minimum)';
      case 'network-request-failed':
        return 'Pas de connexion internet, réessayez';
      default:
        return 'Inscription impossible (${e.code})';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InscriptionPatientScreen(
      erreur: _erreur,
      onValider: _envoi ? null : _inscrire,
    );
  }
}
