import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../admin/screens/admin_dashboard.dart';
import '../../adminHopital/screens/admin_hopital_dashboard.dart';
import '../../medecin/screens/medecin_home_loader.dart';
import '../../secretaire/screens/secretaire_home_loader.dart';
import '../../patient/screens/patient_home_loader.dart';

/// Dispatch centralisé "rôle Firestore → écran d'accueil du rôle".
///
/// Ce code vivait entièrement dans login_screen.dart. On l'a extrait ici
/// parce que la page d'accueil PUBLIQUE en a besoin elle aussi : quand un
/// visiteur non connecté clique sur « Prendre rendez-vous », l'application
/// doit le renvoyer vers la connexion, et une fois connecté le renvoyer vers
/// le bon espace — exactement comme après une saisie d'identifiants.
/// Sans cet extrait, les deux écrans entretiendraient deux listes de rôles
/// qui divergeraient à la première évolution.
class RoutageRole {
  RoutageRole._();

  /// Extrait le rôle du document "users" lié à [uid].
  ///
  /// La lecture du champ est ROBUSTE, comme elle l'était dans login_screen :
  /// on tolère une espace parasite en fin de NOM de champ (une faute de
  /// frappe à la saisie dans la console Firebase créerait "role " au lieu de
  /// "role", et `data['role']` vaudrait alors null) et on trim() la valeur.
  static Future<String> lireRole(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!doc.exists) return '';

    final data = doc.data() as Map<String, dynamic>;
    final cleRole = data.keys.firstWhere(
      (cle) => cle.trim() == 'role',
      orElse: () => '',
    );
    if (cleRole.isEmpty) return '';

    return (data[cleRole] ?? '').toString().trim();
  }

  /// Construit l'écran correspondant au rôle, ou renvoie null si le rôle est
  /// inconnu (message d'erreur à afficher par l'appelant).
  ///
  /// Les écrans "…HomeLoader" sont utilisés pour les rôles dont l'espace a
  /// besoin de données Firestore : le patient n'a pas d'écran d'entrée direct
  /// (son dossier et son catalogue sont chargés par PatientHomeLoader).
  static Widget? ecranPourRole(String role, Map<String, dynamic> userData) {
    switch (role) {
      case 'adminSysteme':
        return const AdminSystemeDashboard();
      case 'adminHopital':
        return AdminHopitalDashboard(hopitalId: userData['hopitalId'] ?? '');
      case 'medecin':
        return const MedecinHomeLoader();
      case 'secretaire':
        return const SecretaireHomeLoader();
      case 'patient':
        return const PatientHomeLoader();
      default:
        return null;
    }
  }

  /// Ouvre l'espace du rôle actuellement connecté, tel que lu dans la
  /// collection "users".
  ///
  /// Renvoie false si aucun compte n'est connecté ou si le rôle est
  /// inconnu — l'appelant affiche alors un message plutôt qu'un écran vide.
  static Future<bool> ouvrirEspaceConnecte(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // On rassemble les deux lectures AVANT de retoucher au context : chaque
    // await invalide la garantie que le widget soit encore monté, et il faut
    // donc un unique point de contrôle après le dernier d'entre eux.
    final role = await lireRole(user.uid);
    final userData = await _donneesProfil(user.uid);
    if (!context.mounted) return false;

    final ecran = ecranPourRole(role, userData);
    if (ecran == null) return false;

    // pushAndRemoveUntil : l'accueil public ne doit pas rester dans la pile
    // sous l'espace privé, sinon le bouton "retour" renverrait à un écran
    // qui suppose encore l'utilisateur connecté.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => ecran),
      (route) => false,
    );
    return true;
  }

  static Future<Map<String, dynamic>> _donneesProfil(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.data() ?? const <String, dynamic>{};
  }
}
