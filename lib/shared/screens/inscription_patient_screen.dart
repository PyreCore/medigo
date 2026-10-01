import 'package:flutter/material.dart';

/// Écran d'INSCRIPTION patient : formulaire pur, sans aucune logique
/// Firestore. Il appelle onValider avec les informations saisies ; c'est
/// InscriptionPatientLoader (le parent) qui branche l'enregistrement réel.
///
/// Aucun hôpital n'est demandé ici : le patient n'est rattaché à aucun
/// établissement, il en choisit un au moment de prendre rendez-vous.
///
/// L'auto-inscription est le point d'entrée du patient dans Medigo :
/// l'app n'avait jusqu'ici que l'écran de connexion, et les patients
/// étaient saisis à l'accueil par la secrétaire, sans compte.
class InscriptionPatientScreen extends StatefulWidget {
  // Appelée quand l'utilisateur valide. Le "? final" (double "?") rend
  // la fonction optionnelle : si le parent ne fournit rien, le bouton
  // de validation est simplement désactivé (comme partout dans l'app).
  final void Function({
    required String nom,
    required String prenom,
    required String email,
    required String motDePasse,
    required String telephone,
    DateTime? dateNaissance,
    String? groupeSanguin,
  })? onValider;

  // Message d'erreur à afficher (ex: "email déjà utilisé"), ou null.
  final String? erreur;

  const InscriptionPatientScreen({
    super.key,
    this.onValider,
    this.erreur,
  });

  @override
  State<InscriptionPatientScreen> createState() =>
      _InscriptionPatientScreenState();
}

class _InscriptionPatientScreenState extends State<InscriptionPatientScreen> {
  // Chaque TextEditingController retient ce que l'utilisateur tape dans
  // UN champ. Ils doivent être libérés dans dispose(), sinon Flutter
  // signale une fuite de mémoire.
  final _controllerNom = TextEditingController();
  final _controllerPrenom = TextEditingController();
  final _controllerEmail = TextEditingController();
  final _controllerMotDePasse = TextEditingController();
  final _controllerTelephone = TextEditingController();
  final _controllerGroupeSanguin = TextEditingController();

  // Valeur du sélecteur de date de naissance. Nullable car rien n'est
  // encore choisi à l'ouverture.
  DateTime? _dateNaissance;

  @override
  void dispose() {
    _controllerNom.dispose();
    _controllerPrenom.dispose();
    _controllerEmail.dispose();
    _controllerMotDePasse.dispose();
    _controllerTelephone.dispose();
    _controllerGroupeSanguin.dispose();
    super.dispose();
  }

  // Ouvre le sélecteur de date natif. On interdit les dates futures.
  Future<void> _choisirDateNaissance() async {
    final maintenant = DateTime.now();
    final resultat = await showDatePicker(
      context: context,
      initialDate: _dateNaissance ?? DateTime(maintenant.year - 30),
      firstDate: DateTime(maintenant.year - 120),
      lastDate: maintenant,
    );
    if (resultat != null) {
      setState(() => _dateNaissance = resultat);
    }
  }

  // Vérifie les champs obligatoires, puis transmet tout au parent.
  void _valider() {
    final nom = _controllerNom.text.trim();
    final prenom = _controllerPrenom.text.trim();
    final email = _controllerEmail.text.trim();
    final motDePasse = _controllerMotDePasse.text;
    final telephone = _controllerTelephone.text.trim();

    // On regroupe les vérifications pour n'afficher qu'un seul message
    // à l'utilisateur plutôt que trois SnackBars successives.
    if (nom.isEmpty || prenom.isEmpty || telephone.isEmpty) {
      _signaler('Merci de renseigner nom, prénom et téléphone');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _signaler('Merci de renseigner un email valide');
      return;
    }
    // 6 caractères est le minimum imposé par Firebase Authentication.
    if (motDePasse.length < 6) {
      _signaler('Le mot de passe doit contenir au moins 6 caractères');
      return;
    }

    final groupeSanguin = _controllerGroupeSanguin.text.trim();
    widget.onValider?.call(
      nom: nom,
      prenom: prenom,
      email: email,
      motDePasse: motDePasse,
      telephone: telephone,
      dateNaissance: _dateNaissance,
      groupeSanguin: groupeSanguin.isEmpty ? null : groupeSanguin,
    );
  }

  void _signaler(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte patient')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Créez votre compte pour prendre et suivre vos rendez-vous.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controllerPrenom,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Prénom',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controllerNom,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nom',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controllerEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controllerMotDePasse,
            // obscureText masque la saisie (le champ est une valeur
            // secrète). Aucune confirmation n'est demandée ici pour
            // garder le formulaire simple ; l'utilisateur peut
            // toujours utiliser "Mot de passe oublié" côté connexion.
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mot de passe (6 caractères minimum)',
              prefixIcon: Icon(Icons.lock),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controllerTelephone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Téléphone',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cake_outlined),
            title: Text(
              _dateNaissance == null
                  ? 'Date de naissance (optionnel)'
                  : '${_dateNaissance!.day}/${_dateNaissance!.month}/${_dateNaissance!.year}',
            ),
            onTap: _choisirDateNaissance,
          ),
          TextField(
            controller: _controllerGroupeSanguin,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Groupe sanguin (optionnel)',
              prefixIcon: Icon(Icons.bloodtype_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          // Erreur renvoyée par le parent (ex: "email déjà utilisé"),
          // affichée sous les champs plutôt qu'en SnackBar pour qu'elle
          // reste visible.
          if (widget.erreur != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.erreur!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: widget.onValider == null ? null : _valider,
              child: const Text(
                'Créer mon compte',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
