// ─────────────────────────────────────────────────────────────────────
// CAPTURES D'ÉCRAN — accueil médecin redessiné (hors suite `flutter test`).
//
// Rend AccueilMedecin à 360 / 600 / 900 / 1280 px (+ variante vide) et
// écrit les PNG dans tool/captures/goldens/. Ce fichier vit hors test/
// volontairement : un golden est lié aux polices de la machine qui l'a
// généré, il ne doit pas figer la suite de tests de l'équipe.
//
// Utilisation :
//   flutter test tool/captures/accueil_medecin_capture_test.dart --update-goldens
//
// Le même fichier sert aussi de vérification « sans erreur rouge » :
// toute exception de layout pendant le rendu fait échouer le test.
// ─────────────────────────────────────────────────────────────────────
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopital_app/medecin/screens/accueil_medecin.dart';
import 'package:hopital_app/models/medecin.dart';
import 'package:hopital_app/models/rendez_vous.dart';
import 'package:hopital_app/theme/maquette_tokens.dart';

/// Charge des polices RÉELLES pour que le PNG affiche du texte lisible :
/// dans un test, Flutter utilise sinon la police « Ahem » (des
/// rectangles à la place des lettres).
Future<void> _chargerPolices() async {
  // Roboto — la police RÉELLE de l'app (fournie par le SDK Flutter) :
  // métriques fidèles au rendu Android/web. Repli : DejaVu (système).
  // Sans ces polices, Flutter rend les tests avec « Ahem » : des
  // rectangles à la place des lettres.
  const roboto =
      '/home/ideal/flutter/bin/cache/dart-sdk/bin/resources/devtools/'
      'assets/fonts/Roboto';
  const dejavu = '/usr/share/fonts/truetype/dejavu';

  final candidats = [
    (
      '$roboto/Roboto-Regular.ttf',
      ['$roboto/Roboto-Medium.ttf', '$roboto/Roboto-Bold.ttf'],
    ),
    (
      '$dejavu/DejaVuSans.ttf',
      ['$dejavu/DejaVuSans-Bold.ttf'],
    ),
  ];

  for (final (principal, suite) in candidats) {
    final premier = File(principal);
    if (!premier.existsSync()) continue;
    final chargeur = FontLoader('Preview');
    chargeur.addFont(_octets(premier));
    for (final chemin in suite) {
      final fichier = File(chemin);
      if (fichier.existsSync()) chargeur.addFont(_octets(fichier));
    }
    await chargeur.load();
    break;
  }

  // Icônes Material (cloche, chevron) : la famille que Icons attend.
  final icones = File('build/flutter_assets/fonts/MaterialIcons-Regular.otf');
  if (icones.existsSync()) {
    final chargeur = FontLoader('MaterialIcons');
    chargeur.addFont(_octets(icones));
    await chargeur.load();
  }
}

Future<ByteData> _octets(File fichier) async {
  final data = await fichier.readAsBytes();
  return ByteData.view(data.buffer, data.offsetInBytes, data.length);
}

Medecin _medecin() => Medecin(
      id: 'm1',
      nom: 'Obame',
      prenom: 'Sarah',
      specialite: 'Cardiologie',
      hopitalId: 'h1',
      hopitalNom: 'CHU de Libreville',
    );

RendezVous _rdv({
  required String id,
  required DateTime date,
  required String heure,
  required String statut,
  required String patientNom,
  required String patientPrenom,
  String? motif,
}) =>
    RendezVous.fromJson({
      'id': id,
      'patient_nom': patientNom,
      'patient_prenom': patientPrenom,
      'date': date.toIso8601String(),
      'heure': heure,
      'statut': statut,
      'motif': motif,
    });

