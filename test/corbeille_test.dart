import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopital_app/medecin/screens/liste_rendez_vous_medecin.dart';
import 'package:hopital_app/models/rendez_vous.dart';
import 'package:hopital_app/secretaire/screens/liste_rendez_vous_secretaire.dart';
import 'package:hopital_app/services/medecin_service.dart';
import 'package:hopital_app/services/secretaire_service.dart';

/// Corbeille des rendez-vous (secrétaire + médecin).
///
/// Ce qui est testable SANS Firestore :
///  · les statuts éligibles (constantes des services — le contrôle
///    d'éligibilité de mettreALaCorbeille s'appuie dessus) ;
///  · l'ouverture de l'onglet (purge déclenchée UNE fois) ;
///  · les mentions des lignes : compte à rebours pour annulé/refusé,
///    « Conservé — historique » pour terminé (jamais purgé) ;
///  · la confirmation obligatoire avant la suppression définitive.
///
/// Le reste (lecture/écriture Firestore) est couvert par les règles et
/// les ajouts de service, non exécutables ici : Firestore n'est pas
/// initialisé dans les tests (même principe que corpsRendezVous).
RendezVous _rdv({required StatutRendezVous statut, String id = 'r1'}) =>
    RendezVous(
      id: id,
      patientNom: 'Mba',
      patientPrenom: 'Alice',
      date: DateTime(2026, 11, 10),
      heure: '09:30',
      statut: statut,
      motif: 'Contrôle tensionnel',
      medecinNom: 'Dr Sarah Obame',
      hopitalId: 'h1',
    );

/// Entrée de corbeille « à J jours » (le compte à rebours affiche
/// 30 - J).
({RendezVous rdv, DateTime corbeilleLe}) _entree(
  StatutRendezVous statut, {
  required int jours,
  String id = 'r1',
}) =>
    (rdv: _rdv(statut: statut, id: id), corbeilleLe: DateTime.now().subtract(Duration(days: jours)));

