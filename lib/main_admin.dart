import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'shared/screens/login_screen.dart';

// Point d'entrée du site ADMIN (https://medigo-f2fd5-admin.web.app) :
// un second site Firebase Hosting, déployé depuis build/admin (voir
// firebase.json). Contrairement au site public (main.dart), il s'ouvre
// DIRECTEMENT sur l'écran de connexion : pas d'accueil public ici, ce
// lien est réservé à l'équipe (admin système, admin hôpital, médecin,
// secrétaire). L'écran de connexion route chaque rôle vers son espace
// (voir routage_role.dart), aucune duplication de logique.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Même si l'rappel de rendez-vous ne concerne que l'espace patient,
  // on l'initialise aussi ici : un médecin ou une secrétaire peut
  // manipuler des rendez-vous depuis son espace.
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
        // Violette : cohérente avec les espaces administrateurs
        // (voir theme/admin_theme.dart).
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6A1B9A)),
      ),
      // Le site admin s'ouvre sur la connexion : toute URL inconnue
      // (rafraîchissement de page, lien partagé) rebasculera dessus.
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
