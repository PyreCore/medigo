import 'package:flutter_test/flutter_test.dart';
import 'package:hopital_app/models/disponibilite.dart';

void main() {
  // Le médecin saisit ses disponibilités avec un jour 1..7, et l'écran
  // médecin affiche ce choix via nomJour(jour) : 1 = Lundi … 7 = Dimanche.
  // jourDeLaSemaine doit donc renvoyer exactement la convention de Dart
  // (DateTime.weekday), sinon la recherche des créneaux se fait sur le jour
  // suivant et le patient voit « aucune disponibilité » à tort.
  group('Disponibilite.jourDeLaSemaine', () {
    test('lundi vaut 1', () {
      expect(Disponibilite.jourDeLaSemaine(DateTime(2026, 10, 5)), 1);
    });

    test('dimanche vaut 7', () {
      expect(Disponibilite.jourDeLaSemaine(DateTime(2026, 10, 11)), 7);
    });

    test('couvre les sept jours sans débordement', () {
      final premiere = DateTime(2026, 10, 5); // lundi
      for (var decalage = 0; decalage < 7; decalage++) {
        expect(
          Disponibilite.jourDeLaSemaine(
            premiere.add(Duration(days: decalage)),
          ),
          decalage + 1,
        );
      }
    });

    test('le nom affiché correspond au jour réel de la date', () {
      // 5 octobre 2026 est un lundi : afficher « Mardi » était le symptôme
      // du décalage.
      expect(
        Disponibilite.nomJour(Disponibilite.jourDeLaSemaine(DateTime(2026, 10, 5))),
        'Lundi',
      );
      expect(
        Disponibilite.nomJour(Disponibilite.jourDeLaSemaine(DateTime(2026, 10, 6))),
        'Mardi',
      );
    });
  });
}
