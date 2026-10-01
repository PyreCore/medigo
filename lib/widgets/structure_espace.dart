// ─────────────────────────────────────────────────────────────────────
// STRUCTURE DES ESPACES (coquille commune Médecin / Secrétaire)
//
// Deux dispositions selon la largeur d'écran (responsive) :
//  · web / tablette large (≥ 900 px) : RAIL de navigation à gauche
//    (libellés seuls — aucune icône), en-tête de page intégré, contenu
//    centré avec largeur maximale : c'est le schéma des applications
//    professionnelles internationales (Doctolib Pro, Linear, Notion).
//  · mobile (< 900 px) : barre du haut compacte + barre du bas à
//    libellés seuls avec pastille d'indication.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../theme/medigo_theme.dart';
import 'ui_kit.dart';

class StructureEspace extends StatelessWidget {
  /// « Espace Médecin » / « Espace Secrétaire » (sous-titre du rail).
  final String titreEspace;

  /// Nom affiché dans la carte utilisateur du rail.
  final String nomUtilisateur;

  /// Initiales de l'utilisateur (avatar du rail).
  final String initialesUser;

  /// Photo de profil optionnelle (null = initiales).
  final String? photoUser;

  /// Index de l'onglet affiché.
  final int indexActif;

  /// Change d'onglet (appelé par le rail ET par la barre du bas).
  final ValueChanged<int> onChoisirOnglet;

  /// Libellés des onglets (servent aussi de titres de page).
  /// Le DERNIER doit être « Profil » (la carte utilisateur y mène).
  final List<String> libelles;

  /// Les écrans correspondants, empilés via IndexedStack (les écrans
  /// non visibles restent en mémoire : la position de défilement et
  /// l'état de chaque onglet sont donc conservés).
  final List<Widget> onglets;

  const StructureEspace({
    super.key,
    required this.titreEspace,
    required this.nomUtilisateur,
    required this.initialesUser,
    this.photoUser,
    required this.indexActif,
    required this.onChoisirOnglet,
    required this.libelles,
    required this.onglets,
  });

  @override
  Widget build(BuildContext context) {
    final contenu = IndexedStack(index: indexActif, children: onglets);

    return LayoutBuilder(
      builder: (context, contraintes) {
        // ── Écran LARGE : rail à gauche ────────────────────────────
        if (contraintes.maxWidth >= 900) {
          return Scaffold(
            backgroundColor: AppColors.fond,
            body: Row(
              children: [
                _RailMedigo(
                  titreEspace: titreEspace,
                  nomUtilisateur: nomUtilisateur,
                  initialesUser: initialesUser,
                  photoUser: photoUser,
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
                      // Contenu centré, largeur maximale pour rester
                      // lisible sur très grands écrans.
                      Expanded(child: _centre(contenu, 1120)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // ── Écran ÉTROIT : barre haut + barre basse ────────────────
        return Scaffold(
          backgroundColor: AppColors.fond,
          appBar: BarreHauteMedigo(titre: libelles[indexActif]),
          body: _centre(contenu, 720),
          bottomNavigationBar: _BarreBasseMedigo(
            libelles: libelles,
            indexActif: indexActif,
            onChoisirOnglet: onChoisirOnglet,
          ),
        );
      },
    );
  }

  // Contenu centré avec largeur maximale : la mise en page reste
  // identique (et lisible) quelle que soit la taille de la fenêtre.
  Widget _centre(Widget contenu, double largeurMax) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: largeurMax),
        child: contenu,
      ),
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
  final List<String> libelles;
  final int indexActif;
  final ValueChanged<int> onChoisirOnglet;

  const _RailMedigo({
    required this.titreEspace,
    required this.nomUtilisateur,
    required this.initialesUser,
    required this.photoUser,
    required this.libelles,
    required this.indexActif,
    required this.onChoisirOnglet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 256,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.trait)),
      ),
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
                  color: AppColors.bleuMedical,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                titreEspace,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.texteFaible,
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
                hoverColor: AppColors.bleuMedical.withValues(alpha: 0.05),
                onTap: () => onChoisirOnglet(libelles.length - 1),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.fond,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.bleuMedical.withValues(
                          alpha: 0.12,
                        ),
                        backgroundImage: imageProfil(photoUser),
                        child: photoUser == null
                            ? Text(
                                initialesUser,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.bleuMedical,
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
                                color: AppColors.texte,
                              ),
                            ),
                            Text(
                              titreEspace,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.texteFaible,
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
        hoverColor: AppColors.bleuMedical.withValues(alpha: 0.06),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
          decoration: BoxDecoration(
            color: actif
                ? AppColors.bleuMedical.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            libelle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
              color: actif ? AppColors.bleuMedical : AppColors.texteFaible,
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

  const _BarreBasseMedigo({
    required this.libelles,
    required this.indexActif,
    required this.onChoisirOnglet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.trait)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: libelles.asMap().entries.map((entree) {
              final actif = entree.key == indexActif;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onChoisirOnglet(entree.key),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: actif
                              ? AppColors.bleuMedical.withValues(alpha: 0.10)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          entree.value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: actif
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: actif
                                ? AppColors.bleuMedical
                                : AppColors.texteFaible,
                          ),
                        ),
                      ),
                    ),
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
