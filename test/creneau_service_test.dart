import 'package:flutter_test/flutter_test.dart';
import 'package:hopital_app/services/creneau_service.dart';

void main() {
  group('CreneauService.cleJour', () {
    // La clé de jour est stockée dans Firestore et sert de filtre dans la
    // requête getHeuresOccupees. Une erreur ici ferait apparaître des créneaux
    // libres qui sont en réalité pris, ou l'inverse.
    test('formate une date au format AAAA-MM-JJ', () {
      expect(CreneauService.cleJour(DateTime(2026, 9, 30)), '2026-09-30');
    });

    test('ajoute un zéro devant les mois et les jours < 10', () {
      expect(CreneauService.cleJour(DateTime(2026, 1, 5)), '2026-01-05');
      expect(CreneauService.cleJour(DateTime(2026, 12, 9)), '2026-12-09');
    });

    test('ignore l\'heure, donc la même journée donne toujours la même clé', () {
      final matin = DateTime(2026, 3, 7, 8, 30);
      final soir = DateTime(2026, 3, 7, 22, 15);
      expect(CreneauService.cleJour(soir), CreneauService.cleJour(matin));
    });

    test('deux journées différentes donnent deux clés différentes', () {
      expect(
        CreneauService.cleJour(DateTime(2026, 3, 7)),
        isNot(CreneauService.cleJour(DateTime(2026, 3, 8))),
      );
    });
  });
}
