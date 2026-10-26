import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';
import '../theme/maquette_tokens.dart';

/// Bouton « Se déconnecter » de l'espace administrateur.
/// Violet au repos, il devient ROUGE dès que le curseur passe dessus
/// (survol souris, utile sur le web). Sur mobile, il reste violet.
class BoutonDeconnexion extends StatefulWidget {
  final VoidCallback? onPressed;
  final String texte;

  const BoutonDeconnexion({
    super.key,
    required this.onPressed,
    this.texte = 'Se déconnecter',
  });

  @override
  State<BoutonDeconnexion> createState() => _BoutonDeconnexionState();
}

class _BoutonDeconnexionState extends State<BoutonDeconnexion> {
  bool _survol = false;

  @override
  Widget build(BuildContext context) {
    final actif = widget.onPressed != null;

    return MouseRegion(
      cursor: actif ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (actif) setState(() => _survol = true);
      },
      onExit: (_) {
        if (_survol) setState(() => _survol = false);
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: 48,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _survol ? MaquetteCouleurs.refuseTexte : AdminCouleurs.violet,
            borderRadius: BorderRadius.circular(MaquetteRayons.bouton),
          ),
          child: Text(
            widget.texte,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
