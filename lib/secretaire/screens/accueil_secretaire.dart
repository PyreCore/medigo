// ─────────────────────────────────────────────────────────────────────
// ACCUEIL SECRÉTAIRE — tableau de bord « RDV de l'hôpital ».
// Aligné sur la maquette « Medigo Médecin et Secrétaire » et sur
// l'accueil médecin :
//  1. en-tête : date au-dessus, salutation en grand, avatar à droite ;
//  2. carte « Prochain rendez-vous » en dégradé signature ;
//  3. rangée de 3 métriques à icône pastel ;
//  4. actions rapides (spécifiques au secrétaire : programmer un RDV,
//     nouveau patient) ;
//  5. liste des RDV + ≥ 900 px : panneau « Répartition du jour ».
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

  // Ligne d'information d'une carte : « Dr X · motif » (le secrétaire a
  // besoin de voir LE MÉDECIN, contrairement à l'accueil médecin).
  static String _sousTitreRdv(RendezVous rdv) {
    final medecin = (rdv.medecinNom ?? '').trim();
    final motif = (rdv.motif ?? '').trim();
    if (medecin.isNotEmpty && motif.isNotEmpty) return '$medecin · $motif';
    if (medecin.isNotEmpty) return medecin;
    return motif;
  }

  /// Carte « Prochain rendez-vous » (dégradé signature), en haut du
  /// tableau de bord comme dans la maquette.
  Widget _carteProchain(RendezVous prochain) {
    return CarteGradientMedigo(
      onTap: () => onTapRendezVous?.call(prochain),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Prochain rendez-vous',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Rayons.pillule),
                ),
                child: Text(
                  prochain.heure,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            prochain.patientNomComplet,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _sousTitreRdv(prochain),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Text(
                'Voir le détail',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Prochain rendez-vous « à venir » (en attente ou confirmé).
    RendezVous? prochain;
    for (final rdv in rendezVousDuJour) {
      if (rdv.statut == StatutRendezVous.enAttente ||
          rdv.statut == StatutRendezVous.confirme) {
        prochain = rdv;
        break;
      }
    }

    // Liste des rendez-vous du jour (cartes maquette + médecin affiché).
    final listeRdv = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EnTeteSection(titre: 'Rendez-vous du jour'),
        const SizedBox(height: 8),
        if (rendezVousDuJour.isEmpty)
          const EtatVide(
            message: 'Aucun rendez-vous aujourd\'hui',
            detail: 'Ils apparaîtront ici dès qu\'ils seront créés.',
          )
        else
          ...rendezVousDuJour.asMap().entries.map(
            (entree) => Apparition(
              delaiMs: 160 + (entree.key * 60),
              child: CarteRdvTableau(
                rdv: entree.value,
                sousTitre: _sousTitreRdv(entree.value),
                onTap: onTapRendezVous == null
                    ? null
                    : () => onTapRendezVous!(entree.value),
              ),
            ),
          ),
      ],
    );

    // Panneau latéral (≥ 900 px) : répartition du jour par statut.
    final panneau = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EnTeteSection(titre: 'Répartition du jour'),
        const SizedBox(height: 8),
        RepartitionStatuts(rdvs: rendezVousDuJour),
      ],
    );

    return RefreshIndicator(
      onRefresh: onRafraichir ?? () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── 1. En-tête : date au-dessus, salutation, avatar à droite ──
          Apparition(
            delaiMs: 0,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateDuJour(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.texteFaible,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bonjour, ${secretaire.nomComplet}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.bleuClair,
                  backgroundImage: imageProfil(photoUrl),
                  child: photoUrl == null
                      ? Text(
                          initiales(secretaire.prenom, secretaire.nom),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.bleuVif,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 2. Carte « Prochain rendez-vous » (dégradé) ───────────
          if (prochain != null) ...[
            Apparition(delaiMs: 60, child: _carteProchain(prochain)),
            const SizedBox(height: 16),
          ],

          // ── 3. Métriques du jour (icônes pastel) ─────────────────
          Apparition(
            delaiMs: 120,
            child: Row(
              children: [
                Expanded(
                  child: TuileStatIcone(
                    icone: Icons.calendar_month_outlined,
                    couleur: AppColors.bleuVif,
                    fondPastel: AppColors.bleuClair,
                    valeur: (statistiques['rdvAujourdhui'] ?? 0).toString(),
                    libelle: 'RDV aujourd\'hui',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TuileStatIcone(
                    icone: Icons.schedule,
                    couleur: AppColors.ambre,
                    fondPastel: AppColors.ambreClair,
                    valeur: (statistiques['enAttente'] ?? 0).toString(),
                    libelle: 'En attente',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TuileStatIcone(
                    icone: Icons.people_alt_outlined,
                    couleur: AppColors.vertSante,
                    fondPastel: AppColors.vertClair,
                    valeur: (statistiques['totalPatients'] ?? 0).toString(),
                    libelle: 'Patients suivis',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 4. Actions rapides (spécifiques secrétaire) ──────────
          if (onNouveauRendezVous != null || onNouveauPatient != null)
            Apparition(
              delaiMs: 180,
              child: Row(
                children: [
                  if (onNouveauRendezVous != null) ...[
                    Expanded(
                      child: BoutonPrincipal(
                        texte: 'Programmer un rendez-vous',
                        hauteur: 52,
                        onPressed: onNouveauRendezVous,
                      ),
                    ),
                  ],
                  if (onNouveauPatient != null) ...[
                    if (onNouveauRendezVous != null) const SizedBox(width: 12),
                    Expanded(
                      child: BoutonContour(
                        texte: 'Nouveau patient',
                        hauteur: 52,
                        onPressed: onNouveauPatient,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 20),

          // ── 5. Liste + panneau responsive ─────────────────────────
          LayoutBuilder(
            builder: (context, contraintes) {
              if (contraintes.maxWidth >= 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: listeRdv),
                    const SizedBox(width: 24),
                    Expanded(flex: 3, child: panneau),
                  ],
                );
              }
              return listeRdv;
            },
          ),
        ],
      ),
    );
  }
}
