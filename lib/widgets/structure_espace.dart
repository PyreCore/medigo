// ─────────────────────────────────────────────────────────────────────
// STRUCTURE DES ESPACES (coquille commune Médecin / Secrétaire)
//
// Deux dispositions selon la largeur d'écran (responsive) :
//  · web / tablette large (≥ 900 px) : RAIL de navigation à gauche
//    (libellés), en-tête de page intégré, contenu centré avec
//    largeur maximale. Fond en dégradé G de la maquette
//    (#2458D3 → #28211A ≈ 80°), libellés blancs.
//  · mobile (< 900 px) : barre du haut compacte + barre du bas en
//    dégradé G, icône + libellé blancs et onglet actif plus marqué
//    (pastille blanche translucide, maquette §3).
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../theme/maquette_tokens.dart';
import '../theme/medigo_theme.dart';
import 'ui_kit.dart';

/// Icône Material associée à chaque onglet (d'après la maquette).
/// Le libellé sert de clé : on reconnaît « Accueil », « Rendez-vous »…
/// Sinon, une icône neutre par défaut évite tout crash.
IconData _iconePourLibelle(String libelle) {
  switch (libelle) {
    case 'Accueil':
      return Icons.home_outlined;
    case 'Rendez-vous':
      return Icons.calendar_month_outlined;
    case 'Disponibilités':
      return Icons.schedule;
    case 'Patients':
      return Icons.people_alt_outlined;
    case 'Horaires':
      return Icons.access_time_outlined;
    case 'Profil':
      return Icons.person_outline;
    default:
      return Icons.circle_outlined;
  }
}

class StructureEspace extends StatelessWidget {
  /// « Espace Médecin » / « Espace Secrétaire » (sous-titre du rail).
  final String titreEspace;

  /// Nom affiché dans la carte utilisateur du rail.
  final String nomUtilisateur;

  /// Initiales de l'utilisateur (avatar du rail).
  final String initialesUser;

  /// Photo de profil optionnelle (null = initiales).
  final String? photoUser;

  /// Dégradé de la navigation (rail à gauche et barre du bas).
  /// null = dégradé bleu de la maquette. Permet à l'espace Admin
  /// d'utiliser un thème violet sans dupliquer la coquille.
  final LinearGradient? degradeNavigation;

  /// Index de l'onglet affiché.
  final int indexActif;

  /// Change d'onglet (appelé par le rail ET par la barre du bas).
  final ValueChanged<int> onChoisirOnglet;

  /// Libellés des onglets (servent aussi de titres de page).
  /// Le DERNIER doit être « Profil » (la carte utilisateur y mène).
  final List<String> libelles;

  /// Les écrans correspondants. Seul l'onglet d'index [indexActif] est
  /// construit à la fois (voir build) : c'est indispensable car les
  /// ListView de chaque onglet exigent une hauteur contrainte, ce qu'un
  /// empilement type IndexedStack dans un Center ne leur donne pas.
  final List<Widget> onglets;

  const StructureEspace({
    super.key,
    required this.titreEspace,
    required this.nomUtilisateur,
    required this.initialesUser,
    this.photoUser,
    this.degradeNavigation,
    required this.indexActif,
    required this.onChoisirOnglet,
    required this.libelles,
    required this.onglets,
  });

