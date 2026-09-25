import 'package:flutter/material.dart';

/// Écran formulaire pour enregistrer un nouveau patient.
/// "StatefulWidget" (et non StatelessWidget) car ce widget doit garder
/// en mémoire ce que l'utilisateur tape dans les champs texte au fur
/// et à mesure, entre chaque frappe au clavier.
class EnregistrementPatientSecretaire extends StatefulWidget {
  // Fonction appelée quand on valide le formulaire, avec les valeurs
  // saisies en paramètres. C'est l'écran parent (espace_secretaire.dart)
  // qui décidera quoi en faire (appeler SecretaireService, par exemple).
  final void Function({
    required String nom,
    required String prenom,
    required String telephone,
    String? groupeSanguin,
  }) onValider;

  const EnregistrementPatientSecretaire({super.key, required this.onValider});

  // Pour un StatefulWidget, build() n'est pas défini ici directement :
  // il faut créer une classe "State" séparée (voir plus bas), et
  // createState() dit à Flutter comment la construire.
  @override
  State<EnregistrementPatientSecretaire> createState() =>
      _EnregistrementPatientSecretaireState();
}

// Convention Dart : le nom de la classe State commence par underscore
// (privée) et reprend le nom du widget avec "State" à la fin.
class _EnregistrementPatientSecretaireState
    extends State<EnregistrementPatientSecretaire> {
  // Un TextEditingController "surveille" un champ de texte : il retient
  // ce qui a été tapé, et permet de le lire au moment de valider
  // (via _controllerNom.text par exemple).
  final _controllerNom = TextEditingController();
  final _controllerPrenom = TextEditingController();
  final _controllerTelephone = TextEditingController();
  final _controllerGroupeSanguin = TextEditingController();

  // "dispose()" est appelé automatiquement par Flutter quand ce widget
  // est définitivement retiré de l'écran (ex: on quitte cet écran).
  // Il faut "libérer" chaque controller ici pour éviter les fuites mémoire.
  @override
  void dispose() {
    _controllerNom.dispose();
    _controllerPrenom.dispose();
    _controllerTelephone.dispose();
    _controllerGroupeSanguin.dispose();
    // "super.dispose()" laisse aussi la classe parente faire son propre
    // nettoyage : toujours l'appeler en dernier.
    super.dispose();
  }

  // Fonction appelée quand on appuie sur le bouton "Enregistrer".
  void _valider() {
    // On vérifie que les champs obligatoires ne sont pas vides avant
    // de continuer. ".trim()" enlève les espaces au début/fin
    // (ex: si l'utilisateur a tapé " Obame " par erreur).
    if (_controllerNom.text.trim().isEmpty ||
        _controllerPrenom.text.trim().isEmpty ||
        _controllerTelephone.text.trim().isEmpty) {
      // ScaffoldMessenger affiche un petit message temporaire en bas
      // de l'écran (une "SnackBar"), ici pour signaler l'erreur.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom, prénom et téléphone sont obligatoires')),
      );
      // "return" arrête la fonction ici : on ne valide pas le formulaire.
      return;
    }

    // On appelle la fonction fournie par le parent, en lui passant
    // les valeurs saisies. widget.onValider (et pas juste onValider)
    // car dans une classe State, il faut passer par "widget." pour
    // accéder aux propriétés du StatefulWidget associé.
    widget.onValider(
      nom: _controllerNom.text.trim(),
      prenom: _controllerPrenom.text.trim(),
      telephone: _controllerTelephone.text.trim(),
      // Si le champ groupe sanguin est vide, on transmet null plutôt
      // qu'une chaîne vide, pour rester cohérent avec le modèle Patient.
      groupeSanguin: _controllerGroupeSanguin.text.trim().isEmpty
          ? null
          : _controllerGroupeSanguin.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau patient')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controllerNom,
            decoration: const InputDecoration(
              labelText: 'Nom',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controllerPrenom,
            decoration: const InputDecoration(
              labelText: 'Prénom',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controllerTelephone,
            // Force le clavier à afficher les chiffres et symboles
            // téléphoniques par défaut, plus pratique pour l'utilisateur.
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Téléphone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controllerGroupeSanguin,
            decoration: const InputDecoration(
              labelText: 'Groupe sanguin (optionnel)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          // SizedBox avec une largeur infinie pour que le bouton
          // occupe toute la largeur disponible.
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _valider,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Enregistrer'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
