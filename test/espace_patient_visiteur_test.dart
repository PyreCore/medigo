// Espace Patient en mode visiteur : l'application s'utilise sans compte,
// mais toute réservation demande une connexion.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

Widget _app({bool connecte = false, double largeur = 360}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(largeur, 1600)),
      child: EspacePatientVisiteur(
        chargerHopitaux: () async => _hopitaux,
        chargerSpecialites: () async => _specialites,
        estConnecte: () => connecte,
      ),
    ),
  );
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

  testWidgets('« Prendre rendez-vous » sans compte demande la connexion',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Prendre rendez-vous'));
    await tester.pumpAndSettle();

    expect(find.text('Connexion requise'), findsOneWidget);
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();
    expect(find.text('Connexion requise'), findsNothing);
  });

  testWidgets('l\'onglet Prendre RDV est verrouillé pour un visiteur',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Prendre RDV'));
    await tester.pumpAndSettle();

    expect(find.text('Connectez-vous pour réserver'), findsOneWidget);
    expect(find.text('Créer un compte patient'), findsOneWidget);
  });

  testWidgets('une spécialité filtre les hôpitaux qui la proposent',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ActionChip, 'Pédiatrie'));
    await tester.pumpAndSettle();

    // On est sur l'onglet Hôpitaux, filtré : seul h2 propose la pédiatrie.
    expect(find.widgetWithText(InputChip, 'Pédiatrie'), findsOneWidget);
    expect(find.text('Clinique de Port-Gentil'), findsOneWidget);
    expect(
      find.text('Centre Hospitalier Universitaire de Libreville'),
      findsNothing,
    );
  });

  testWidgets('la recherche filtre par nom ou par ville', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hôpitaux').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'libreville');
    await tester.pumpAndSettle();

    expect(
      find.text('Centre Hospitalier Universitaire de Libreville'),
      findsOneWidget,
    );
    expect(find.text('Clinique de Port-Gentil'), findsNothing);
  });

  testWidgets('le détail d\'un hôpital liste ses spécialités et garde la réservation',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hôpitaux').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Centre Hospitalier Universitaire de Libreville'));
    await tester.pumpAndSettle();

    expect(find.text('Spécialités proposées'), findsOneWidget);
    expect(find.text('Cœur'), findsOneWidget);

    await tester.tap(find.text('Réserver dans cet hôpital'));
    await tester.pumpAndSettle();
    expect(find.text('Connexion requise'), findsOneWidget);
  });
}
