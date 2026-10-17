// ─────────────────────────────────────────────────────────────────────
// TEST RESPONSIVE — vérifie qu'aucun écran de l'espace Médecin / Secrétaire
// ne provoque d'erreur de mise en page (RenderFlex overflow, unbounded...)
// aux 4 largeurs de référence : 360 px (petit téléphone), 600 px (tablette
// étroite), 900 px (seuil du rail) et 1280 px (web/desktop).
//
// PRINCIPE : on "pompe" chaque écran dans un SizedBox de la largeur voulue.
// Quand Flutter déborde (overflow), il signale une erreur via FlutterError
// → le test échoue automatiquement avec le message exact. C'est ainsi qu'on
// attrape les erreurs "rouges" de la console navigateur de façon reproductible
// sans avoir à lancer l'application à la main.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hopital_app/models/medecin.dart';
import 'package:hopital_app/models/patient.dart';
import 'package:hopital_app/models/rendez_vous.dart';
import 'package:hopital_app/models/secretaire.dart';
import 'package:hopital_app/medecin/screens/accueil_medecin.dart';
import 'package:hopital_app/medecin/screens/detail_rendez_vous_medecin.dart';
import 'package:hopital_app/medecin/screens/liste_rendez_vous_medecin.dart';
import 'package:hopital_app/secretaire/screens/accueil_secretaire.dart';
import 'package:hopital_app/secretaire/screens/detail_rendez_vous_secretaire.dart';
import 'package:hopital_app/secretaire/screens/liste_patients_secretaire.dart';
import 'package:hopital_app/secretaire/screens/liste_rendez_vous_secretaire.dart';
import 'package:hopital_app/widgets/structure_espace.dart';

/// Les 4 largeurs de référence imposées par le cahier des charges.
const List<double> largeursATester = [360, 600, 900, 1280];

// ── Données de test (nommées très longues exprès : c'est le pire cas
//    d'overflow, s'il tient ici il tient avec des noms normaux). ────────
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

