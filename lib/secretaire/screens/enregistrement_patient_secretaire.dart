import 'package:flutter/material.dart';
import '../../theme/maquette_tokens.dart';
import '../../widgets/maquette_widgets.dart'; // BoutonDegradeSpec (chargement)

// ─────────────────────────────────────────────────────────────────────
// FORMULAIRE « NOUVEAU PATIENT » (SECRÉTAIRE) — maquette § formulaires.
//
//  · validation EN DIRECT : message sous le champ dès qu'il a été
//    touché puis vidé (nom, prénom, téléphone obligatoires) ;
//  · bouton DÉSACTIVÉ (gris) tant que le formulaire est incomplet,
//    puis indicateur de chargement pendant l'envoi (champs verrouillés) ;
//  · bordure de focus bleu maquette #2458D3 (1,6 px) — MaquetteCouleurs.bleu ;
//  · claviers adaptés : name (noms), phone (téléphone), capitales
//    (groupe sanguin) ; « Entrée » passe au champ suivant, « Terminé »
//    sur le dernier déclenche la validation ;
//  · entrée des champs en fondu + glissement (stagger 650 ms) ;
//  · succès ANIMÉ (cercle dégradé + liseré « Patient enregistré »)
//    puis retour automatique à la liste des patients.
//
// LOGIQUE INCHANGÉE : mêmes champs, même règle d'obligation, même
// chemin d'enregistrement (onValider → EspaceSecretaire → chargeur →
// SecretaireService). SEUL le moment du retour change : le formulaire
// se ferme APRÈS son animation de succès — d'où la signature
// Future<void> de onValider (l'état de chargement doit pouvoir être
// honnête, il reflète l'écriture Firestore réelle).
// ─────────────────────────────────────────────────────────────────────
class EnregistrementPatientSecretaire extends StatefulWidget {
  // Fonction appelée quand on valide le formulaire, avec les valeurs
  // saisies en paramètres. ASYNCHRONE : le formulaire attend la fin de
  // l'enregistrement (Firestore) avant d'afficher son succès.
  final Future<void> Function({
    required String nom,
    required String prenom,
    required String telephone,
    String? groupeSanguin,
  }) onValider;

  const EnregistrementPatientSecretaire({super.key, required this.onValider});

  @override
  State<EnregistrementPatientSecretaire> createState() =>
      _EnregistrementPatientSecretaireState();
}

