import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'shared/screens/accueil_public_screen.dart';
import 'shared/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Rappels de rendez-vous : initialisés AVANT runApp pour que le premier
  // affichage de l'espace patient puisse déjà programmer les rappels. La
  // méthode n'échoue jamais (voir NotificationService.init).
  await NotificationService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medigo',
      theme: ThemeData(
        // Vert médical : c'est la couleur de l'accueil public, qui est
        // désormais le premier écran de l'application. Elle se distingue
        // du bleu de l'espace patient pour qu'on identifie d'un coup d'œil
        // dans quel espace on se trouve.
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
      ),
      // L'application s'ouvre sur l'accueil PUBLIC : un visiteur peut
      // découvrir Medigo (hôpitaux, spécialités) sans avoir de compte.
      // La connexion n'est demandée qu'au moment de réserver.
      initialRoute: '/',
      routes: {
        '/': (context) => const AccueilPublicScreen(),
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