/// Liste de rendez-vous variée : chaque statut représenté, avec des noms
/// longs et un motif, pour exercer toutes les branches d'affichage.
List<RendezVous> desRendezVous() => [
      RendezVous(
        id: '1',
        patientNom: 'Nzoghe-Mba-Okouma-Koumba',
        patientPrenom: 'Jean-Baptiste-François',
        date: DateTime(2099, 1, 1),
        heure: '09:00',
        statut: StatutRendezVous.enAttente,
        motif: 'Consultation de contrôle cardiaque de routine',
        medecinNom: 'Dr Sarah-Fatoumata Nzoghe-Mba-Obame-Okouma',
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
      RendezVous(
        id: '3',
        patientNom: 'Owono-Assoumou',
        patientPrenom: 'Paul',
        date: DateTime(2099, 1, 1),
        heure: '11:15',
        statut: StatutRendezVous.refuse,
        motifRefus: 'Créneau déjà occupé ce jour-là',
        medecinNom: 'Dr Léon',
      ),
      RendezVous(
        id: '4',
        patientNom: 'Moussavou',
        patientPrenom: 'Aline',
        date: DateTime(2099, 1, 1),
        heure: '14:00',
        statut: StatutRendezVous.termine,
        medecinNom: 'Dr Léon',
      ),
    ];

/// Affiche [enfant] dans une fenêtre simulée de [largeur] px sur 700 px de
/// hauteur. Toute exception de layout levée pendant le build fait échouer
/// le test (c'est exactement ce que la console navigateur montrerait en rouge).
Future<void> verifierLargeur(
  WidgetTester tester,
  double largeur,
  Widget enfant,
) async {
  tester.view.physicalSize = Size(largeur, 700);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SizedBox(width: largeur, child: enfant)),
    ),
  );
  // Deux pump : une pour le build initial, une pour les micro-animations
  // (Apparition, compteurs) qui ne doivent elles non plus rien faire déborder.
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('Espace Médecin — aucune erreur de layout aux 4 largeurs', () {
    for (final largeur in largeursATester) {
      testWidgets('accueil médecin à $largeur px', (tester) async {
        await verifierLargeur(
          tester,
          largeur,
          AccueilMedecin(
            medecin: medecinTest,
            rendezVousDuJour: desRendezVous(),
            enAttente: 2,
            patientsSuivis: 10,
            onVoirTout: () {},
            onVoirPlanning: () {},
            onTapRendezVous: (_) {},
          ),
        );
      });

      testWidgets('liste des rendez-vous médecin à $largeur px', (tester) async {
        await verifierLargeur(
          tester,
          largeur,
          ListeRendezVousMedecin(
            rendezVous: desRendezVous(),
            onTapRendezVous: (_) {},
          ),
        );
      });

      testWidgets('détail rendez-vous médecin à $largeur px', (tester) async {
        await verifierLargeur(
          tester,
          largeur,
          DetailRendezVousMedecin(
            rdv: desRendezVous().first,
            onAccepter: () async {},
            onRefuser: () async {},
          ),
        );
      });
    }
  });

  group('Espace Secrétaire — aucune erreur de layout aux 4 largeurs', () {
    for (final largeur in largeursATester) {
      testWidgets('accueil secrétaire à $largeur px', (tester) async {
        await verifierLargeur(
          tester,
          largeur,
          AccueilSecretaire(
            secretaire: secretaireTest,
            rendezVousDuJour: desRendezVous(),
            statistiques: {'rdvAujourdhui': 4, 'enAttente': 1, 'totalPatients': 12},
            onTapRendezVous: (_) {},
            onNouveauRendezVous: () {},
            onNouveauPatient: () {},
          ),
        );
      });

      testWidgets('liste des patients secrétaire à $largeur px', (tester) async {
        await verifierLargeur(
          tester,
          largeur,
          ListePatientsSecretaire(
            patients: [patientTest],
            onNouveauPatient: () {},
          ),
        );
      });

      testWidgets('liste des rendez-vous secrétaire à $largeur px', (tester) async {
        await verifierLargeur(
          tester,
          largeur,
          ListeRendezVousSecretaire(
            rendezVous: desRendezVous(),
            onTapRendezVous: (_) {},
            onNouveauRendezVous: () {},
          ),
        );
      });

      testWidgets('détail rendez-vous secrétaire à $largeur px', (tester) async {
        await verifierLargeur(
          tester,
          largeur,
          DetailRendezVousSecretaire(
            rdv: desRendezVous().first,
            onConfirmer: () {},
            onAnnuler: () {},
            onRefuser: (rdv, {motif}) async {},
          ),
        );
      });
    }
  });

  group('Coquille StructureEspace — rail ≥ 900 px, barre basse < 900 px', () {
    // Sous 900 px : PAS de rail, une barre du bas avec les libellés.
    testWidgets('à 360 px : barre du bas visible, rail absent', (tester) async {
      await verifierLargeur(
        tester,
        360,
        StructureEspace(
          titreEspace: 'Espace Médecin',
          nomUtilisateur: medecinTest.nomComplet,
          initialesUser: 'SN',
          indexActif: 0,
          onChoisirOnglet: (_) {},
          libelles: const ['Accueil', 'Rendez-vous', 'Disponibilités', 'Profil'],
          onglets: const [SizedBox(), SizedBox(), SizedBox(), SizedBox()],
        ),
      );
      // Le logotype du rail n'existe que en mode large.
      expect(find.text('Medigo'), findsNothing);
      // Les libellés de la barre du bas sont présents.
      expect(find.text('Accueil'), findsWidgets);
      expect(find.text('Profil'), findsWidgets);
    });

    // À ≥ 900 px : rail à gauche (« Medigo »), pas de barre du bas.
    testWidgets('à 900 px : rail visible, barre du bas absente', (tester) async {
      await verifierLargeur(
        tester,
        900,
        StructureEspace(
          titreEspace: 'Espace Médecin',
          nomUtilisateur: medecinTest.nomComplet,
          initialesUser: 'SN',
          indexActif: 0,
          onChoisirOnglet: (_) {},
          libelles: const ['Accueil', 'Rendez-vous', 'Disponibilités', 'Profil'],
          onglets: const [SizedBox(), SizedBox(), SizedBox(), SizedBox()],
        ),
      );
      // Le logotype du rail apparaît en mode large.
      expect(find.text('Medigo'), findsOneWidget);
    });
  });
}
