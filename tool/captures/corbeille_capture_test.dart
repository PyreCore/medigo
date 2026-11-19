// ─────────────────────────────────────────────────────────────────────
// CAPTURES D'ÉCRAN — corbeille des rendez-vous (hors suite `flutter test`).
//
// Rend la vue « Corbeille » des deux listes (secrétaire + médecin) à
// 360 / 600 / 900 / 1280 px, la variante vide, et le détail secrétaire
// avec son pied « Mettre à la corbeille ». Écrit les PNG dans
// tool/captures/goldens/. Ce fichier vit hors test/ volontairement :
// un golden est lié aux polices de la machine qui l'a généré, il ne
// doit pas figer la suite de tests de l'équipe.
//
// Utilisation :
//   flutter test tool/captures/corbeille_capture_test.dart --update-goldens
//
// Le même fichier sert aussi de vérification « sans erreur rouge » :
// toute exception de layout pendant le rendu fait échouer le test.
//
// Stabilité des PNG :
//  · la date des RDV est FIXE et éloignée d'aujourd'hui → `jourRelatif`
//    affiche « 20 octobre » (jamais « Aujourd'hui »/« Hier ») ;
//  · le compte à rebours dépend de `DateTime.now() - jours` →
//    « Suppression dans 5 jours » toujours identique au rendu.
// ─────────────────────────────────────────────────────────────────────
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopital_app/medecin/screens/liste_rendez_vous_medecin.dart';
import 'package:hopital_app/models/rendez_vous.dart';
import 'package:hopital_app/secretaire/screens/detail_rendez_vous_secretaire.dart';
import 'package:hopital_app/secretaire/screens/liste_rendez_vous_secretaire.dart';
import 'package:hopital_app/theme/maquette_tokens.dart';
import 'package:hopital_app/theme/medigo_theme.dart';

