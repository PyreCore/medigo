// Espace Patient en mode visiteur : l'application s'utilise sans compte —
// hôpitaux, spécialités, médecins et formulaire de réservation compris —
// mais l'ENVOI d'une demande exige une connexion.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hopital_app/models/medecin.dart';
import 'package:hopital_app/models/specialite.dart';
import 'package:hopital_app/patient/screens/espace_patient_visiteur.dart';
import 'package:hopital_app/shared/models/hopital_model.dart';

final _hopitaux = [
  Hopital(
    id: 'h1',
    nom: 'Centre Hospitalier Universitaire de Libreville',
    adresse: 'Boulevard Triomphal, Libreville',
    telephone: '011 00 00 01',
    email: 'contact@chul.ga',
  ),
  Hopital(
    id: 'h2',
    nom: 'Clinique de Port-Gentil',
    adresse: 'Port-Gentil',
    telephone: '011 00 00 02',
    email: '',
  ),
];

final _specialites = [
  Specialite(id: 's1', nom: 'Cardiologie', description: 'Cœur', hopitalId: 'h1'),
  Specialite(id: 's2', nom: 'Pédiatrie', description: '', hopitalId: 'h2'),
  Specialite(id: 's3', nom: 'cardiologie', description: '', hopitalId: 'h2'),
];

final _medecins = {
  'h1': [
    Medecin(
      id: 'uid-m1',
      nom: 'Obame',
      prenom: 'Sarah',
      specialite: '',
      specialiteId: 's1',
      hopitalId: 'h1',
      hopitalNom: '',
    ),
  ],
};

Widget _app({bool connecte = false, double largeur = 360}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(largeur, 1600)),
      child: EspacePatientVisiteur(
        chargerHopitaux: () async => _hopitaux,
        chargerSpecialites: () async => _specialites,
        chargerMedecins: (id) async => _medecins[id] ?? const [],
        estConnecte: () => connecte,
      ),
    ),
  );
}

Future<void> _ouvrir(WidgetTester tester, {bool connecte = false}) async {
  tester.view.physicalSize = const Size(360, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(connecte: connecte));
  await tester.pumpAndSettle();
}

void main() {
  for (final largeur in [360.0, 600.0, 900.0, 1280.0]) {
    testWidgets('accueil visiteur sans erreur de mise en page à $largeur px',
        (tester) async {
      tester.view.physicalSize = Size(largeur, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(largeur: largeur));
      await tester.pumpAndSettle();

      expect(find.text('Bienvenue sur Medigo'), findsOneWidget);
      // Les deux « cardiologie » (casse différente) ne font qu'une puce.
      expect(find.widgetWithText(ActionChip, 'Cardiologie'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Pédiatrie'), findsOneWidget);
      expect(find.text('Clinique de Port-Gentil'), findsOneWidget);
    });
  }

  testWidgets('« Prendre rendez-vous » ouvre le formulaire, sans connexion',
      (tester) async {
    await _ouvrir(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Prendre rendez-vous'));
    await tester.pumpAndSettle();

    expect(find.text('Connexion requise'), findsNothing);
    expect(find.textContaining('Mode visiteur'), findsOneWidget);
    expect(find.text('Envoyer ma demande'), findsOneWidget);
  });

  testWidgets('le formulaire visiteur vérifie les champs avant de demander un compte',
      (tester) async {
    await _ouvrir(tester);
    await tester.tap(find.text('Prendre RDV'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Envoyer ma demande'));
    await tester.pump();

    expect(find.text('Merci de choisir un hôpital'), findsOneWidget);
    expect(find.text('Connexion requise'), findsNothing);
  });

  testWidgets('« Réserver dans cet hôpital » pré-sélectionne l\'hôpital et ses médecins',
      (tester) async {
    await _ouvrir(tester);
    await tester.tap(find.text('Hôpitaux').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Centre Hospitalier Universitaire de Libreville'));
    await tester.pumpAndSettle();

    // Fiche : spécialités ET médecins, visibles sans compte.
    expect(find.text('Spécialités proposées'), findsOneWidget);
    expect(find.text('Dr Sarah Obame'), findsOneWidget);

    await tester.tap(find.text('Réserver dans cet hôpital'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mode visiteur'), findsOneWidget);
    expect(find.text('Médecin'), findsOneWidget);
    expect(find.text('Connexion requise'), findsNothing);
  });

  testWidgets('un hôpital sans médecin l\'indique dans sa fiche', (tester) async {
    await _ouvrir(tester);
    await tester.tap(find.text('Hôpitaux').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clinique de Port-Gentil'));
    await tester.pumpAndSettle();

    expect(
      find.text('Aucun médecin n\'est encore enregistré dans cet hôpital.'),
      findsOneWidget,
    );
  });

  testWidgets('connecté, l\'onglet Prendre RDV renvoie vers son espace',
      (tester) async {
    await _ouvrir(tester, connecte: true);
    await tester.tap(find.text('Prendre RDV'));
    await tester.pumpAndSettle();

    expect(find.text('Ouvrir mon espace'), findsOneWidget);
  });

  testWidgets('une spécialité filtre les hôpitaux qui la proposent',
      (tester) async {
    await _ouvrir(tester);

    await tester.tap(find.widgetWithText(ActionChip, 'Pédiatrie'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, 'Pédiatrie'), findsOneWidget);
    expect(find.text('Clinique de Port-Gentil'), findsOneWidget);
    expect(
      find.text('Centre Hospitalier Universitaire de Libreville'),
      findsNothing,
    );
  });

  testWidgets('la recherche filtre par nom ou par ville', (tester) async {
    await _ouvrir(tester);

    await tester.tap(find.text('Hôpitaux').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'libreville');
    await tester.pumpAndSettle();

    expect(
      find.text('Centre Hospitalier Universitaire de Libreville'),
      findsOneWidget,
    );
    expect(find.text('Clinique de Port-Gentil'), findsNothing);
  });
}
