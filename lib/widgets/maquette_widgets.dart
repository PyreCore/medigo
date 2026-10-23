// ─────────────────────────────────────────────────────────────────────
// COMPOSANTS LOCAUX DE LA MAQUETTE (espaces Médecin / Secrétaire)
//
// Copies locales des composants de lib/widgets/ui_kit.dart, restylées
// avec les valeurs de MAQUETTE_SPEC.md (jetons : lib/theme/maquette_
// tokens.dart). ui_kit.dart et medigo_theme.dart ne sont PAS modifiés :
// ces widgets sont utilisés UNIQUEMENT par lib/medecin et lib/secretaire
// (et éventuellement par structure_espace.dart).
//
// Les helpers libres (dateDuJour, initiales, jourRelatif…) restent ceux
// de ui_kit.dart : inutile de les dupliquer.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../models/rendez_vous.dart';
import '../theme/maquette_tokens.dart';
import 'ui_kit.dart'; // helpers : initiales(), jourRelatif(), dateDuJour()

// ─────────────────────────────────────────────────────────────────────
// Carte de base de la maquette : blanc, bordure 1 px #E3E8F2, rayon 18.
// (Version légère de CarteMedigo, sans animation de survol, pour
// coller exactement aux valeurs de la maquette.)
// ─────────────────────────────────────────────────────────────────────
class CarteSpec extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final double rayon;
  final Color couleur;

  const CarteSpec({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.rayon = MaquetteRayons.carte,
    this.couleur = MaquetteCouleurs.surface,
  });

  @override
  Widget build(BuildContext context) {
    final container = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.circular(rayon),
        border: Border.all(color: MaquetteCouleurs.bordure),
      ),
      child: child,
    );
    if (onTap == null) return container;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: container),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Pastille de statut (pilule) : fond + texte selon le statut.
// Refusé ET Annulé sont ROUGES (§1 des statuts).
// ─────────────────────────────────────────────────────────────────────
class PastilleStatutSpec extends StatelessWidget {
  final StatutRendezVous statut;

  /// Consultation marquée « non terminée » par le médecin : la pastille
  /// affiche alors « Non terminé » (style neutre pastel orange, le même
  /// que « En attente ») au lieu de « Terminé ». Voir l'arbitrage dans
  /// MedecinService.marquerConsultationNonTerminee.
  final bool nonTermine;

  const PastilleStatutSpec({
    super.key,
    required this.statut,
    this.nonTermine = false,
  });

  /// Vrai seulement si le drapeau est posé SUR un rendez-vous terminé.
  bool get _estNonTermine =>
      nonTermine && statut == StatutRendezVous.termine;

  static Color fond(StatutRendezVous s) {
    switch (s) {
      case StatutRendezVous.confirme:
        return MaquetteCouleurs.confirmeFond;
      case StatutRendezVous.enAttente:
        return MaquetteCouleurs.attenteFond;
      case StatutRendezVous.refuse:
      case StatutRendezVous.annule:
        return MaquetteCouleurs.refuseFond;
      case StatutRendezVous.termine:
        return MaquetteCouleurs.termineFond;
    }
  }

  static Color couleurTexte(StatutRendezVous s) {
    switch (s) {
      case StatutRendezVous.confirme:
        return MaquetteCouleurs.confirmeTexte;
      case StatutRendezVous.enAttente:
        return MaquetteCouleurs.attenteTexte;
      case StatutRendezVous.refuse:
      case StatutRendezVous.annule:
        return MaquetteCouleurs.refuseTexte;
      case StatutRendezVous.termine:
        return MaquetteCouleurs.termineTexte;
    }
  }