/// Charge des polices RÉELLES pour que le PNG affiche du texte lisible :
/// dans un test, Flutter utilise sinon la police « Ahem » (des
/// rectangles à la place des lettres).
Future<void> _chargerPolices() async {
  // Roboto — la police RÉELLE de l'app (fournie par le SDK Flutter) :
  // métriques fidèles au rendu Android/web. Repli : DejaVu (système).
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

  // Icônes Material : la famille que Icons attend.
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

/// Entrée de corbeille pour la capture. La date du RDV est FIXE et
/// éloignée d'aujourd'hui (20 octobre) : `jourRelatif` rend alors
/// « 20 octobre », jamais « Aujourd'hui »/« Hier » — le PNG est donc
/// identique quel que soit le jour de génération. Le compte à rebours
/// vient de `now - jours` → stable aussi.
({RendezVous rdv, DateTime corbeilleLe}) _entree({
  required String id,
  required StatutRendezVous statut,
  required String patientNom,
  required String patientPrenom,
  required String heure,
  required String motif,
  required String medecinNom,
  required int jours,
  String? motifRefus,
}) {
  return (
    rdv: RendezVous(
      id: id,
      patientNom: patientNom,
      patientPrenom: patientPrenom,
      date: DateTime(2026, 10, 20),
      heure: heure,
      statut: statut,
      motif: motif,
      motifRefus: motifRefus,
      medecinNom: medecinNom,
      hopitalId: 'h1',
    ),
    corbeilleLe: DateTime.now().subtract(Duration(days: jours)),
  );
}

/// Trois lignes représentatives : refusé (5 j restants), annulé
/// (20 j restants), terminé (« Conservé — historique »).
List<({RendezVous rdv, DateTime corbeilleLe})> _corbeilleSecretaire() => [
      _entree(
        id: 'r1',
        statut: StatutRendezVous.refuse,
        patientNom: 'Moussavou',
        patientPrenom: 'Aline',
        heure: '14:00',
        motif: 'Suivi grossesse',
        medecinNom: 'Dr Sarah Obame',
        jours: 25,
        motifRefus: 'Créneau déjà occupé',
      ),
      _entree(
        id: 'a1',
        statut: StatutRendezVous.annule,
        patientNom: 'Nkemba',
        patientPrenom: 'Georges',
        heure: '10:30',
        motif: 'Douleurs abdominales',
        medecinNom: 'Dr Léon Mba',
        jours: 10,
      ),
      _entree(
        id: 't1',
        statut: StatutRendezVous.termine,
        patientNom: 'Ndong',
        patientPrenom: 'Paul',
        heure: '08:15',
        motif: 'Suivi diabète',
        medecinNom: 'Dr Léon Mba',
        jours: 40,
      ),
    ];

/// La corbeille du médecin ne contient QUE des rendez-vous terminés.
List<({RendezVous rdv, DateTime corbeilleLe})> _corbeilleMedecin() => [
      _entree(
        id: 't1',
        statut: StatutRendezVous.termine,
        patientNom: 'Ndong',
        patientPrenom: 'Paul',
        heure: '08:15',
        motif: 'Suivi diabète',
        medecinNom: 'Dr Léon Mba',
        jours: 5,
      ),
      _entree(
        id: 't2',
        statut: StatutRendezVous.termine,
        patientNom: 'Ekema',
        patientPrenom: 'Marie',
        heure: '11:00',
        motif: 'Contrôle tensionnel',
        medecinNom: 'Dr Sarah Obame',
        jours: 12,
      ),
    ];

Widget _listeSecretaire({
  List<({RendezVous rdv, DateTime corbeilleLe})> corbeille = const [],
}) =>
    ListeRendezVousSecretaire(
      rendezVous: const [],
      onNouveauRendezVous: () {},
      corbeille: corbeille,
      onOuvrirCorbeille: () async {},
      onRestaurer: (_) async {},
      onSupprimerDefinitivement: (_) async {},
    );

Widget _listeMedecin({
  List<({RendezVous rdv, DateTime corbeilleLe})> corbeille = const [],
}) =>
    ListeRendezVousMedecin(
      rendezVous: const [],
      onTapRendezVous: (_) {},
      corbeille: corbeille,
      onOuvrirCorbeille: () async {},
      onRestaurer: (_) async {},
      onSupprimerDefinitivement: (_) async {},
    );

/// Détail secrétaire sur un rendez-vous REFUSÉ : pied « Mettre à la
/// corbeille » visible (statut éligible). Fournit son propre Scaffold.
Widget _detailSecretaire() => DetailRendezVousSecretaire(
      rdv: RendezVous(
        id: 'r1',
        patientNom: 'Moussavou',
        patientPrenom: 'Aline',
        date: DateTime(2026, 10, 20),
        heure: '14:00',
        statut: StatutRendezVous.refuse,
        motif: 'Suivi grossesse',
        motifRefus: 'Créneau déjà occupé',
        medecinNom: 'Dr Sarah Obame',
        hopitalId: 'h1',
      ),
      onConfirmer: () {},
      onAnnuler: () {},
      onRefuser: (rdv, {motif}) async {},
      onMettreALaCorbeille: (_) async {},
    );

/// Bascule vers l'onglet Corbeille (l'écran démarre sur la liste
/// normale). Le segment est visé via son GestureDetector : « Rendez-vous »
/// existe aussi dans le titre de l'écran (tap ambigu sinon).
Future<void> _versCorbeille(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(GestureDetector, 'Corbeille'));
}

