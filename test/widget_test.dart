// Test de base : vérifie que les modèles de données se construisent
// correctement et que les getters calculés renvoient les bonnes valeurs.
import 'package:flutter_test/flutter_test.dart';
import 'package:hopital_app/models/rendez_vous.dart';
import 'package:hopital_app/models/patient.dart';
import 'package:hopital_app/models/medecin.dart';

void main() {
  group('RendezVous', () {
    test('patientNomComplet combine prénom et nom', () {
      final rdv = RendezVous(
        id: '1',
        patientNom: 'Nzoghe',
        patientPrenom: 'Paul',
        date: DateTime(2026, 10, 15, 9, 0),
        heure: '09:00',
        statut: StatutRendezVous.confirme,
      );
      expect(rdv.patientNomComplet, 'Paul Nzoghe');
    });

    test('dateHeure combine date et heure', () {
      final rdv = RendezVous(
        id: '1',
        patientNom: 'Nzoghe',
        patientPrenom: 'Paul',
        date: DateTime(2026, 10, 15),
        heure: '09:30',
        statut: StatutRendezVous.enAttente,
      );
      expect(rdv.dateHeure, DateTime(2026, 10, 15, 9, 30));
    });

    test('modifiableParPatient est vrai seulement si en attente et à venir', () {
      final rdvPasse = RendezVous(
        id: '1',
        patientNom: 'Nzoghe',
        patientPrenom: 'Paul',
        date: DateTime(2020, 1, 1),
        heure: '09:00',
        statut: StatutRendezVous.enAttente,
      );
      expect(rdvPasse.modifiableParPatient, isFalse);

      final rdvConfirme = RendezVous(
        id: '2',
        patientNom: 'Nzoghe',
        patientPrenom: 'Paul',
        date: DateTime(2099, 1, 1),
        heure: '09:00',
        statut: StatutRendezVous.confirme,
      );
      expect(rdvConfirme.modifiableParPatient, isFalse);

      final rdvOk = RendezVous(
        id: '3',
        patientNom: 'Nzoghe',
        patientPrenom: 'Paul',
        date: DateTime(2099, 1, 1),
        heure: '09:00',
        statut: StatutRendezVous.enAttente,
      );
      expect(rdvOk.modifiableParPatient, isTrue);
    });

    test('fromJson lit motifRefus et statut', () {
      final rdv = RendezVous.fromJson({
        'id': 'abc',
        'patient_nom': 'Nzoghe',
        'patient_prenom': 'Paul',
        'date': '2026-10-15T09:00:00.000',
        'heure': '09:00',
        'statut': 'refuse',
        'motifRefus': 'Créneau déjà occupé',
      });
      expect(rdv.statut, StatutRendezVous.refuse);
      expect(rdv.motifRefus, 'Créneau déjà occupé');
    });
  });

  group('Patient', () {
    test('nomComplet et initiale', () {
      final patient = Patient(
        id: '1',
        nom: 'Nzoghe',
        prenom: 'Paul',
        telephone: '074500224',
        email: 'paul@example.com',
        hopitalId: 'hop1',
      );
      expect(patient.nomComplet, 'Paul Nzoghe');
      expect(patient.initiale, 'P');
    });

    test('fromJson lit userId et email', () {
      // NOTE : Patient.fromJson reçoit une carte déjà NORMALISÉE par
      // PatientService._versPatient (qui traduit le document Firestore en
      // clés snake_case). Le champ Firestore "userId" (camelCase) arrive
      // donc ici sous le nom "user_id".
      final patient = Patient.fromJson({
        'id': 'p1',
        'nom': 'Nzoghe',
        'prenom': 'Paul',
        'telephone': '074500224',
        'hopital_id': 'hop1',
        'user_id': 'uid123',
        'email': 'paul@example.com',
      });
      expect(patient.userId, 'uid123');
      expect(patient.email, 'paul@example.com');
    });
  });

  group('Medecin', () {
    test('nomComplet commence par Dr', () {
      final medecin = Medecin(
        id: '1',
        nom: 'Obame',
        prenom: 'Sarah',
        specialite: 'Cardiologie',
        hopitalId: 'hop1',
        hopitalNom: 'CHU de Libreville',
      );
      expect(medecin.nomComplet, 'Dr Sarah Obame');
    });

    test('fromJson lit specialiteId', () {
      final medecin = Medecin.fromJson({
        'id': 'm1',
        'nom': 'Obame',
        'prenom': 'Sarah',
        'specialite': 'Cardiologie',
        'hopitalId': 'hop1',
        'hopitalNom': 'CHU de Libreville',
        'specialiteId': 'spec123',
      });
      expect(medecin.specialiteId, 'spec123');
    });
  });
}
