import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hopital_app/models/medecin.dart';
import 'package:hopital_app/models/specialite.dart';
import 'package:hopital_app/shared/models/hopital_model.dart';

/// Reproduit la mécanique exacte du formulaire « Prendre rendez-vous » :
/// un DropdownButtonFormField alimenté par `initialValue:` et par une liste
/// d'items reconstruite à chaque build.
///
/// Flutter exige qu'exactement UN item porte la valeur retenue ; sinon il
/// lève l'assertion « There should be exactly one item with
/// [DropdownButton]'s value » et l'écran passe au rouge. Ce test verrouille
/// les deux scénarios qui cassaient la réservation.
void main() {
  Hopital hopital() => Hopital.fromMap({'nom': 'CHU'}, 'h1');
  Medecin medecin(String id, String nom) => Medecin(
    id: id,
    nom: nom,
    prenom: '',
    specialite: '',
    hopitalId: 'h1',
    hopitalNom: '',
  );

  group('identité des modèles', () {
    test('un Hopital relu de Firastore reste le même', () {
      expect(hopital(), hopital());
      expect(hopital().hashCode, hopital().hashCode);
    });

    test('un Medecin relu de Firestore reste le même', () {
      expect(medecin('m1', 'Moulekissi christiana'), medecin('m1', 'Moulekissi christiana'));
      expect(medecin('m1', 'A').hashCode, medecin('m1', 'B').hashCode);
    });

    test('deux médecins différents ne sont pas égaux', () {
      expect(medecin('m1', 'A') == medecin('m2', 'A'), isFalse);
    });

    test('une Specialite relue reste la même', () {
      final a = Specialite.fromJson({'id': 's1', 'nom': 'Cardiologie'});
      final b = Specialite.fromJson({'id': 's1', 'nom': 'Cardiologie'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('sélection dans un DropdownButtonFormField', () {
    testWidgets('l\'hôpital survit au rechargement du loader', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _FormulaireHopital()));
      await tester.tap(find.byType(DropdownButtonFormField<Hopital>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CHU').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Le loader recharge les données : nouveaux objets, mêmes ids.
      await tester.tap(find.text('recharger'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // La sélection est toujours celle du patient, pas une page blanche.
      expect(find.text('CHU'), findsOneWidget);
    });

    testWidgets('le médecin choisi disparaît quand la recherche l\'exclut', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: _FormulaireMedecin()));
      await tester.tap(find.byType(DropdownButtonFormField<Medecin>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Moulekissi christiana').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Le patient affine sa recherche : le médecin choisi n'y est plus.
      await tester.enterText(find.byType(TextField), 'obame');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Il ne reste pas "sélectionné" invisible : le sélecteur est vide.
      await tester.tap(find.byType(DropdownButtonFormField<Medecin>));
      await tester.pumpAndSettle();
      expect(find.text('Moulekissi christiana'), findsNothing);
    });
  });
}

/// Formulaire minimal : hôpital + rechargement.
class _FormulaireHopital extends StatefulWidget {
  const _FormulaireHopital();
  @override
  State<_FormulaireHopital> createState() => _FormulaireHopitalState();
}

class _FormulaireHopitalState extends State<_FormulaireHopital> {
  Hopital? _choisi;
  List<Hopital> _hopitaux = [
    Hopital.fromMap({'nom': 'CHU'}, 'h1'),
    Hopital.fromMap({'nom': 'Clinique'}, 'h2'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          DropdownButtonFormField<Hopital>(
            initialValue: _choisi,
            items: _hopitaux.map((h) => DropdownMenuItem(value: h, child: Text(h.nom))).toList(),
            onChanged: (h) => setState(() => _choisi = h),
          ),
          ElevatedButton(
            onPressed: () => setState(() {
              _hopitaux = [
                Hopital.fromMap({'nom': 'CHU'}, 'h1'),
                Hopital.fromMap({'nom': 'Clinique'}, 'h2'),
              ];
            }),
            child: const Text('recharger'),
          ),
        ],
      ),
    );
  }
}

/// Formulaire minimal : recherche + médecin, avec désélection automatique.
class _FormulaireMedecin extends StatefulWidget {
  const _FormulaireMedecin();
  @override
  State<_FormulaireMedecin> createState() => _FormulaireMedecinState();
}

class _FormulaireMedecinState extends State<_FormulaireMedecin> {
  final _controller = TextEditingController();
  Medecin? _choisi;
  String _recherche = '';
  final List<Medecin> _medecins = [
    Medecin(
      id: 'm1',
      nom: 'Moulekissi christiana',
      prenom: '',
      specialite: 'Cardiologie',
      hopitalId: 'h1',
      hopitalNom: '',
    ),
    Medecin(
      id: 'm2',
      nom: 'Obame sarah',
      prenom: '',
      specialite: 'Pédiatrie',
      hopitalId: 'h1',
      hopitalNom: '',
    ),
  ];

  List<Medecin> get _filtres {
    final texte = _recherche.trim().toLowerCase();
    if (texte.isEmpty) return _medecins;
    return _medecins.where((m) => m.nomComplet.toLowerCase().contains(texte)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextField(
            controller: _controller,
            onChanged: (valeur) {
              setState(() => _recherche = valeur);
              final ids = _filtres.map((m) => m.id).toSet();
              if (_choisi != null && !ids.contains(_choisi!.id)) _choisi = null;
            },
          ),
          DropdownButtonFormField<Medecin>(
            initialValue: _choisi,
            items: _filtres.map((m) => DropdownMenuItem(value: m, child: Text(m.nom))).toList(),
            onChanged: (m) => setState(() => _choisi = m),
          ),
        ],
      ),
    );
  }
}
