// ─────────────────────────────────────────────────────────────────────
// CARTE DE RENDEZ-VOUS — composant partagé (médecin + secrétaire).
// Refaite sur le design system Medigo (lib/theme/medigo_theme.dart) :
// carte blanche arrondie + ombre douce, pastille horaire à gauche,
// badge de statut coloré à droite, effet de survol sur web.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../models/rendez_vous.dart';
import '../theme/medigo_theme.dart';
import 'ui_kit.dart';

/// Associe une couleur de la palette Medigo à chaque statut.
/// (Fonction publique : d'autres écrans peuvent l'importer.)
Color couleurStatutRdv(StatutRendezVous statut) {
  // "switch" sur une valeur d'enum : chaque "case" correspond à une
  // valeur possible de StatutRendezVous.
  switch (statut) {
    case StatutRendezVous.confirme:
      return AppColors.vertSante; // vert santé : c'est validé
    case StatutRendezVous.enAttente:
      return AppColors.ambre; // ambre : ça attend une décision
    // Deux "case" collés sans "return" entre eux = même résultat :
    // refusé ET annulé partagent le même rouge.
    case StatutRendezVous.refuse:
    case StatutRendezVous.annule:
      return AppColors.rouge;
    case StatutRendezVous.termine:
      return AppColors.texteFaible; // gris-bleu discret : terminé
  }
}

/// Libellé français de chaque statut (l'enum, elle, reste en anglais
/// pour respecter les conventions de nommage Dart).
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

/// Badge coloré du statut (« Confirmé », « En attente"...).
/// Réutilisé par la carte ci-dessous et par les écrans de détail.
class ChipStatutRdv extends StatelessWidget {
  final StatutRendezVous statut;

  const ChipStatutRdv({super.key, required this.statut});

  @override
  Widget build(BuildContext context) {
    final couleur = couleurStatutRdv(statut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        // Couleur pleine diluée à 12 % → fond pastel assorti au statut.
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Rayons.pillule),
      ),
      child: Text(
        libelleStatutRdv(statut),
        style: TextStyle(
          color: couleur,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Carte de rendez-vous complète (médecin + secrétaire).
class RendezVousCard extends StatelessWidget {
  final RendezVous rdv;
  final VoidCallback? onTap;
  final bool afficherMedecin;
  final bool afficherPatient;

  // Constructeur. "super.key" transmet le paramètre "key" à la classe
  // parente (StatelessWidget) : c'est une convention Flutter qui aide
  // le framework à identifier ce widget précis quand il redessine l'écran.
  const RendezVousCard({
    super.key,
    required this.rdv,
    this.onTap,
    this.afficherMedecin = false, // valeur par défaut si on ne précise rien
    this.afficherPatient = true,
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
                    // Côté patient (afficherPatient: false), on affiche
                    // plutôt le médecin ; et si le rendez-vous n'a pas de
                    // médecin renseigné, on retombe sur le nom du patient
                    // pour ne jamais afficher une ligne vide.
                    afficherPatient
                        ? rdv.patientNomComplet
                        : (rdv.medecinNom ?? rdv.patientNomComplet),
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

/// Panneau « répartition du jour » : comptage des rendez-vous par
/// statut, en lignes « libellé …… nombre » — sans icône.
/// Utilisé dans le panneau latéral des deux dashboards.
class RepartitionStatuts extends StatelessWidget {
  final List<RendezVous> rdvs;

  const RepartitionStatuts({super.key, required this.rdvs});

  @override
  Widget build(BuildContext context) {
    int nb(StatutRendezVous s) => rdvs.where((r) => r.statut == s).length;

    // (libellé, nombre, couleur) — record Dart 3.
    final lignes = <(String, int, Color)>[
      ('Confirmés', nb(StatutRendezVous.confirme), AppColors.vertSante),
      ('En attente', nb(StatutRendezVous.enAttente), AppColors.ambre),
      ('Terminés', nb(StatutRendezVous.termine), AppColors.texteFaible),
      (
        'Annulés / refusés',
        nb(StatutRendezVous.annule) + nb(StatutRendezVous.refuse),
        AppColors.rouge,
      ),
    ];

    return CarteMedigo(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
      child: Column(
        children: [
          for (var i = 0; i < lignes.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      lignes[i].$1,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.texteFaible,
                      ),
                    ),
                  ),
                  Text(
                    lignes[i].$2.toString(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: lignes[i].$3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
