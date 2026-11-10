// ─────────────────────────────────────────────────────────────────────
// CAPTURES D'ÉCRAN — accueil secrétaire redessiné (hors suite `flutter test`).
//
// Rend AccueilSecretaire à 360 / 600 / 900 / 1280 px (+ variante vide) et
// écrit les PNG dans tool/captures/goldens/. Ce fichier vit hors test/
// volontairement : un golden est lié aux polices de la machine qui l'a
// généré, il ne doit pas figer la suite de tests de l'équipe.
//
// Utilisation :
//   flutter test tool/captures/accueil_secretaire_capture_test.dart --update-goldens
//
// Le même fichier sert aussi de vérification « sans erreur rouge » :
// toute exception de layout pendant le rendu fait échouer le test.
// ─────────────────────────────────────────────────────────────────────
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopital_app/models/rendez_vous.dart';
import 'package:hopital_app/models/secretaire.dart';
import 'package:hopital_app/secretaire/screens/accueil_secretaire.dart';
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

  // Icônes Material (chevron du bouton héros) : la famille que Icons attend.
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

Secretaire _secretaire() => Secretaire(
      id: 's1',
      nom: 'Ondo-Mbadinga-Bekale',
      prenom: 'Marie-Josée',
      hopitalId: 'h1',
      hopitalNom: 'CHU de Libreville',
    );

/// Données stables pour la capture : 2 demandes en attente (le héros),
/// 1 confirmé, 1 refusé, 1 terminé — tous avec médecin affiché.
List<RendezVous> _rendezVous() {
  final maintenant = DateTime.now();
  final jour = DateTime(maintenant.year, maintenant.month, maintenant.day);
  return [
    RendezVous(
      id: 'e1',
      patientNom: 'Mba',
      patientPrenom: 'Alice',
      date: jour,
      heure: '09:00',
      statut: StatutRendezVous.enAttente,
      motif: 'Douleurs thoraciques',
      medecinNom: 'Dr Sarah Obame',
      hopitalId: 'h1',
    ),
    RendezVous(
      id: 'e2',
      patientNom: 'Ondo',
      patientPrenom: 'Marie-Josée',
      date: jour,
      heure: '10:30',
      statut: StatutRendezVous.enAttente,
      motif: 'Contrôle tensionnel',
      medecinNom: 'Dr Léon Mba',
      hopitalId: 'h1',
    ),
    RendezVous(
      id: 'c1',
      patientNom: 'Owono',
      patientPrenom: 'Paul',
      date: jour,
      heure: '11:15',
      statut: StatutRendezVous.confirme,
      motif: 'Bilan annuel',
      medecinNom: 'Dr Léon Mba',
      hopitalId: 'h1',
    ),
    RendezVous(
      id: 'r1',
      patientNom: 'Moussavou',
      patientPrenom: 'Aline',
      date: jour,
      heure: '14:00',
      statut: StatutRendezVous.refuse,
      motif: 'Suivi grossesse',
      motifRefus: 'Créneau déjà occupé',
      medecinNom: 'Dr Sarah Obame',
      hopitalId: 'h1',
    ),
    RendezVous(
      id: 't1',
      patientNom: 'Ndong',
      patientPrenom: 'Paul',
      date: jour,
      heure: '08:15',
      statut: StatutRendezVous.termine,
      motif: 'Suivi diabète',
      medecinNom: 'Dr Léon Mba',
      hopitalId: 'h1',
    ),
  ];
}

/// Construit l'écran (variantes : liste + stats par défaut, ou vide).
Widget _ecran({List<RendezVous>? liste, Map<String, int>? stats}) =>
    AccueilSecretaire(
      secretaire: _secretaire(),
      rendezVousDuJour: liste ?? _rendezVous(),
      statistiques: stats ??
          {'rdvAujourdhui': 4, 'enAttente': 2, 'totalPatients': 128},
      onTapRendezVous: (_) {},
      onNouveauRendezVous: () {},
      onNouveauPatient: () {},
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

  // On avance la pendule de test : délais d'Apparition (0 → 400 ms) puis
  // animation des compteurs (600 ms). Sans cela, la capture serait prise
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

  testWidgets('accueil secrétaire — 360 px (mobile étroit)', (tester) async {
    await _capturer(
      tester,
      largeur: 360,
      hauteur: 780,
      fichier: 'goldens/accueil_secretaire_360.png',
      enfant: _ecran(),
    );
  });

  testWidgets('accueil secrétaire — 600 px (tablette)', (tester) async {
    await _capturer(
      tester,
      largeur: 600,
      hauteur: 900,
      fichier: 'goldens/accueil_secretaire_600.png',
      enfant: _ecran(),
    );
  });

  testWidgets('accueil secrétaire — 900 px (panneau latéral)', (tester) async {
    await _capturer(
      tester,
      largeur: 900,
      hauteur: 1000,
      fichier: 'goldens/accueil_secretaire_900.png',
      enfant: _ecran(),
    );
  });

  testWidgets('accueil secrétaire — 1280 px (desktop)', (tester) async {
    await _capturer(
      tester,
      largeur: 1280,
      hauteur: 1000,
      fichier: 'goldens/accueil_secretaire_1280.png',
      enfant: _ecran(),
    );
  });

  testWidgets('accueil secrétaire — variante vide (600 px)', (tester) async {
    await _capturer(
      tester,
      largeur: 600,
      hauteur: 900,
      fichier: 'goldens/accueil_secretaire_vide.png',
      enfant: _ecran(
        liste: const [],
        stats: {'rdvAujourdhui': 0, 'enAttente': 0, 'totalPatients': 0},
      ),
    );
  });
}
