// Test de reproduction : le champ mot de passe doit s'afficher DANS une
// fenêtre (AlertDialog + StatefulBuilder), exactement comme dans les
// dialogues « Ajouter un médecin » / « Ajouter une secrétaire ».
//
// Si ce test échoue, c'est que ChampMotDePasse casse l'affichage de la
// fenêtre — ce qui correspond au symptôme « le voile gris apparaît mais
// aucune fenêtre ».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hopital_app/widgets/champ_mot_de_passe.dart';

void main() {
  testWidgets('ChampMotDePasse s\'affiche dans une fenêtre', (tester) async {
    final controller = TextEditingController();
    var mdpValide = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (context) => StatefulBuilder(
                  builder: (context, setDialogState) => AlertDialog(
                    title: const Text('Ajouter un médecin'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: controller,
                            decoration:
                                const InputDecoration(labelText: 'Prénom'),
                          ),
                          const SizedBox(height: 4),
                          ChampMotDePasse(
                            controller: controller,
                            onValideChange: (valide) =>
                                setDialogState(() => mdpValide = valide),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      ElevatedButton(
                        onPressed: !mdpValide ? null : () {},
                        child: const Text('Créer'),
                      ),
                    ],
                  ),
                ),
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    // La fenêtre doit contenir le champ…
    expect(
      find.byType(ChampMotDePasse),
      findsOneWidget,
      reason: 'Le champ mot de passe doit être présent dans la fenêtre',
    );
    // …avec sa liste de critères visible.
    expect(
      find.textContaining('caractères'),
      findsWidgets,
      reason: 'La liste des critères doit être visible',
    );

    // Taper un mot de passe conforme dans le champ MOT DE PASSE (le
    // deuxième TextField : le premier est « Prénom ») doit activer le
    // bouton.
    final champs = find.byType(TextField);
    expect(champs, findsNWidgets(2), reason: 'Prénom + mot de passe');
    await tester.enterText(champs.at(1), 'Abcdefg1!');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ElevatedButton>(find.byType(ElevatedButton).last)
          .onPressed,
      isNotNull,
      reason: 'Le bouton Créer doit s\'activer avec un mot de passe valide',
    );
  });
}
