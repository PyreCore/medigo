import 'package:flutter/material.dart';

import 'regle_mot_de_passe.dart';

/// Champ mot de passe complet utilisé dans TOUS les formulaires de
/// création de compte (admin, admin hôpital, médecin, secrétaire, patient).
///
/// Comprend :
///  · le champ masqué avec l'œil « afficher / masquer » ;
///  · la LIGNE DE FORCE animée, qui se remplit en changeant de couleur
///    (rouge = faible, jaune = moyen, vert = bon / excellent) ;
///  · la liste des 4 critères cochés en direct, comme dans la maquette ;
///  · le rapport de validité au parent via [onValideChange], pour
///    désactiver le bouton « Enregistrer » tant que tout n'est pas bon.
class ChampMotDePasse extends StatefulWidget {
  const ChampMotDePasse({
    super.key,
    required this.controller,
    this.libelle = 'Mot de passe',
    this.hint = '8 caractères minimum, chiffres et caractère spécial',
    this.onValideChange,
    this.montrerAide = true,
    this.occulteAuDebut = true,
    this.bordure,
  });

  /// Contrôleur partagé avec le formulaire parent.
  final TextEditingController controller;

  /// Bordure appliquée au champ (null = thème par défaut). Permet
  /// d'aligner le champ sur les autres d'un formulaire donné.
  final InputBorder? bordure;

  /// Libellé du champ (ex. « Mot de passe »).
  final String libelle;

  /// Texte d'invitation affiché tant que le champ est vide.
  final String hint;

  /// Appelé à chaque frappe avec true si le mot de passe est valable.
  final ValueChanged<bool>? onValideChange;

  /// Affiche la ligne de force et les 4 critères.
  final bool montrerAide;

  /// Champ masqué au chargement (recommandé : l'œil permet d'afficher).
  final bool occulteAuDebut;

  @override
  State<ChampMotDePasse> createState() => _ChampMotDePasseState();
}

class _ChampMotDePasseState extends State<ChampMotDePasse> {
  late bool _masque = widget.occulteAuDebut;

  @override
  void initState() {
    super.initState();
    // On informe le parent de l'état initial APRÈS la première frame :
    // appeler un setState parent pendant le build lèverait une exception.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onValideChange?.call(motDePasseValide(widget.controller.text));
    });
  }

  void _taper(String valeur) {
    setState(() {}); // recalcule la ligne et les cochages
    widget.onValideChange?.call(motDePasseValide(valeur));
  }

  @override
  Widget build(BuildContext context) {
    final valeur = widget.controller.text;
    final score = scoreMotDePasse(valeur);
    final couleur = forceCouleur(score);
    final criteres = criteresMotDePasse(valeur);
    final vide = valeur.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          obscureText: _masque,
          onChanged: _taper,
          decoration: InputDecoration(
            labelText: widget.libelle,
            hintText: widget.hint,
            border: widget.bordure,
            // Pas de message rouge tant que l'utilisateur n'a rien tapé :
            // on montre les critères, on ne crie pas sur un champ vide.
            errorText: vide ? null : erreurMotDePasse(valeur),
            suffixIcon: IconButton(
              icon: Icon(_masque ? Icons.visibility_off : Icons.visibility),
              tooltip: _masque ? 'Afficher' : 'Masquer',
              onPressed: () => setState(() => _masque = !_masque),
            ),
          ),
        ),
        if (widget.montrerAide) ...[
          const SizedBox(height: 14),
          _LigneForce(
            ratio: vide ? 0 : score / criteres.length,
            couleur: couleur,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                vide ? 'Force du mot de passe' : 'Force : ${forceLibelle(score)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: vide ? Colors.grey.shade500 : couleur,
                ),
              ),
              const Spacer(),
              Text(
                '$score / ${criteres.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: vide ? Colors.grey.shade500 : couleur,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Le mot de passe doit contenir les éléments suivants :',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final critere in criteres) _LigneCritere(critere: critere),
        ],
      ],
    );
  }
}

/// Barre de progression de la force : se remplit et change de couleur
/// avec une transition animée de 350 ms.
class _LigneForce extends StatelessWidget {
  const _LigneForce({required this.ratio, required this.couleur});

  final double ratio;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    // NB deux pièges, corrigés ici :
    //
    // 1) PAS de `width: double.infinity` sur le Container. AlertDialog
    //    calcule la largeur de son contenu de façon « intrinsèque » ;
    //    une largeur infinie casse ce calcul ('width.isFinite') et la
    //    fenêtre entière ne s'affiche plus. Le Column du parent est en
    //    crossAxisAlignment.stretch, il donne déjà la largeur.
    //
    // 2) FractionallySizedBox calcule en intrinsèque
    //    largeurEnfant / widthFactor. Avec widthFactor = 0 (champ
    //    encore vide), c'est une division par zéro → NaN/Infini, même
    //    assertion 'width.isFinite' → fenêtre invisible. On borne donc
    //    le facteur à une valeur strictement positive : la barre reste
    //    vide à l'œil nu (0,1 %) mais le calcul reste fini.
    final facteur = ratio.clamp(0.001, 1.0);

    return Container(
      height: 8,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: facteur,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          height: 8,
          decoration: BoxDecoration(
            color: couleur,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

/// Une exigence de la maquette : pastille cochée (vert) ou vide (gris).
class _LigneCritere extends StatelessWidget {
  const _LigneCritere({required this.critere});

  /// (libellé, satisfait ?)
  final (String, bool) critere;

  @override
  Widget build(BuildContext context) {
    final ok = critere.$2;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.only(top: 1),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: ok ? const Color(0xFF1B7F3B) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: ok ? const Color(0xFF1B7F3B) : Colors.grey.shade400,
                width: 1.6,
              ),
            ),
            child: ok
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                fontWeight: ok ? FontWeight.w700 : FontWeight.w500,
                color: ok ? const Color(0xFF1B7F3B) : Colors.black54,
              ),
              child: Text(critere.$1),
            ),
          ),
        ],
      ),
    );
  }
}