void main() {
  group('statuts éligibles à la corbeille', () {
    test('secrétaire : terminé, annulé, refusé — jamais en_attente/confirme', () {
      expect(
        SecretaireService.statutsCorbeilleSecretaire,
        {'termine', 'annule', 'refuse'},
      );
      // Une demande en cours de traitement ne doit JAMAIS disparaître
      // des listes : ces deux statuts sont explicitement exclus.
      expect(
        SecretaireService.statutsCorbeilleSecretaire.contains('en_attente'),
        isFalse,
      );
      expect(
        SecretaireService.statutsCorbeilleSecretaire.contains('confirme'),
        isFalse,
      );
    });

    test('médecin : terminé seul (ses seuls rendez-vous visibles)', () {
      expect(MedecinService.statutsCorbeilleMedecin, {'termine'});
    });
  });

  group('onglet Corbeille — secrétaire', () {
    Widget ecran({
      List<RendezVous> rdv = const [],
      List<({RendezVous rdv, DateTime corbeilleLe})> corbeille = const [],
      Future<void> Function()? onOuvrir,
      Future<void> Function(RendezVous)? onRestaurer,
      Future<void> Function(RendezVous)? onSupprimer,
    }) =>
        MaterialApp(
          home: Scaffold(
            body: ListeRendezVousSecretaire(
              rendezVous: rdv,
              onNouveauRendezVous: () {},
              corbeille: corbeille,
              onOuvrirCorbeille: onOuvrir,
              onRestaurer: onRestaurer,
              onSupprimerDefinitivement: onSupprimer,
            ),
          ),
        );

    testWidgets("ouvrir la corbeille déclenche la purge (une seule fois)", (
      tester,
    ) async {
      var purges = 0;
      await tester.pumpWidget(ecran(onOuvrir: () async => purges++));

      // Vue initiale : la liste normale, pas encore la corbeille.
      expect(find.text('Aucun rendez-vous pour ce filtre.'), findsOneWidget);
      expect(find.text('La corbeille est vide.'), findsNothing);

      // Segmente visé via son GestureDetector : « Rendez-vous » existe
      // aussi dans le TITRE de l'écran (tap ambigu sinon).
      await tester.tap(find.widgetWithText(GestureDetector, 'Corbeille'));
      await tester.pump();
      expect(purges, 1);
      expect(find.text('La corbeille est vide.'), findsOneWidget);

      // Un second appui sur l'onglet DÉJÀ actif ne re-purge pas.
      await tester.tap(find.widgetWithText(GestureDetector, 'Corbeille'));
      await tester.pump();
      expect(purges, 1);

      // Retour à la liste normale.
      await tester.tap(find.widgetWithText(GestureDetector, 'Rendez-vous'));
      await tester.pump();
      expect(find.text('Aucun rendez-vous pour ce filtre.'), findsOneWidget);
      expect(purges, 1);
    });

    testWidgets(
      'compte à rebours pour annulé/refusé, « Conservé — historique » pour terminé',
      (tester) async {
        await tester.pumpWidget(
          ecran(corbeille: [
            _entree(StatutRendezVous.annule, jours: 10, id: 'a1'),
            _entree(StatutRendezVous.refuse, jours: 25, id: 'r2'),
            _entree(StatutRendezVous.termine, jours: 40, id: 't1'),
          ]),
        );
        await tester.tap(find.widgetWithText(GestureDetector, 'Corbeille'));
        await tester.pump();

        expect(find.text('Suppression dans 20 jours'), findsOneWidget);
        expect(find.text('Suppression dans 5 jours'), findsOneWidget);
        // Terminé : jamais purgé → pas de compte à rebours trompeur.
        expect(find.text('Conservé — historique'), findsOneWidget);
      },
    );

    testWidgets('le dernier jour affiche « Suppression dans 1 jour »', (
      tester,
    ) async {
      await tester.pumpWidget(
        ecran(corbeille: [_entree(StatutRendezVous.annule, jours: 29)]),
      );
      await tester.tap(find.widgetWithText(GestureDetector, 'Corbeille'));
      await tester.pump();
      expect(find.text('Suppression dans 1 jour'), findsOneWidget);
    });

    testWidgets('Restaurer appelle le callback, sans confirmation', (
      tester,
    ) async {
      var restaurations = 0;
      await tester.pumpWidget(
        ecran(
          corbeille: [_entree(StatutRendezVous.annule, jours: 3)],
          onRestaurer: (_) async => restaurations++,
        ),
      );
      await tester.tap(find.widgetWithText(GestureDetector, 'Corbeille'));
      await tester.pump();

      await tester.tap(find.text('Restaurer'));
      await tester.pump();
      expect(restaurations, 1);
      // Restaurer est réversible : aucune boîte de dialogue.
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('Supprimer demande confirmation avant le callback', (
      tester,
    ) async {
      var suppressions = 0;
      await tester.pumpWidget(
        ecran(
          corbeille: [_entree(StatutRendezVous.refuse, jours: 2)],
          onSupprimer: (_) async => suppressions++,
        ),
      );
      await tester.tap(find.widgetWithText(GestureDetector, 'Corbeille'));
      await tester.pump();

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer définitivement ?'), findsOneWidget);
      // Rien n'est supprimé TANT que la confirmation n'est pas donnée.
      expect(suppressions, 0);

      // Annulation : le callback n'est jamais appelé.
      await tester.tap(
        find.descendant(of: find.byType(Dialog), matching: find.text('Annuler')),
      );
      await tester.pumpAndSettle();
      expect(suppressions, 0);
      expect(find.text('Supprimer définitivement ?'), findsNothing);

      // Confirmation : le callback est appelé exactement une fois.
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Supprimer'),
        ),
      );
      await tester.pumpAndSettle();
      expect(suppressions, 1);
    });
  });

  group('onglet Corbeille — médecin', () {
    Widget ecran({
      List<RendezVous> rdv = const [],
      List<({RendezVous rdv, DateTime corbeilleLe})> corbeille = const [],
      Future<void> Function()? onOuvrir,
      Future<void> Function(RendezVous)? onRestaurer,
      Future<void> Function(RendezVous)? onSupprimer,
    }) =>
        MaterialApp(
          home: Scaffold(
            body: ListeRendezVousMedecin(
              rendezVous: rdv,
              onTapRendezVous: (_) {},
              corbeille: corbeille,
              onOuvrirCorbeille: onOuvrir,
              onRestaurer: onRestaurer,
              onSupprimerDefinitivement: onSupprimer,
            ),
          ),
        );

    testWidgets("ouvrir la corbeille déclenche la purge (une seule fois)", (
      tester,
    ) async {
      var purges = 0;
      await tester.pumpWidget(ecran(onOuvrir: () async => purges++));

      await tester.tap(find.widgetWithText(GestureDetector, 'Corbeille'));
      await tester.pump();
      expect(purges, 1);
      expect(find.text('La corbeille est vide.'), findsOneWidget);

      await tester.tap(find.widgetWithText(GestureDetector, 'Corbeille'));
      await tester.pump();
      expect(purges, 1);
    });

    testWidgets('la corbeille du médecin affiche ses rendez-vous terminés', (
      tester,
    ) async {
      await tester.pumpWidget(
        ecran(
          corbeille: [
            _entree(StatutRendezVous.termine, jours: 5, id: 't1'),
          ],
          onRestaurer: (_) async {},
          onSupprimer: (_) async {},
        ),
      );
      await tester.tap(find.widgetWithText(GestureDetector, 'Corbeille'));
      await tester.pump();

      expect(find.text('Conservé — historique'), findsOneWidget);
      expect(find.text('Restaurer'), findsOneWidget);
      expect(find.text('Supprimer'), findsOneWidget);
    });

    testWidgets('Supprimer demande confirmation avant le callback', (
      tester,
    ) async {
      var suppressions = 0;
      await tester.pumpWidget(
        ecran(
          corbeille: [_entree(StatutRendezVous.termine, jours: 5)],
          onSupprimer: (_) async => suppressions++,
        ),
      );
      await tester.tap(find.widgetWithText(GestureDetector, 'Corbeille'));
      await tester.pump();

      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer définitivement ?'), findsOneWidget);
      expect(suppressions, 0);

      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Supprimer'),
        ),
      );
      await tester.pumpAndSettle();
      expect(suppressions, 1);
    });
  });
}
