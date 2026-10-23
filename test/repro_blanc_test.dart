// Test de reproduction du bug « écran blanc » : on pompe l'espace COMPLET
// (StructureEspace + accueil) comme dans l'application réelle, aux 4 largeurs.
// Contrairement aux tests isolés, ceci exerce la vraie chaîne de navigation.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hopital_app/models/medecin.dart';
import 'package:hopital_app/models/patient.dart';
import 'package:hopital_app/models/rendez_vous.dart';
import 'package:hopital_app/models/secretaire.dart';
import 'package:hopital_app/medecin/screens/espace_medecin.dart';
import 'package:hopital_app/secretaire/screens/espace_secretaire.dart';

final medecinTest = Medecin(
  id: 'm1',
  nom: 'Nzoghe-Mba-Obame-Okouma',
  prenom: 'Sarah-Fatoumata',
  specialite: 'Cardiologie et maladies cardio-vasculaires',
  hopitalId: 'h1',
  hopitalNom: 'Centre Hospitalier Universitaire de Libreville',
);

final secretaireTest = Secretaire(
  id: 's1',
  nom: 'Ondo-Mbadinga-Bekale',
  prenom: 'Marie-Josée',
  hopitalId: 'h1',
  hopitalNom: 'Centre Hospitalier Universitaire de Libreville',
);

final patientTest = Patient(
  id: 'p1',
  nom: 'Nzoghe-Mba-Longue-Nom',
  prenom: 'Jean-Baptiste',
  telephone: '+241 07 45 00 22 44',
  email: 'jeanbaptiste.nzoghe@example-gabon.fr',
);

List<RendezVous> desRendezVous() => [
      RendezVous(
        id: '1',
        patientNom: 'Nzoghe-Mba-Okouma-Koumba',
        patientPrenom: 'Jean-Baptiste-François',
        date: DateTime(2099, 1, 1),
        heure: '09:00',
        statut: StatutRendezVous.enAttente,
        motif: 'Consultation de contrôle cardiaque de routine',
        medecinNom: 'Dr Sarah',
      ),
      RendezVous(
        id: '2',
        patientNom: 'Ondo-Bekale',
        patientPrenom: 'Marie-Josée',
        date: DateTime(2099, 1, 1),
        heure: '10:30',
        statut: StatutRendezVous.confirme,
        motif: 'Douleur thoracique',
        medecinNom: 'Dr Léon',
      ),
    ];

Future<void> pomperEspace(
  WidgetTester tester,
  double largeur,
  Widget espace,
) async {
  tester.view.physicalSize = Size(largeur, 700);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: espace));
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('Reproduction — EspaceMedecin COMPLET', () {
    for (final largeur in [360.0, 600.0, 900.0, 1280.0]) {
      testWidgets('espace médecin $largeur px', (tester) async {
        await pomperEspace(
          tester,
          largeur,
          EspaceMedecin(
            medecin: medecinTest,
            rendezVousDuJour: desRendezVous(),
            patientsSuivis: 10,
          ),
        );
        // Vérifie que l'accueil est réellement affiché (pas blanc).
        expect(find.textContaining('Bonjour'), findsWidgets);
      });
    }
  });

  group('Reproduction — EspaceSecretaire COMPLET', () {
    for (final largeur in [360.0, 600.0, 900.0, 1280.0]) {
      testWidgets('espace secrétaire $largeur px', (tester) async {
        await pomperEspace(
          tester,
          largeur,
          EspaceSecretaire(
            secretaire: secretaireTest,
            patients: [patientTest],
            medecins: [medecinTest],
            rendezVousDuJour: desRendezVous(),
            statistiques: const {'rdvAujourdhui': 2, 'enAttente': 1, 'totalPatients': 1},
          ),
        );
        expect(find.textContaining('Bonjour'), findsWidgets);
      });
    }
  });
}