  @override
  Widget build(BuildContext context) {
    // Affichage direct de l'onglet actif (pas d'IndexedStack) :
    // les ListView enfants ont besoin d'une hauteur contrainte, ce que
    // IndexedStack dans un Center ne leur donne pas → écran blanc.
    final contenu = onglets[indexActif];
    final degrade = degradeNavigation ?? MaquetteDegrades.principal;

    return LayoutBuilder(
      builder: (context, contraintes) {
        // ── Écran LARGE : rail à gauche ────────────────────────────
        if (contraintes.maxWidth >= 900) {
          return Scaffold(
            backgroundColor: MaquetteCouleurs.fond,
            body: Row(
              children: [
                _RailMedigo(
                  titreEspace: titreEspace,
                  nomUtilisateur: nomUtilisateur,
                  initialesUser: initialesUser,
                  photoUser: photoUser,
                  degrade: degrade,
                  libelles: libelles,
                  indexActif: indexActif,
                  onChoisirOnglet: onChoisirOnglet,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // En-tête de page : gros titre à gauche, aucune
                      // icône de barre d'application (style « web pro »).
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 28, 32, 8),
                        child: Text(
                          libelles[indexActif],
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.bleuNuit,
                          ),
                        ),
                      ),
                      // Contenu : Container avec largeur maximale (pas de
                      // Center qui absorberait les contraintes de hauteur).
                      Expanded(
                        child: Container(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1120),
                            child: contenu,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // ── MOBILE : barre haute + barre basse, contenu compact ──
        // Le contenu est mis directement dans le body (le Scaffold donne
        // des contraintes de hauteur bornées — indispensable aux ListView).
        // ConstrainedBox borne seulement la largeur, sans casser la hauteur.
        return Scaffold(
          backgroundColor: MaquetteCouleurs.fond,
          appBar: BarreHauteMedigo(titre: libelles[indexActif]),
          body: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: contenu,
            ),
          ),
          bottomNavigationBar: _BarreBasseMedigo(
            degrade: degrade,
            libelles: libelles,
            indexActif: indexActif,
            onChoisirOnglet: onChoisirOnglet,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Rail de navigation gauche (écrans larges) — libellés SEULS.
// ─────────────────────────────────────────────────────────────────────
class _RailMedigo extends StatelessWidget {
  final String titreEspace;
  final String nomUtilisateur;
  final String initialesUser;
  final String? photoUser;
  final LinearGradient degrade;
  final List<String> libelles;
  final int indexActif;
  final ValueChanged<int> onChoisirOnglet;

  const _RailMedigo({
    required this.titreEspace,
    required this.nomUtilisateur,
    required this.initialesUser,
    required this.photoUser,
    required this.degrade,
    required this.libelles,
    required this.indexActif,
    required this.onChoisirOnglet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 256,
      // Fond en dégradé G de la maquette (#2458D3 → #28211A ≈ 80°),
      // comme la barre du bas mobile : la navigation est uniforme.
      decoration: BoxDecoration(gradient: degrade),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logotype texte (« wordmark ») : pas d'icône.
              const Text(
                'Medigo',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                titreEspace,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 28),
              // Entrées de navigation.
              ...libelles.asMap().entries.map(
                (entree) => _ItemRail(
                  libelle: entree.value,
                  actif: entree.key == indexActif,
                  onTap: () => onChoisirOnglet(entree.key),
                ),
              ),
              const Spacer(),
              // Carte utilisateur en bas : clique = onglet Profil.
              InkWell(
                borderRadius: BorderRadius.circular(14),
                hoverColor: Colors.white.withValues(alpha: 0.08),
                onTap: () => onChoisirOnglet(libelles.length - 1),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        backgroundImage: imageProfil(photoUser),
                        child: photoUser == null
                            ? Text(
                                initialesUser,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nomUtilisateur,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              titreEspace,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

// Une entrée du rail : libellé seul, pastille de fond quand actif.
class _ItemRail extends StatelessWidget {
  final String libelle;
  final bool actif;
  final VoidCallback onTap;

  const _ItemRail({
    required this.libelle,
    required this.actif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // Survol subtil (utile surtout sur web).
        hoverColor: Colors.white.withValues(alpha: 0.08),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
          decoration: BoxDecoration(
            // Onglet ACTIF : pastille blanche translucide, plus marquée
            // que l'inactif (maquette §3 sur dégradé).
            color: actif
                ? Colors.white.withValues(alpha: 0.20)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          // Libellé seul (le rail reste « texte seul » — les icônes de la
          // maquette vivent dans la barre du bas mobile, pas dans ce rail).
          child: Text(
            libelle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: actif ? FontWeight.w800 : FontWeight.w500,
              color: actif
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.80),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Barre du bas (mobile) — libellés SEULS, pastille d'indication.
// ─────────────────────────────────────────────────────────────────────
class _BarreBasseMedigo extends StatelessWidget {
  final List<String> libelles;
  final int indexActif;
  final ValueChanged<int> onChoisirOnglet;
  final LinearGradient degrade;

  const _BarreBasseMedigo({
    required this.libelles,
    required this.indexActif,
    required this.onChoisirOnglet,
    required this.degrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Hauteur MAXIMALE bornée : CORRECTIF DU BUG BLANC (à conserver).
      // Dans le slot bottomNavigationBar, la hauteur est NON BORNÉE
      // (0 → ∞). Sans borne, un « Center » (Align sans heightFactor) ou un
      // Column en mainAxisSize.max gonfle à TOUTE la hauteur offerte → la
      // barre mesure alors la hauteur de l'écran et le corps reçoit 0 px
      // (écran blanc). La borne garantit une taille normale (~68 px de
      // contenu + zone sûre basse), et reste un plafond de sécurité.
      //
      // Hauteur EXPLICITE : sans elle, la décoration en dégradé ne se
      // voyait pas correctement (fond perçu « blanc ou uni »). Le
      // Container mesure désormais 68 px de contenu (+ SafeArea basse).
      height: 68,
      // Fond en dégradé G de la maquette (#2458D3 → #28211A, ≈ 80°).
      decoration: BoxDecoration(gradient: degrade),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: libelles.asMap().entries.map((entree) {
              final actif = entree.key == indexActif;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onChoisirOnglet(entree.key),
                  // mainAxisSize.min : le Column se dimensionne à son
                  // contenu (icône + libellé) et ne gonfle jamais.
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Onglet ACTIF : pastille 56 x 32 (rayon 16) blanche
                      // translucide + icône blanche — plus marqué que
                      // l'inactif (maquette §3 : icônes/libellés blancs,
                      // actif plus visible).
                      Container(
                        width: 56,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: actif
                              ? Colors.white.withValues(alpha: 0.22)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _iconePourLibelle(entree.value),
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Libellé sous l'icône. FittedBox : il RÉTRÉCIT si la
                      // largeur manque (ex : 5 onglets sur 360 px).
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          entree.value,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                actif ? FontWeight.w800 : FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
