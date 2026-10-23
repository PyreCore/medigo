import 'package:flutter/material.dart';
import '../../services/secretaire_service.dart';
import '../../theme/maquette_tokens.dart';
import '../../widgets/maquette_widgets.dart'; // BoutonPleinSpec (chargement)

// ─────────────────────────────────────────────────────────────────────
// REFUS D'UN RENDEZ-VOUS (SECRÉTAIRE) — maquette §4.3.
//
// La secrétaire choisit un motif parmi une liste prédéfinie (ou saisit
// un motif personnalisé), puis confirme le refus. Le refus est
// définitif : le rendez-vous passe au statut "refusé" et le créneau
// est libéré.
//
// Habillage maquette :
//  · lignes de motifs en fondu + glissement (stagger) ;
//  · sélection = pastille rouge + fond rouge clair (refuseFond) ;
//  · champ « Autre motif » avec bordure de focus #2458D3 et aide en
//    direct (« Merci de préciser le motif ») ;
//  · bouton rouge maquette (BoutonPleinSpec) désactivé (gris) tant que
//    le motif est vide, spinner pendant l'envoi ;
//  · succès ANIMÉ (« Rendez-vous refusé ») puis fermeture.
//
// LOGIQUE INCHANGÉE : mêmes motifs prédéfinis (SecretaireService.
// motifsRefus), même règle (« Autre motif » exige une saisie), même
// chemin (onRefuser → détail → EspaceSecretaire → chargeur →
// SecretaireService). Le motif envoyé reste un SEUL texte (étiquette
// prédéfinie OU saisie libre).
//
// Fermeture : après le succès, le formulaire se referme PUIS le détail
// du rendez-vous sous-jacent est refermé aussi — l'utilisateur retombe
// sur la liste (le détail afficherait un statut périmé). C'est le
// double-pop de _confirmerRefus ; le détail et l'espace ne poppent
// plus rien pour ce formulaire (voir detail_rendez_vous_secretaire).
// ─────────────────────────────────────────────────────────────────────
class RefuserRendezVousSecretaire extends StatefulWidget {
  final String rdvId;

  /// Enregistre le refus (chaîne jusqu'à SecretaireService). Le
  /// formulaire ATTEND ce Future avant d'afficher son succès.
  final Future<void> Function(String rdvId, {String? motif}) onRefuser;

  const RefuserRendezVousSecretaire({
    super.key,
    required this.rdvId,
    required this.onRefuser,
  });

  @override
  State<RefuserRendezVousSecretaire> createState() =>
      _RefuserRendezVousSecretaireState();
}

