import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'shared/screens/login_admin_systeme_screen.dart';

// Point d'entrée du site ADMIN (https://medigo-f2fd5-admin.web.app) :
// un second site Firebase Hosting, déployé depuis build/admin (voir
// firebase.json). Contrairement au site public (main.dart), il s'ouvre
// DIRECTEMENT sur UNE CONNEXION DÉDIÉE À L'ADMIN SYSTÈME : pas d'accueil
// public ici, ce lien est réservé à l'administrateur système. Tout
// autre rôle (même patient/médecin) qui saisirait ses identifiants ici
// est refusé et déconnecté — voir login_admin_systeme_screen.dart.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // L'rappel de rendez-vous reste initialisé sans condition ici :
  // NotificationService.init n'échoue jamais et l'espace admin système
  // consulte aussi des rendez-vous (tableau de bord).
  await NotificationService.instance.init();
  runApp(const MyAppAdmin());
}

class MyAppAdmin extends StatelessWidget {
  const MyAppAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medigo Admin',
      theme: ThemeData(
        // Thème VIOLETTE : cohérente avec les espaces administrateurs
        // (voir theme/admin_theme.dart).
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6A1B9A)),
      ),
      // Le site admin s'ouvre sur la CONNEXION DÉDIÉE admin système :
      // toute URL inconnue (rafraîchissement, lien partagé) y rebascule.
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginAdminSystemeScreen(),
        '/login': (context) => const LoginAdminSystemeScreen(),
      },
    );
  }
}
