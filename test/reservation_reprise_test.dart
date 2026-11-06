// Réservation commencée en mode visiteur puis reprise après la connexion :
// le brouillon en mémoire, et le formulaire qui se pré-remplit avec.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hopital_app/models/disponibilite.dart';
import 'package:hopital_app/models/medecin.dart';
import 'package:hopital_app/patient/reservation_en_attente.dart';
import 'package:hopital_app/patient/screens/prendre_rendez_vous_patient.dart';
import 'package:hopital_app/shared/models/hopital_model.dart';

final _hopital = Hopital(
  id: 'h1',
  nom: 'CHU de Libreville',
  adresse: 'Libreville',
  telephone: '',
  email: '',
);

final _medecin = Medecin(
  id: 'uid-m1',
  nom: 'Obame',
  prenom: 'Sarah',
  specialite: '',
  hopitalId: 'h1',
  hopitalNom: '',
);

// Un jour futur, pour que la date reste valide quel que soit le jour du test.
final _date = DateTime.now().add(const Duration(days: 3));

ReservationEnAttente _reservation({DateTime? creeLe}) => ReservationEnAttente(
      hopital: _hopital,
      medecin: _medecin,
      date: _date,
      heure: '09:30',
      motif: 'Contrôle annuel',
      creeLe: creeLe,
    );

Widget _formulaire({
  required ReservationEnAttente reservation,
  List<Medecin>? medecins,
  List<String> occupees = const [],
  void Function(String heure, String? motif)? onEnvoi,
}) {
  return MaterialApp(
    home: Scaffold(
      body: PrendreRendezVousPatient(
        hopitaux: [_hopital],
        reservationReprise: reservation,
        chargerMedecins: (_) async => medecins ?? [_medecin],
        chargerSpecialites: (_) async => const [],
        chargerDisponibilites: (id) async => [
          Disponibilite(
            id: 'd1',
            medecinId: id,
            jour: _date.weekday,
            heureDebut: '09:00',
            heureFin: '11:00',
          ),
        ],
        chargerHeuresOccupees: (_, _) async => occupees,
        onValider: ({required medecin, required date, required heure, motif}) =>
            onEnvoi?.call(heure, motif),
      ),
    ),
  );
}

void main() {
  tearDown(ReservationEnAttente.oublier);

  group('ReservationEnAttente', () {
    test('n\'est reprise qu\'une seule fois', () {
      ReservationEnAttente.garder(_reservation());
      expect(ReservationEnAttente.reprendre()?.heure, '09:30');
      expect(ReservationEnAttente.reprendre(), isNull);
    });

    test('expire au bout de 30 minutes', () {
      final creeLe = DateTime(2026, 11, 6, 10, 0);
      ReservationEnAttente.garder(_reservation(creeLe: creeLe));
      expect(
        ReservationEnAttente.reprendre(maintenant: creeLe.add(const Duration(minutes: 31))),
        isNull,
      );
    });

    test('« Plus tard » l\'oublie', () {
      ReservationEnAttente.garder(_reservation());
      ReservationEnAttente.oublier();
      expect(ReservationEnAttente.reprendre(), isNull);
    });
  });

  group('formulaire pré-rempli', () {
    testWidgets('reprend hôpital, médecin, créneau et motif, prêts à envoyer',
        (tester) async {
      String? heureEnvoyee;
      String? motifEnvoye;
      await tester.pumpWidget(_formulaire(
        reservation: _reservation(),
        onEnvoi: (heure, motif) {
          heureEnvoyee = heure;
          motifEnvoye = motif;
        },
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Votre réservation a été reprise'), findsOneWidget);
      expect(find.text('CHU de Libreville'), findsOneWidget);
      expect(find.text('Dr Sarah Obame'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Envoyer ma demande'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Envoyer ma demande'));
      await tester.pump();

      expect(heureEnvoyee, '09:30');
      expect(motifEnvoye, 'Contrôle annuel');
    });

    testWidgets('un créneau pris entre-temps est signalé et à rechoisir',
        (tester) async {
      String? heureEnvoyee;
      await tester.pumpWidget(_formulaire(
        reservation: _reservation(),
        occupees: ['09:30'],
        onEnvoi: (heure, _) => heureEnvoyee = heure,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('n\'est plus libre'), findsOneWidget);
      expect(find.text('Dr Sarah Obame'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Envoyer ma demande'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Envoyer ma demande'));
      await tester.pump();
      expect(heureEnvoyee, isNull);
    });

    testWidgets('un médecin qui n\'exerce plus est signalé', (tester) async {
      await tester.pumpWidget(_formulaire(
        reservation: _reservation(),
        medecins: const [],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('n\'est plus disponible'), findsOneWidget);
    });
  });
}
