import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopital_app/services/secretaire_service.dart';

/// Vérifie le schéma d'écriture du rendez-vous programmé AU GUICHET.
///
/// Le champ "patientUid" est le lien entre ce rendez-vous et l'espace
/// Patient : sans lui, le patient ne voit ni ne lit le rendez-vous pris
/// au guichet (filtre .where('patientUid') + règles firestore.rules,
/// match /rendez_vous). C'est le bug corrigé le 9 novembre.
///
/// On teste CorpsRendezVous en statique : Firestore n'est pas
/// initialisé dans les tests (voir le même principe que
/// CreneauService.cleJour).
void main() {
  group('SecretaireService.corpsRendezVous', () {
    // Construit un corps minimal, en surchargeant seulement ce que le
    // test examine.
    Map<String, dynamic> corps({String? patientUid, String? motif}) =>
        SecretaireService.corpsRendezVous(
          patientId: 'dossier-7',
          patientUid: patientUid,
          patientNom: 'Mba',
          patientPrenom: 'Alice',
          medecinId: 'medecin-uid',
          medecinNom: 'Dr Koto',
          hopitalId: 'hopital-1',
          date: DateTime(2026, 11, 15, 9, 30),
          heure: '09:30',
          motif: motif,
        );

    test('écrit patientUid quand le patient a un compte', () {
      final map = corps(patientUid: 'uid-42');
      expect(map['patientUid'], 'uid-42');
      // patientId reste l'id du DOSSIER patients : ce n'est pas le même
      // identifiant, le second ne doit pas écraser le premier.
      expect(map['patientId'], 'dossier-7');
    });

    test('omet la clé patientUid pour un patient sans compte', () {
      final map = corps();
      // containsKey (et non map['patientUid'] == null) : la clé doit être
      // ABSENTE du document, pas présente avec une valeur nulle.
      expect(map.containsKey('patientUid'), isFalse);
    });

    test("statut 'en_attente' et date en Timestamp, comme l'espace patient", () {
      final map = corps();
      expect(map['statut'], 'en_attente');
      // L'espace Patient et MedecinService lisent (data['date'] as
      // Timestamp) : un texte planterait leur affichage.
      expect(map['date'], isA<Timestamp>());
      expect(
        (map['date'] as Timestamp).toDate(),
        DateTime(2026, 11, 15, 9, 30),
      );
    });

    test('omet le motif absent, garde le motif saisi', () {
      expect(corps().containsKey('motif'), isFalse);
      expect(corps(motif: 'Contrôle')['motif'], 'Contrôle');
    });

    test("l'identifiant du médecin est conservé (filtres et règles)", () {
      final map = corps();
      expect(map['medecinId'], 'medecin-uid');
      expect(map['hopitalId'], 'hopital-1');
    });
  });
}