Future<void> _capturer(
  WidgetTester tester, {
  required double largeur,
  required double hauteur,
  required String fichier,
  required Widget enfant,
  Color fond = MaquetteCouleurs.fond,
  bool scaffoldPropre = false,
  Future<void> Function(WidgetTester tester)? apres,
}) async {
  tester.view.physicalSize = Size(largeur, hauteur);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Preview'),
      // Un écran qui fournit DÉJÀ son Scaffold (le détail) ne doit pas
      // en recevoir un second : find.byType(Scaffold) doit rester unique.
      home: scaffoldPropre
          ? enfant
          : Scaffold(
              backgroundColor: fond,
              body: enfant,
            ),
    ),
  );

  // Bascule vers la vue Corbeille avant la capture, le cas échéant.
  if (apres != null) await apres(tester);

  // On avance la pendule de test : micro-animations d'apparition
  // (fondu + glissement). Sans cela, la capture serait prise pendant
  // le fondu (contenu encore transparent).
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

  // ── Corbeille secrétaire (fond Medigo) ────────────────────────────
  testWidgets('corbeille secrétaire — 360 px (mobile étroit)', (tester) async {
    await _capturer(
      tester,
      largeur: 360,
      hauteur: 780,
      fichier: 'goldens/corbeille_secretaire_360.png',
      enfant: _listeSecretaire(corbeille: _corbeilleSecretaire()),
      fond: AppColors.fond,
      apres: _versCorbeille,
    );
  });

  testWidgets('corbeille secrétaire — 600 px (tablette)', (tester) async {
    await _capturer(
      tester,
      largeur: 600,
      hauteur: 900,
      fichier: 'goldens/corbeille_secretaire_600.png',
      enfant: _listeSecretaire(corbeille: _corbeilleSecretaire()),
      fond: AppColors.fond,
      apres: _versCorbeille,
    );
  });

  testWidgets('corbeille secrétaire — 900 px (panneau latéral)', (tester) async {
    await _capturer(
      tester,
      largeur: 900,
      hauteur: 1000,
      fichier: 'goldens/corbeille_secretaire_900.png',
      enfant: _listeSecretaire(corbeille: _corbeilleSecretaire()),
      fond: AppColors.fond,
      apres: _versCorbeille,
    );
  });

  testWidgets('corbeille secrétaire — 1280 px (desktop)', (tester) async {
    await _capturer(
      tester,
      largeur: 1280,
      hauteur: 1000,
      fichier: 'goldens/corbeille_secretaire_1280.png',
      enfant: _listeSecretaire(corbeille: _corbeilleSecretaire()),
      fond: AppColors.fond,
      apres: _versCorbeille,
    );
  });

  testWidgets('corbeille secrétaire — variante vide (600 px)', (tester) async {
    await _capturer(
      tester,
      largeur: 600,
      hauteur: 900,
      fichier: 'goldens/corbeille_secretaire_vide.png',
      enfant: _listeSecretaire(),
      fond: AppColors.fond,
      apres: _versCorbeille,
    );
  });

  // ── Corbeille médecin (fond maquette) ─────────────────────────────
  testWidgets('corbeille médecin — 360 px (mobile étroit)', (tester) async {
    await _capturer(
      tester,
      largeur: 360,
      hauteur: 780,
      fichier: 'goldens/corbeille_medecin_360.png',
      enfant: _listeMedecin(corbeille: _corbeilleMedecin()),
      apres: _versCorbeille,
    );
  });

  testWidgets('corbeille médecin — 600 px (tablette)', (tester) async {
    await _capturer(
      tester,
      largeur: 600,
      hauteur: 900,
      fichier: 'goldens/corbeille_medecin_600.png',
      enfant: _listeMedecin(corbeille: _corbeilleMedecin()),
      apres: _versCorbeille,
    );
  });

  testWidgets('corbeille médecin — 900 px (panneau latéral)', (tester) async {
    await _capturer(
      tester,
      largeur: 900,
      hauteur: 1000,
      fichier: 'goldens/corbeille_medecin_900.png',
      enfant: _listeMedecin(corbeille: _corbeilleMedecin()),
      apres: _versCorbeille,
    );
  });

  testWidgets('corbeille médecin — 1280 px (desktop)', (tester) async {
    await _capturer(
      tester,
      largeur: 1280,
      hauteur: 1000,
      fichier: 'goldens/corbeille_medecin_1280.png',
      enfant: _listeMedecin(corbeille: _corbeilleMedecin()),
      apres: _versCorbeille,
    );
  });

  // ── Détail secrétaire : pied « Mettre à la corbeille » ────────────
  testWidgets('détail refusé avec pied corbeille — 360 px', (tester) async {
    await _capturer(
      tester,
      largeur: 360,
      hauteur: 780,
      fichier: 'goldens/corbeille_detail_secretaire_360.png',
      enfant: _detailSecretaire(),
      scaffoldPropre: true,
    );
  });

  testWidgets('détail refusé avec pied corbeille — 1280 px', (tester) async {
    await _capturer(
      tester,
      largeur: 1280,
      hauteur: 1000,
      fichier: 'goldens/corbeille_detail_secretaire_1280.png',
      enfant: _detailSecretaire(),
      scaffoldPropre: true,
    );
  });
}