class _RefuserRendezVousSecretaireState
    extends State<RefuserRendezVousSecretaire>
    with SingleTickerProviderStateMixin {
  // Index du motif sélectionné dans la liste prédéfinie.
  // null = rien encore sélectionné.
  int? _motifSelectionne;

  // Contrôleur pour le champ "Autre motif" (saisie libre).
  final _controleurMotif = TextEditingController();

  // Vrai pendant l'appel à Firestore (évite le double-clic).
  bool _envoiEnCours = false;

  // Vrai quand la saisie libre a été touchée (aide en direct) et quand
  // l'animation de succès est affichée.
  bool _saisieTouchee = false;
  bool _succes = false;

  // Animation d'ENTRÉE (fondu + glissement, décalage par ligne).
  late final AnimationController _entree = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  @override
  void dispose() {
    _controleurMotif.dispose();
    _entree.dispose();
    super.dispose();
  }

  bool get _estAutreMotif =>
      _motifSelectionne == SecretaireService.motifsRefus.length - 1;

  /// Le bouton "Confirmer le refus" n'est actif que si un motif est
  /// choisi (et, pour "Autre motif", si le champ n'est pas vide).
  bool get _peutRefuser {
    if (_motifSelectionne == null) return false;
    // Dernier élément = "Autre motif" : exige une saisie.
    if (_estAutreMotif) return _controleurMotif.text.trim().isNotEmpty;
    return true;
  }

  Future<void> _confirmerRefus() async {
    if (!_peutRefuser || _envoiEnCours) return;

    setState(() => _envoiEnCours = true);

    // Si "Autre motif" est sélectionné, on utilise la saisie libre.
    // Sinon, on utilise le texte du motif prédéfini choisi.
    final motif = _estAutreMotif
        ? _controleurMotif.text.trim()
        : SecretaireService.motifsRefus[_motifSelectionne!];

    try {
      // On ATTEND réellement l'écriture Firestore.
      await widget.onRefuser(widget.rdvId, motif: motif);
      if (!mounted) return;
      setState(() {
        _envoiEnCours = false;
        _succes = true;
      });
      // Succès animé visible, puis fermeture : le formulaire ET le
      // détail du rendez-vous ( juste en dessous ), pour retomber sur
      // la liste.
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) {
        final navigator = Navigator.of(context);
        navigator.pop(); // le formulaire de refus
        navigator.pop(); // le détail du rendez-vous (statut périmé)
      }
    } catch (e) {
      // Échec (règles Firestore, réseau…) : on rouvre le formulaire.
      if (!mounted) return;
      setState(() => _envoiEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refus impossible : $e')),
      );
    }
  }

  // Enveloppe animée : fondu + glissement vers le haut, avec un
  // décalage progressif par ligne (stagger).
  Widget _anime(int index, Widget enfant) {
    final interval = Interval(
      0.09 * index,
      // Borné à 1 : Interval exige end <= 1 (index max du formulaire).
      (0.09 * index + 0.5).clamp(0.0, 1.0).toDouble(),
      curve: Curves.easeOutCubic,
    );
    final anim = _entree.drive(CurveTween(curve: interval));
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(anim),
        child: enfant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MaquetteCouleurs.fond,
      appBar: AppBar(title: const Text('Refuser le rendez-vous')),
      // Après succès : l'écran de confirmation animé remplace le formulaire.
      body: _succes ? _vueSucces() : _formulaire(),
    );
  }

  Widget _formulaire() {
    final verrouille = _envoiEnCours;
    final autres = SecretaireService.motifsRefus;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // En-tête explicatif : pourquoi cet écran existe.
        _anime(
          0,
          const Text(
            'Choisissez le motif du refus. Il sera visible par le patient '
            'et le médecin concerné.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: MaquetteCouleurs.texteSecondaire,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Liste des motifs prédéfinis : chaque élément est une ligne
        // cliquable avec une case à cocher circulaire (Radio).
        for (var i = 0; i < autres.length; i++)
          _anime(i + 1, _ligneMotif(i, verrouille: verrouille)),

        const SizedBox(height: 24),

        // Bouton de confirmation : rouge maquette (action destructive),
        // gris tant que le motif est vide, spinner pendant l'envoi.
        _anime(
          autres.length + 1,
          BoutonPleinSpec(
            texte: 'Confirmer le refus',
            couleurActive: MaquetteCouleurs.refuseTexte,
            chargement: _envoiEnCours,
            onPressed: _peutRefuser ? _confirmerRefus : null,
          ),
        ),
      ],
    );
  }

  /// Une ligne de la liste : radio + texte du motif.
  /// Si c'est "Autre motif", ajoute un champ de saisie en dessous.
  Widget _ligneMotif(int index, {required bool verrouille}) {
    final estSelectionne = _motifSelectionne == index;
    final estAutre = index == SecretaireService.motifsRefus.length - 1;

    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: verrouille
              ? null
              : () => setState(() => _motifSelectionne = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              // Fond rouge clair quand la ligne est sélectionnée.
              color: estSelectionne
                  ? MaquetteCouleurs.refuseFond
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Radio : cercle vide ou plein selon la sélection.
                Icon(
                  estSelectionne
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: estSelectionne
                      ? MaquetteCouleurs.refuseTexte
                      : MaquetteCouleurs.texteSecondaire,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    SecretaireService.motifsRefus[index],
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: estSelectionne
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: MaquetteCouleurs.texte,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Champ de saisie visible uniquement pour "Autre motif".
        if (estAutre && estSelectionne)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 4, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controleurMotif,
                  enabled: !verrouille,
                  maxLines: 2,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Précisez le motif',
                    // Aide en direct : tant que la saisie est vide.
                    errorText: _saisieTouchee &&
                            _controleurMotif.text.trim().isEmpty
                        ? 'Merci de préciser le motif'
                        : null,
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: MaquetteCouleurs.bordure),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: MaquetteCouleurs.bordure),
                    ),
                    // Focus maquette : bleu #2458D3, 1,6 px.
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(
                        color: MaquetteCouleurs.bleu,
                        width: 1.6,
                      ),
                    ),
                    errorBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(
                        color: MaquetteCouleurs.refuseTexte,
                      ),
                    ),
                    focusedErrorBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(
                        color: MaquetteCouleurs.refuseTexte,
                        width: 1.6,
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() => _saisieTouchee = true),
                ),
              ],
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
                color: MaquetteCouleurs.refuseTexte,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Rendez-vous refusé',
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
