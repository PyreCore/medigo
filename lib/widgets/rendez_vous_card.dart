// Package standard de Flutter qui fournit tous les widgets visuels
// prêts à l'emploi (boutons, textes, listes, couleurs Material Design...).
import 'package:flutter/material.dart';
import '../models/rendez_vous.dart';

// Fonction "libre" (pas dans une classe) qui associe une couleur à
// chaque statut de rendez-vous. On la met ici, à côté du widget qui
// s'en sert le plus, mais comme elle est publique (pas de underscore _),
// d'autres fichiers peuvent aussi l'utiliser en l'important.
Color couleurStatutRdv(StatutRendezVous statut) {
  // "switch" sur une valeur d'enum : chaque "case" correspond à une
  // valeur possible de StatutRendezVous.
  switch (statut) {
    case StatutRendezVous.confirme:
      // "const" = cette couleur est calculée une seule fois à la compilation,
      // pas recréée à chaque fois que la fonction est appelée (plus rapide).
      // 0xFF2E7D32 est un code couleur hexadécimal : FF = opacité pleine,
      // 2E7D32 = un vert.
      return const Color(0xFF2E7D32);
    case StatutRendezVous.enAttente:
      return const Color(0xFFD98E04); // orange
    // Deux "case" collés sans "return" entre eux = même résultat pour les
    // deux : refusé ET annulé affichent la même couleur (rouge).
    case StatutRendezVous.refuse:
    case StatutRendezVous.annule:
      return const Color(0xFFC62828); // rouge
    case StatutRendezVous.termine:
      return Colors.black45; // gris (couleur prédéfinie de Flutter)
  }
}

// Même principe, mais pour le texte affiché à l'utilisateur (en français,
// alors que l'enum est en anglais/camelCase pour respecter les
// conventions de code Dart).
String libelleStatutRdv(StatutRendezVous statut) {
  switch (statut) {
    case StatutRendezVous.confirme:
      return 'Confirmé';
    case StatutRendezVous.enAttente:
      return 'En attente';
    case StatutRendezVous.refuse:
      return 'Refusé';
    case StatutRendezVous.annule:
      return 'Annulé';
    case StatutRendezVous.termine:
      return 'Terminé';
  }
}

/// Carte cliquable représentant un rendez-vous.
/// Utilisée sur le tableau de bord et sur l'écran "liste des rendez-vous".
// "StatelessWidget" = un widget qui n'a pas de mémoire interne : il
// affiche toujours la même chose tant qu'on ne lui redonne pas de
// nouvelles données depuis l'extérieur (par opposition à StatefulWidget,
// qui peut changer tout seul, voir plus bas dans d'autres fichiers).
class RendezVousCard extends StatelessWidget {
  // Les données que ce widget a besoin de recevoir pour s'afficher.
  final RendezVous rdv; // le rendez-vous à afficher
  // Une fonction à appeler quand on tape sur la carte. Le "?" la rend
  // optionnelle : si on ne la fournit pas, la carte ne réagit pas au clic.
  final VoidCallback? onTap;

  // Nouveau paramètre, "false" par défaut : quand la secrétaire affiche
  // sa liste de rendez-vous (plusieurs médecins mélangés), elle a besoin
  // de voir le nom du médecin concerné. Côté médecin, on laisse la valeur
  // par défaut (false) : pas besoin, il ne voit que ses propres rendez-vous.
  final bool afficherMedecin;

  // Constructeur. "super.key" transmet le paramètre "key" à la classe
  // parente (StatelessWidget) : c'est une convention Flutter qui aide
  // le framework à identifier ce widget précis quand il redessine l'écran.
  const RendezVousCard({
    super.key,
    required this.rdv,
    this.onTap,
    this.afficherMedecin = false, // valeur par défaut si on ne précise rien
  });

  // La méthode build() décrit CE QUI DOIT S'AFFICHER À L'ÉCRAN.
  // Flutter l'appelle automatiquement à chaque fois qu'il a besoin de
  // (re)dessiner ce widget. "BuildContext context" donne accès à des
  // infos sur la position de ce widget dans l'arbre de l'application
  // (thème, taille de l'écran, navigation...).
  @override
  Widget build(BuildContext context) {
    // On calcule une fois la couleur correspondant au statut, pour ne
    // pas répéter couleurStatutRdv(rdv.statut) plusieurs fois plus bas.
    final couleur = couleurStatutRdv(rdv.statut);

    // InkWell rend n'importe quel widget cliquable, avec un petit effet
    // visuel "d'encre qui s'étale" au clic (typique Material Design).
    return InkWell(
      onTap: onTap, // fonction appelée au clic (peut être null = pas cliquable)
      // Arrondit aussi l'effet visuel du clic pour qu'il suive la forme
      // de la carte (sinon l'effet déborderait en rectangle).
      borderRadius: BorderRadius.circular(14),
      child: Container(
        // Espace vide EN DEHORS du cadre (entre cette carte et les autres).
        margin: const EdgeInsets.only(bottom: 10),
        // Espace vide À L'INTÉRIEUR du cadre (entre le bord et le contenu).
        padding: const EdgeInsets.all(14),
        // "decoration" permet de styliser le fond, les bords, les coins...
        decoration: BoxDecoration(
          color: Colors.white, // fond blanc
          borderRadius: BorderRadius.circular(14), // coins arrondis
          // Bordure fine, presque invisible (6% d'opacité de noir).
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        // "Row" aligne ses enfants HORIZONTALEMENT, les uns à côté des autres.
        child: Row(
          children: [
            // Petit trait de couleur vertical à gauche de la carte,
            // qui indique visuellement le statut d'un coup d'œil.
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: couleur,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Espace vide fixe de 12 pixels entre le trait et le texte.
            const SizedBox(width: 12),
            // "Expanded" dit à ce widget de prendre TOUT l'espace
            // horizontal restant dans la Row (sinon le texte pourrait
            // être coupé ou la Row planterait si le contenu est trop large).
            Expanded(
              // "Column" aligne ses enfants VERTICALEMENT, les uns
              // au-dessus des autres.
              child: Column(
                // Aligne le texte à gauche (au lieu du centre par défaut).
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // Getter défini dans le modèle RendezVous :
                    // combine prénom + nom du patient.
                    rdv.patientNomComplet,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2), // petit espace vertical
                  Text(
                    // "if (condition) ... else ..." dans un template de texte
                    // n'existe pas directement : on utilise l'opérateur "?:"
                    // pour choisir le texte à afficher selon afficherMedecin.
                    afficherMedecin && rdv.medecinNom != null
                        ? '${rdv.heure} · ${rdv.medecinNom}'
                        : rdv.heure,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Petit badge coloré affichant le statut en toutes lettres
            // (ex: "Confirmé"), à droite de la carte.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                // Même couleur que le trait, mais très transparente (12%),
                // pour un fond pastel assorti au statut.
                color: couleur.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                libelleStatutRdv(rdv.statut),
                style: TextStyle(
                  color: couleur, // texte dans la couleur pleine du statut
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Petite flèche ">" tout à droite, qui suggère visuellement
            // "tape ici pour voir plus de détails".
            const Icon(Icons.chevron_right, color: Colors.black26, size: 20),
          ],
        ),
      ),
    );
  }
}
