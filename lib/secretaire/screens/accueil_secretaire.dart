// ─────────────────────────────────────────────────────────────────────
// ACCUEIL SECRÉTAIRE — tableau de bord « RDV de l'hôpital » (#5 du brief).
// Structure professionnelle alignée sur l'accueil médecin :
//  1. en-tête : identité + date (texte seul, aucune icône) ;
//  2. rangée de métriques (chiffres + trait d'accent coloré) ;
//  3. actions rapides : programmer un RDV / nouveau patient ;
//  4. grille responsive : liste des RDV (gauche) + panneau « répartition »
//     et « prochain rendez-vous » (droite, ≥ 820 px).
// La LOGIQUE (données + callbacks) est inchangée.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../models/secretaire.dart';
import '../../models/rendez_vous.dart';
import '../../theme/medigo_theme.dart';
import '../../widgets/rendez_vous_card.dart';
import '../../widgets/ui_kit.dart';

class AccueilSecretaire extends StatelessWidget {
  final Secretaire secretaire;

  /// Photo à jour (peut changer après modification du profil).
  final String? photoUrl;

  final List<RendezVous> rendezVousDuJour;
  final Map<String, int> statistiques;

  // Fonction appelée quand on tape sur un rendez-vous, pour aller voir
  // son détail. Le "?" la rend optionnelle.
  final void Function(RendezVous)? onTapRendezVous;

  // Actions rapides du dashboard (optionnelles : si le parent ne les
  // fournit pas, les boutons n'apparaissent pas).
  final VoidCallback? onNouveauRendezVous;
  final VoidCallback? onNouveauPatient;

  final Future<void> Function()? onRafraichir;

  const AccueilSecretaire({
    super.key,
    required this.secretaire,
    this.photoUrl,
    required this.rendezVousDuJour,
    required this.statistiques,
    this.onTapRendezVous,
    this.onNouveauRendezVous,
    this.onNouveauPatient,
    this.onRafraichir,
  });

  @override
  Widget build(BuildContext context) {
    // Hôpital de l'en-tête, avec repli si le champ est vide dans
    // Firestore (comptes créés sans cette information).
    final hopitalTitre = secretaire.hopitalNom.trim().isEmpty
        ? 'Espace secrétaire'
        : secretaire.hopitalNom;

    // Prochain rendez-vous « à venir » pour le panneau latéral.
    RendezVous? prochain;
    for (final rdv in rendezVousDuJour) {
      if (rdv.statut == StatutRendezVous.enAttente ||
          rdv.statut == StatutRendezVous.confirme) {
        prochain = rdv;
        break;
      }
    }

    return RefreshIndicator(
      onRefresh: onRafraichir ?? () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── 1. En-tête : avatar + salutation + date ───────────────
          Apparition(
            delaiMs: 0,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.bleuMedical.withValues(
                    alpha: 0.10,
                  ),
                  backgroundImage: imageProfil(photoUrl),
                  child: photoUrl == null
                      ? Text(
                          initiales(secretaire.prenom, secretaire.nom),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.bleuMedical,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bonjour, ${secretaire.nomComplet}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.texte,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hopitalTitre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.texteFaible,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Pastille de date (texte seul — aucune icône).
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(Rayons.pillule),
                    border: Border.all(color: AppColors.trait),
                  ),
                  child: Text(
                    dateDuJour(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.texteFaible,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 2. Métriques de l'hôpital ─────────────────────────────
          Apparition(
            delaiMs: 60,
            child: Row(
              children: [
                Expanded(
                  child: TuileStat(
                    valeur: (statistiques['rdvAujourdhui'] ?? 0).toString(),
                    libelle: 'RDV aujourd\'hui',
                    couleur: AppColors.bleuMedical,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TuileStat(
                    valeur: (statistiques['enAttente'] ?? 0).toString(),
                    libelle: 'En attente',
                    couleur: AppColors.ambre,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TuileStat(
                    valeur: (statistiques['totalPatients'] ?? 0).toString(),
                    libelle: 'Patients',
                    couleur: AppColors.turquoise,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 3. Actions rapides (texte seul) ──────────────────────
          if (onNouveauRendezVous != null || onNouveauPatient != null)
            Apparition(
              delaiMs: 120,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (onNouveauRendezVous != null)
                    BoutonPrincipal(
                      texte: 'Programmer un rendez-vous',
                      pleineLargeur: false,
                      hauteur: 44,
                      onPressed: onNouveauRendezVous,
                    ),
                  if (onNouveauPatient != null)
                    BoutonContour(
                      texte: 'Nouveau patient',
                      onPressed: onNouveauPatient,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // ── 4. Grille responsive : liste + panneau latéral ───────
          LayoutBuilder(
            builder: (context, contraintes) {
              // Colonne gauche : les rendez-vous du jour de l'hôpital.
              final liste = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EnTeteSection(titre: 'Rendez-vous du jour'),
                  const SizedBox(height: 8),
                  if (rendezVousDuJour.isEmpty)
                    const EtatVide(
                      message: 'Aucun rendez-vous aujourd\'hui',
                      detail: 'Les nouveaux rendez-vous apparaîtront ici.',
                    )
                  else
                    // Apparition décalée : 60 ms entre chaque carte.
                    ...rendezVousDuJour.asMap().entries.map(
                      (entree) => Apparition(
                        delaiMs: 160 + (entree.key * 60),
                        child: RendezVousCard(
                          rdv: entree.value,
                          // La secrétaire voit plusieurs médecins :
                          // on affiche le nom du médecin sous le patient.
                          afficherMedecin: true,
                          onTap: onTapRendezVous != null
                              ? () => onTapRendezVous!(entree.value)
                              : null,
                        ),
                      ),
                    ),
                ],
              );

              // Colonne droite : panneau d'analyse du jour.
              final panneau = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EnTeteSection(titre: 'Répartition du jour'),
                  const SizedBox(height: 8),
                  RepartitionStatuts(rdvs: rendezVousDuJour),
                  if (prochain != null) ...[
                    const SizedBox(height: 20),
                    const EnTeteSection(titre: 'Prochain rendez-vous'),
                    const SizedBox(height: 8),
                    RendezVousCard(
                      rdv: prochain,
                      afficherMedecin: true,
                      onTap: onTapRendezVous != null
                          ? () => onTapRendezVous!(prochain!)
                          : null,
                    ),
                  ],
                ],
              );

              // Grand écran : les deux colonnes côte à côte.
              if (contraintes.maxWidth > 820) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: liste),
                    const SizedBox(width: 24),
                    SizedBox(width: 340, child: panneau),
                  ],
                );
              }
              // Petit écran : empilées.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [liste, const SizedBox(height: 28), panneau],
              );
            },
          ),
        ],
      ),
    );
  }
}
