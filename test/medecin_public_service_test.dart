// La fiche publique d'un médecin (medecins_publics) ne doit jamais contenir
// ses coordonnées personnelles.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:hopital_app/services/medecin_public_service.dart';

void main() {
  final ficheComplete = {
    'prenom': 'Sarah',
    'nom': 'Obame',
    'email': 'sarah.obame@exemple.ga',
    'telephone': '077 00 00 00',
    'specialiteId': 's1',
    'hopitalId': 'h1',
    'userId': 'uid-m1',
  };

  test('la fiche publique ne garde que nom, prénom, spécialité et hôpital', () {
    expect(MedecinPublicService.champsPublics(ficheComplete), {
      'nom': 'Obame',
      'prenom': 'Sarah',
      'specialiteId': 's1',
      'hopitalId': 'h1',
    });
  });

  test('ni email, ni téléphone, ni uid dans la fiche publique', () {
    final publique = MedecinPublicService.champsPublics(ficheComplete);
    expect(publique.containsKey('email'), isFalse);
    expect(publique.containsKey('telephone'), isFalse);
    // L'uid est l'id du document, pas un champ : la règle hasOnly le refuserait.
    expect(publique.containsKey('userId'), isFalse);
  });

  test('les champs publiés sont exactement ceux autorisés par firestore.rules', () {
    // Lit la liste hasOnly de la règle medecins_publics : si l'une change
    // sans l'autre, les écritures seraient refusées (ou pire, un champ en
    // trop deviendrait public).
    final regles = File('firestore.rules').readAsStringSync();
    final bloc = regles.substring(regles.indexOf('match /medecins_publics/'));
    final hasOnly = RegExp(r'hasOnly\(\[([^\]]*)\]\)').firstMatch(bloc)!.group(1)!;
    final autorises = RegExp(r"'([^']+)'").allMatches(hasOnly).map((m) => m.group(1)!);

    expect(MedecinPublicService.champs.toSet(), autorises.toSet());
  });

  test('un champ absent devient une chaîne vide plutôt que « null »', () {
    final publique = MedecinPublicService.champsPublics({'nom': 'Obame'});
    expect(publique['specialiteId'], '');
    expect(publique['prenom'], '');
  });
}