/// Données de capture stables : 3 rendez-vous du matin (passés) +
/// 1 rendez-vous du jour à 23:59, qui est toujours le premier de la
/// liste et toujours « à venir » (héros), quelle que soit l'heure
/// d'exécution — sauf la dernière minute de la journée.
///
/// Remarques de reproductibilité :
///  - l'heure du héros est FIXE (« 23:59 ») : le libellé de la pastille
///    ne dépend plus de la minute d'exécution ;
///  - l'en-tête affiche la date du jour (dateDuJour()) et le compteur
///    « À venir » s'appuie sur DateTime.now() : un golden est donc
///    valable pour la journée de sa génération — régénérer avec
///    --update-goldens juste avant un envoi.
List<RendezVous> _rendezVous() {
  final maintenant = DateTime.now();
  final jour = DateTime(maintenant.year, maintenant.month, maintenant.day);
  return [
    // Héros : heure FIXE (et non now + 2 h) pour un golden stable à la
    // minute près ; date = aujourd'hui pour rester dans la section
    // « Rendez-vous d'aujourd'hui ».
    _rdv(
      id: 'p1',
      date: jour,
      heure: '23:59',
      statut: 'confirme',
      patientNom: 'Mba',
      patientPrenom: 'Alice',
      motif: 'Contrôle tensionnel',
    ),
    _rdv(
      id: 'j1',
      date: jour,
      heure: '07:30',
      statut: 'confirme',
      patientNom: 'Ndong',
      patientPrenom: 'Paul',
      motif: 'Douleurs lombaires',
    ),
    _rdv(
      id: 'j2',
      date: jour,
      heure: '08:15',
      statut: 'termine',
      patientNom: 'Ondo',
      patientPrenom: 'Jeanne',
      motif: 'Suivi diabète',
    ),
    _rdv(
      id: 'j3',
      date: jour,
      heure: '08:45',
      statut: 'confirme',
      patientNom: 'Owono',
      patientPrenom: 'Marc',
      motif: 'Bilan annuel',
    ),
  ];
}

/// Construit l'écran (variantes : liste par défaut, ou vide).
Widget _ecran({List<RendezVous>? liste}) => AccueilMedecin(
      medecin: _medecin(),
      rendezVousDuJour: liste ?? _rendezVous(),
      patientsSuivis: 128,
      idsNonTermines: {'j2'}, // la pastille « Non terminé »
      onVoirTout: () {},
      onVoirPlanning: () {},
      onTapRendezVous: (_) {},
      onRafraichir: () async {},
    );

/// Rend [enfant] à la taille demandée et écrit le golden [fichier].
Future<void> _capturer(
  WidgetTester tester, {
  required double largeur,
  required double hauteur,
  required String fichier,
  required Widget enfant,
}) async {
  tester.view.physicalSize = Size(largeur, hauteur);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Preview'),
      home: Scaffold(
        backgroundColor: MaquetteCouleurs.fond,
        body: enfant,
      ),
    ),
  );

  // On avance la pendule de test : délais d'Apparition (0 → 460 ms) puis
  // animation des compteurs (600 ms). Sans cela, le capture serait prise
  // pendant le fondu (contenu encore transparent).
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();

  expect(
    tester.takeException(),
    isNull,
    reason: 'erreur de layout à $largeur px',
  );
  await expectLater(
    find.byType(Scaffold),
    matchesGoldenFile(fichier),
  );
}

void main() {
  setUpAll(_chargerPolices);

  testWidgets('accueil médecin — 360 px (mobile étroit)', (tester) async {
    await _capturer(
      tester,
      largeur: 360,
      hauteur: 780,
      fichier: 'goldens/accueil_medecin_360.png',
      enfant: _ecran(),
    );
  });

  testWidgets('accueil médecin — 600 px (tablette)', (tester) async {
    await _capturer(
      tester,
      largeur: 600,
      hauteur: 900,
      fichier: 'goldens/accueil_medecin_600.png',
      enfant: _ecran(),
    );
  });

  testWidgets('accueil médecin — 900 px (panneau latéral)', (tester) async {
    await _capturer(
      tester,
      largeur: 900,
      hauteur: 1000,
      fichier: 'goldens/accueil_medecin_900.png',
      enfant: _ecran(),
    );
  });

  testWidgets('accueil médecin — 1280 px (desktop)', (tester) async {
    await _capturer(
      tester,
      largeur: 1280,
      hauteur: 1000,
      fichier: 'goldens/accueil_medecin_1280.png',
      enfant: _ecran(),
    );
  });

  testWidgets('accueil médecin — variante vide (600 px)', (tester) async {
    await _capturer(
      tester,
      largeur: 600,
      hauteur: 900,
      fichier: 'goldens/accueil_medecin_vide.png',
      enfant: _ecran(liste: const []),
    );
  });
}