class _EnregistrementPatientSecretaireState
    extends State<EnregistrementPatientSecretaire>
    with SingleTickerProviderStateMixin {
  // Les 4 contrôleurs de champ (le texte tapé entre deux frappes).
  final _controllerNom = TextEditingController();
  final _controllerPrenom = TextEditingController();
  final _controllerTelephone = TextEditingController();
  final _controllerGroupeSanguin = TextEditingController();

  // Nœuds de focus : « Entrée » passe explicitement au champ suivant
  // (ordre garanti, indépendant de la traversée des focus).
  final _focusNom = FocusNode();
  final _focusPrenom = FocusNode();
  final _focusTelephone = FocusNode();
  final _focusGroupe = FocusNode();

  // Animation d'ENTRÉE (fondu + glissement, décalage par champ).
  late final AnimationController _entree = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  // Champs déjà touchés par l'utilisateur (pour la validation live :
  // on ne montre l'erreur QUE sur un champ touché, pas au premier rendu).
  final _touche = <String>{};

  bool _soumis = false; // validation faite depuis le clavier (« Terminé »)
  bool _envoiEnCours = false; // état de chargement (écriture Firestore)
  bool _succes = false; // animation de succès affichée

  @override
  void dispose() {
    _controllerNom.dispose();
    _controllerPrenom.dispose();
    _controllerTelephone.dispose();
    _controllerGroupeSanguin.dispose();
    _focusNom.dispose();
    _focusPrenom.dispose();
    _focusTelephone.dispose();
    _focusGroupe.dispose();
    _entree.dispose();
    super.dispose();
  }

  /// Le formulaire est complet ? (identique à l'ancienne règle :
  /// nom, prénom et téléphone non vides après trim).
  bool get _formulaireValide =>
      _controllerNom.text.trim().isNotEmpty &&
      _controllerPrenom.text.trim().isNotEmpty &&
      _controllerTelephone.text.trim().isNotEmpty;

  /// Message d'erreur live : seulement si le champ a été touché (ou
  /// soumis depuis le clavier) ET qu'il est encore vide.
  String? _erreurChamp(String champ, String valeur) {
    if (!_soumis && !_touche.contains(champ)) return null;
    if (valeur.trim().isNotEmpty) return null;
    switch (champ) {
      case 'nom':
        return 'Le nom est obligatoire';
      case 'prenom':
        return 'Le prénom est obligatoire';
      case 'telephone':
        return 'Le téléphone est obligatoire';
    }
    return null;
  }

  // Marque un champ comme "touché" → son message d'erreur s'affiche
  // (validation en direct) et le bouton se revalide à chaque frappe.
  void _saisie(String champ) {
    setState(() {
      _touche.add(champ);
    });
  }

  Future<void> _valider() async {
    // Garde anti-double-tap pendant l'envoi / après le succès.
    if (_envoiEnCours || _succes) return;

    // Le bouton est désactivé si le formulaire est incomplet, mais
    // « Terminé » sur le dernier champ peut contourner ce parcours :
    // on affiche alors toutes les erreurs.
    setState(() => _soumis = true);
    if (!_formulaireValide) return;

    setState(() => _envoiEnCours = true);
    try {
      // On ATTEND réellement l'écriture Firestore (chaîne
      // onValider → chargeur → SecretaireService).
      await widget.onValider(
        nom: _controllerNom.text.trim(),
        prenom: _controllerPrenom.text.trim(),
        telephone: _controllerTelephone.text.trim(),
        // Champ optionnel : on transmet null plutôt qu'une chaîne vide.
        groupeSanguin: _controllerGroupeSanguin.text.trim().isEmpty
            ? null
            : _controllerGroupeSanguin.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _envoiEnCours = false;
        _succes = true;
      });
      // Succès animé visible, puis retour automatique à la liste.
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Échec (règles Firestore, réseau…) : on rouvre le formulaire.
      if (!mounted) return;
      setState(() => _envoiEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enregistrement impossible : $e')),
      );
    }
  }

  // Enveloppe animée : fondu + glissement vers le haut, avec un
  // décalage progressif par champ (stagger).
  Widget _anime(int index, Widget enfant) {
    final interval = Interval(
      0.11 * index,
      0.11 * index + 0.5,
      curve: Curves.easeOutCubic,
    );
    final anim = _entree.drive(CurveTween(curve: interval));
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(anim),
        child: enfant,
      ),
    );
  }

  InputDecoration _decoration(String label, {String? erreur}) {
    const rayon = BorderRadius.all(Radius.circular(12));
    return InputDecoration(
      labelText: label,
      errorText: erreur,
      errorStyle: const TextStyle(
        fontSize: 12,
        color: MaquetteCouleurs.refuseTexte,
      ),
      labelStyle: const TextStyle(
        fontSize: 14,
        color: MaquetteCouleurs.texteSecondaire,
      ),
      filled: true,
      fillColor: MaquetteCouleurs.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: const OutlineInputBorder(
        borderRadius: rayon,
        borderSide: BorderSide(color: MaquetteCouleurs.bordure),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: rayon,
        borderSide: BorderSide(color: MaquetteCouleurs.bordure),
      ),
      // Focus maquette : bleu #2458D3, 1,6 px (MaquetteCouleurs.bleu).
      focusedBorder: const OutlineInputBorder(
        borderRadius: rayon,
        borderSide: BorderSide(color: MaquetteCouleurs.bleu, width: 1.6),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: rayon,
        borderSide: BorderSide(color: MaquetteCouleurs.refuseTexte),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: rayon,
        borderSide: BorderSide(color: MaquetteCouleurs.refuseTexte, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MaquetteCouleurs.fond,
      appBar: AppBar(title: const Text('Nouveau patient')),
      // Après succès : l'écran de confirmation animé remplace le formulaire.
      body: _succes ? _vueSucces() : _formulaire(),
    );
  }

  Widget _formulaire() {
    // Champs verrouillés pendant l'envoi (pas de modification en cours
    // d'écriture Firestore).
    final verrouille = _envoiEnCours;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _anime(
          0,
          TextField(
            controller: _controllerNom,
            focusNode: _focusNom,
            enabled: !verrouille,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: _decoration(
              'Nom',
              erreur: _erreurChamp('nom', _controllerNom.text),
            ),
            onChanged: (_) => _saisie('nom'),
            onSubmitted: (_) => _focusPrenom.requestFocus(),
          ),
        ),
        const SizedBox(height: 12),
        _anime(
          1,
          TextField(
            controller: _controllerPrenom,
            focusNode: _focusPrenom,
            enabled: !verrouille,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: _decoration(
              'Prénom',
              erreur: _erreurChamp('prenom', _controllerPrenom.text),
            ),
            onChanged: (_) => _saisie('prenom'),
            onSubmitted: (_) => _focusTelephone.requestFocus(),
          ),
        ),
        const SizedBox(height: 12),
        _anime(
          2,
          TextField(
            controller: _controllerTelephone,
            focusNode: _focusTelephone,
            enabled: !verrouille,
            // Clavier téléphonique (chiffres + symboles du téléphone).
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: _decoration(
              'Téléphone',
              erreur: _erreurChamp('telephone', _controllerTelephone.text),
            ),
            onChanged: (_) => _saisie('telephone'),
            onSubmitted: (_) => _focusGroupe.requestFocus(),
          ),
        ),
        const SizedBox(height: 12),
        _anime(
          3,
          TextField(
            controller: _controllerGroupeSanguin,
            focusNode: _focusGroupe,
            enabled: !verrouille,
            keyboardType: TextInputType.text,
            // « Terminé » sur le dernier champ → validation directe.
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: _decoration('Groupe sanguin (optionnel)'),
            onChanged: (_) => _saisie('groupe'),
            onSubmitted: (_) => _valider(),
          ),
        ),
        const SizedBox(height: 24),
        _anime(
          4,
          // Désactivé (gris) tant que le formulaire est incomplet ;
          // indicateur de progression pendant l'envoi.
          BoutonDegradeSpec(
            texte: 'Enregistrer',
            chargement: _envoiEnCours,
            onPressed: (!_formulaireValide && !_envoiEnCours)
                ? null
                : _valider,
          ),
        ),
      ],
    );
  }

  // ── Succès animé ──────────────────────────────────────────────────
  Widget _vueSucces() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutBack,
        builder: (context, valeur, enfant) => Opacity(
          // easeOutBack dépasse légèrement 1 : on borne pour l'opacité.
          opacity: valeur.clamp(0.0, 1.0).toDouble(),
          child: Transform.scale(scale: valeur, child: enfant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                gradient: MaquetteDegrades.principal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Patient enregistré',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: MaquetteCouleurs.texte,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Retour à la liste…',
              style: TextStyle(
                fontSize: 13,
                color: MaquetteCouleurs.texteSecondaire,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