  static String libelle(StatutRendezVous s) {
    switch (s) {
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

  @override
  Widget build(BuildContext context) {
    // « Non terminé » : libellé + couleurs neutres (pastel orange),
    // distinct du vert/« Terminé » des consultations abouties.
    final couleurFond =
        _estNonTermine ? MaquetteCouleurs.attenteFond : fond(statut);
    final couleurTexteFinal =
        _estNonTermine ? MaquetteCouleurs.attenteTexte : couleurTexte(statut);
    final libelleAffiche = _estNonTermine ? 'Non terminé' : libelle(statut);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: couleurFond,
        borderRadius: BorderRadius.circular(MaquetteRayons.pillule),
      ),
      child: Text(
        libelleAffiche,
        style: TextStyle(
          fontSize: MaquetteTypo.badgeStatut,
          fontWeight: FontWeight.w700,
          color: couleurTexteFinal,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Puce de filtre (§4.2) : hauteur 44, rayon 22 ; active = dégradé G +
// texte blanc ; inactive = blanc, bordure #E3E8F2.
// ─────────────────────────────────────────────────────────────────────
class ChipFiltreSpec extends StatelessWidget {
  final String label;
  final bool selectionne;
  final VoidCallback onTap;

  const ChipFiltreSpec({
    super.key,
    required this.label,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            gradient: selectionne ? MaquetteDegrades.principal : null,
            color: selectionne ? null : MaquetteCouleurs.surface,
            borderRadius: BorderRadius.circular(MaquetteRayons.puce),
            border: selectionne
                ? null
                : Border.all(color: MaquetteCouleurs.bordure),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selectionne
                  ? Colors.white
                  : MaquetteCouleurs.texte,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Pastille d'heure : carré arrondi bleu clair, heure bleue gras.
// 56 x 56 (rayon 20) dans les listes d'accueil (§4.1).
// ─────────────────────────────────────────────────────────────────────
class PastilleHeureSpec extends StatelessWidget {
  final String heure;
  final double taille;

  const PastilleHeureSpec({super.key, required this.heure, this.taille = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MaquetteCouleurs.bleuClair,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        heure,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: MaquetteCouleurs.bleu,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Avatar à initiales : cercle bleu clair, initiales bleues (§4.2).
// ─────────────────────────────────────────────────────────────────────
class AvatarInitialesSpec extends StatelessWidget {
  final String lettres;

  /// Rayon : 24 → 48 px de large (liste), 28 → 56 px (détail).
  final double rayon;

  const AvatarInitialesSpec({super.key, required this.lettres, this.rayon = 24});

  @override
  Widget build(BuildContext context) {
    final taille = rayon * 2;
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: MaquetteCouleurs.bleuClair,
        shape: BoxShape.circle,
      ),
      child: Text(
        lettres,
        style: TextStyle(
          fontSize: rayon * 0.7,
          fontWeight: FontWeight.w800,
          color: MaquetteCouleurs.bleu,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Carte de rendez-vous du TABLEAU DE BORD (§4.1) : boîte horaire
// 56 x 56, nom 15 px w700, motif 13 px gris, pastille de statut.
// ─────────────────────────────────────────────────────────────────────
class CarteRdvTableauSpec extends StatelessWidget {
  final RendezVous rdv;
  final VoidCallback? onTap;

  /// Sous-titre forcé (ex : « Dr X » côté secrétaire). Sinon : le motif.
  final String? sousTitre;

  /// Consultation marquée « non terminée » → pastille « Non terminé ».
  final bool nonTermine;

  const CarteRdvTableauSpec({
    super.key,
    required this.rdv,
    this.onTap,
    this.sousTitre,
    this.nonTermine = false,
  });

  @override
  Widget build(BuildContext context) {
    final texte = (sousTitre ?? rdv.motif ?? '').trim();
    return CarteSpec(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          PastilleHeureSpec(heure: rdv.heure),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rdv.patientNomComplet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: MaquetteCouleurs.texte,
                  ),
                ),
                if (texte.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    texte,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: MaquetteCouleurs.texteSecondaire,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          PastilleStatutSpec(statut: rdv.statut, nonTermine: nonTermine),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Carte de rendez-vous de la LISTE (§4.2) : avatar initiales 48 px,
// nom, « Aujourd'hui · 09:00 », motif, pastille de statut.
// ─────────────────────────────────────────────────────────────────────
class CarteRdvListeSpec extends StatelessWidget {
  final RendezVous rdv;
  final VoidCallback? onTap;
  final String? sousTitre;

  /// Consultation marquée « non terminée » → pastille « Non terminé ».
  final bool nonTermine;

  const CarteRdvListeSpec({
    super.key,
    required this.rdv,
    this.onTap,
    this.sousTitre,
    this.nonTermine = false,
  });

  @override
  Widget build(BuildContext context) {
    final motif = (sousTitre ?? rdv.motif ?? '').trim();
    return CarteSpec(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          AvatarInitialesSpec(
            lettres: initiales(rdv.patientPrenom, rdv.patientNom),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rdv.patientNomComplet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: MaquetteCouleurs.texte,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${jourRelatif(rdv.date)} · ${rdv.heure}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: MaquetteCouleurs.texteSecondaire,
                  ),
                ),
                if (motif.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    motif,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: MaquetteCouleurs.texteSecondaire,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          PastilleStatutSpec(statut: rdv.statut, nonTermine: nonTermine),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tuile de statistique à icône (§4.1) : pastille d'icône 32 px,
// nombre 26 px, libellé 12 px. Carte blanche bordée, rayon 20 ;
// `fondDegrade` = version dégradé G texte blanc (accueil secrétaire).
// ─────────────────────────────────────────────────────────────────────
class TuileStatSpec extends StatelessWidget {
  final IconData icone;
  final Color couleurIcone;
  final Color fondPastel;
  final String valeur;
  final String libelle;
  final bool fondDegrade;

  const TuileStatSpec({
    super.key,
    required this.icone,
    required this.couleurIcone,
    required this.fondPastel,
    required this.valeur,
    required this.libelle,
    this.fondDegrade = false,
  });

  @override
  Widget build(BuildContext context) {
    final couleurNombre = fondDegrade
        ? Colors.white
        : MaquetteCouleurs.texte;
    final couleurLibelle = fondDegrade
        ? Colors.white.withValues(alpha: 0.85)
        : MaquetteCouleurs.texteSecondaire;

    final contenu = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fondDegrade ? Colors.white.withValues(alpha: 0.18) : fondPastel,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icone,
            size: 17,
            color: fondDegrade ? Colors.white : couleurIcone,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          valeur,
          style: TextStyle(
            fontSize: 26,
            height: 1,
            fontWeight: FontWeight.w800,
            color: couleurNombre,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          libelle,
          maxLines: 2,
          style: TextStyle(fontSize: 12, color: couleurLibelle),
        ),
      ],
    );

    if (fondDegrade) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          gradient: MaquetteDegrades.principal,
          borderRadius: BorderRadius.circular(20),
        ),
        child: contenu,
      );
    }
    return CarteSpec(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      rayon: 20,
      child: contenu,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Titre de section 17 px w800 + lien d'action 13 px w700 bleu
// (« Voir tout ») (§4.1).
// ─────────────────────────────────────────────────────────────────────
class EnTeteSectionSpec extends StatelessWidget {
  final String titre;
  final String? action;
  final VoidCallback? onAction;

  const EnTeteSectionSpec({
    super.key,
    required this.titre,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              titre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: MaquetteTypo.titreSection,
                fontWeight: FontWeight.w800,
                color: MaquetteCouleurs.texte,
              ),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                action!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MaquetteCouleurs.bleu,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Bouton principal en dégradé G, rayon 16 (§1) — icône optionnelle.
// ─────────────────────────────────────────────────────────────────────
class BoutonDegradeSpec extends StatelessWidget {
  final String texte;
  final VoidCallback? onPressed;
  final bool pleineLargeur;
  final double hauteur;
  final IconData? icone;

  /// (AJOUT) Indicateur de progression pendant un envoi : le libellé
  /// est remplacé par un spinner blanc. `onPressed` reste l'info de
  /// « bouton actif » (non null pendant l'envoi : le dégradé reste).
  final bool chargement;

  const BoutonDegradeSpec({
    super.key,
    required this.texte,
    required this.onPressed,
    this.pleineLargeur = true,
    this.hauteur = 52,
    this.icone,
    this.chargement = false,
  });

  @override
  Widget build(BuildContext context) {
    final actif = onPressed != null;
    return Opacity(
      opacity: actif ? 1 : 0.55,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: hauteur,
          width: pleineLargeur ? double.infinity : null,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: actif ? MaquetteDegrades.principal : null,
            color: actif ? null : const Color(0xFF9AA4C0),
            borderRadius: BorderRadius.circular(MaquetteRayons.bouton),
          ),
          child: chargement
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icone != null) ...[
                      Icon(icone, size: 19, color: Colors.white),
                      const SizedBox(width: 8),
                    ],
                    // Flexible : sur un écran étroit (360 px), le libellé
                    // s'adapte à la place restante au lieu de déborder.
                    Flexible(
                      child: Text(
                        texte,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Bouton « contour » de la maquette : rayon 16, fond blanc, bordure et
// texte colorés. `couleur` = MaquetteCouleurs.refuseTexte pour le rouge.
// ─────────────────────────────────────────────────────────────────────
class BoutonContourSpec extends StatelessWidget {
  final String texte;
  final VoidCallback? onPressed;
  final Color couleur;
  final double hauteur;
  final bool pleineLargeur;

  const BoutonContourSpec({
    super.key,
    required this.texte,
    required this.onPressed,
    this.couleur = MaquetteCouleurs.bleu,
    this.hauteur = 52,
    this.pleineLargeur = true,
  });

  @override
  Widget build(BuildContext context) {
    final actif = onPressed != null;
    return Opacity(
      opacity: actif ? 1 : 0.55,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: hauteur,
          width: pleineLargeur ? double.infinity : null,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: MaquetteCouleurs.surface,
            borderRadius: BorderRadius.circular(MaquetteRayons.bouton),
            border: Border.all(color: couleur.withValues(alpha: 0.6)),
          ),
          child: Text(
            texte,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: couleur,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Bouton plein « désactivé en gris » (§4.3 : « Confirmer le refus »
// est rouge #B3261E, gris tant que le motif est vide).
// ─────────────────────────────────────────────────────────────────────
class BoutonPleinSpec extends StatelessWidget {
  final String texte;
  final VoidCallback? onPressed; // null = désactivé (gris)
  final Color couleurActive;
  final double hauteur;
  final bool pleineLargeur;

  /// (AJOUT) Indicateur de progression pendant un envoi : le libellé
  /// est remplacé par un spinner blanc. `onPressed` reste l'info de
  /// « bouton actif » (non null pendant l'envoi : la couleur reste).
  final bool chargement;

  const BoutonPleinSpec({
    super.key,
    required this.texte,
    required this.onPressed,
    this.couleurActive = MaquetteCouleurs.refuseTexte,
    this.hauteur = 52,
    this.pleineLargeur = true,
    this.chargement = false,
  });

  @override
  Widget build(BuildContext context) {
    final actif = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: hauteur,
        width: pleineLargeur ? double.infinity : null,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: actif ? couleurActive : const Color(0xFFD7DCE8),
          borderRadius: BorderRadius.circular(MaquetteRayons.bouton),
        ),
        child: chargement && actif
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(
                texte,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: actif ? Colors.white : const Color(0xFF8A93AB),
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Bloc d'état en pied de détail (§4.3) : « Consultation terminée »
// (gris) / « Rendez-vous refusé » (rouge clair).
// ─────────────────────────────────────────────────────────────────────
class BlocEtatSpec extends StatelessWidget {
  final String texte;
  final Color fond;
  final Color couleurTexte;

  const BlocEtatSpec({
    super.key,
    required this.texte,
    required this.fond,
    required this.couleurTexte,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(MaquetteRayons.bouton),
      ),
      child: Text(
        texte,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: couleurTexte,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Bouton cloche de l'en-tête (§4.1) : 44 px rond, fond blanc,
// bordure #E3E8F2, pastille rouge #D92D20 en haut à droite si
// notification non lue.
// ─────────────────────────────────────────────────────────────────────
class BoutonClocheSpec extends StatelessWidget {
  final bool avecPastille;
  final VoidCallback? onTap;

  const BoutonClocheSpec({super.key, this.avecPastille = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: maquetteCibleMin,
        height: maquetteCibleMin,
        decoration: const BoxDecoration(
          color: MaquetteCouleurs.surface,
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(color: MaquetteCouleurs.bordure),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.notifications_outlined,
              size: 21,
              color: MaquetteCouleurs.texte,
            ),
            if (avecPastille)
              Positioned(
                top: 9,
                right: 10,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: MaquetteCouleurs.alerteNotif,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Bannière de notification (§4.1) : dégradé violet #7A6BE6→#28211A,
// rayon 18, pastille cloche à gauche, titre 14 w800, sous-titre 13,
// croix de fermeture à droite. (Uniquement dans l'espace Médecin ;
// l'accueil secrétaire réutilisera ce widget au bloc secrétaire.)
// ─────────────────────────────────────────────────────────────────────
class BanniereNotificationSpec extends StatelessWidget {
  final String titre;
  final String sousTitre;
  final VoidCallback onFermer;

  const BanniereNotificationSpec({
    super.key,
    required this.titre,
    required this.sousTitre,
    required this.onFermer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: MaquetteDegrades.banniere,
        borderRadius: BorderRadius.circular(MaquetteRayons.carte),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_outlined,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sousTitre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onFermer,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
