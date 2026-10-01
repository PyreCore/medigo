// ─────────────────────────────────────────────────────────────────────
// ACCUEIL MÉDECIN — tableau de bord « RDV du jour ».
// Structure professionnelle (type Doctolib Pro / dashboards internationaux) :
//  1. en-tête : identité + date du jour (texte seul, aucune icône) ;
//  2. rangée de métriques (chiffres + trait d'accent coloré) ;
//  3. actions rapides (boutons texte) ;
//  4. grille responsive : liste des RDV (gauche) + panneau latéral
//     « répartition » et « prochain rendez-vous » (droite, ≥ 820 px).
// La LOGIQUE (données + callbacks reçus du parent) est inchangée.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../models/medecin.dart';
import '../../models/rendez_vous.dart';
import '../../theme/medigo_theme.dart';
import '../../widgets/rendez_vous_card.dart';
import '../../widgets/ui_kit.dart';

class AccueilMedecin extends StatelessWidget {
  final Medecin medecin;

  /// Photo à jour (peut changer après modification du profil).
  final String? photoUrl;

  final List<RendezVous> rendezVousDuJour;
  final int enAttente;
  final int patientsSuivis;

  // Callbacks : ce widget n'a jamais accès à la navigation directement,
  // il appelle ces fonctions et laisse l'espace parent décider.
  final VoidCallback onVoirTout; // onglet « Rendez-vous »
  final VoidCallback onVoirPlanning; // onglet « Disponibilités »
  final ValueChanged<RendezVous> onTapRendezVous;
  final Future<void> Function()? onRafraichir;

  const AccueilMedecin({
    super.key,
    required this.medecin,
    this.photoUrl,
    required this.rendezVousDuJour,
    this.enAttente = 0,
    this.patientsSuivis = 0,
    required this.onVoirTout,
    required this.onVoirPlanning,
    required this.onTapRendezVous,
    this.onRafraichir,
  });

  @override
  Widget build(BuildContext context) {
    // Sous-titre de l'en-tête : « Spécialité · Hôpital », tolérant aux
    // champs vides (comptes créés sans ces informations dans Firestore).
    final sousTitre = [
      if (medecin.specialite.trim().isNotEmpty) medecin.specialite,
      if (medecin.hopitalNom.trim().isNotEmpty) medecin.hopitalNom,
    ].join(' · ');

    // Prochain rendez-vous « à venir » (en attente ou confirmé) pour
    // le panneau latéral. Boucle classique (pas de dépendance collection).
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
                          initiales(medecin.prenom, medecin.nom),
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
                        'Bonjour, ${medecin.nomComplet}',
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
                        sousTitre.isEmpty ? 'Compte médecin' : sousTitre,
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

          // ── 2. Métriques du jour ─────────────────────────────────
          Apparition(
            delaiMs: 60,
            child: Row(
              children: [
                Expanded(
                  child: TuileStat(
                    valeur: rendezVousDuJour.length.toString(),
                    libelle: 'Rendez-vous du jour',
                    couleur: AppColors.bleuMedical,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TuileStat(
                    valeur: enAttente.toString(),
                    libelle: 'En attente',
                    couleur: AppColors.ambre,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TuileStat(
                    valeur: patientsSuivis.toString(),
                    libelle: 'Patients suivis',
                    couleur: AppColors.turquoise,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 3. Actions rapides (texte seul) ──────────────────────
          Apparition(
            delaiMs: 120,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                BoutonPrincipal(
                  texte: 'Voir le planning',
                  pleineLargeur: false,
                  hauteur: 44,
                  onPressed: onVoirPlanning,
                ),
                BoutonContour(
                  texte: 'Tous les rendez-vous',
                  onPressed: onVoirTout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 4. Grille responsive : liste + panneau latéral ───────
          LayoutBuilder(
            builder: (context, contraintes) {
              // Colonne gauche : la liste des rendez-vous du jour.
              final liste = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EnTeteSection(titre: 'Rendez-vous d\'aujourd\'hui'),
                  const SizedBox(height: 8),
                  if (rendezVousDuJour.isEmpty)
                    const EtatVide(
                      message: 'Aucun rendez-vous aujourd\'hui',
                      detail: 'Profitez-en pour préparer vos consultations.',
                    )
                  else
                    // Apparition décalée : 60 ms entre chaque carte.
                    ...rendezVousDuJour.asMap().entries.map(
                      (entree) => Apparition(
                        delaiMs: 160 + (entree.key * 60),
                        child: RendezVousCard(
                          rdv: entree.value,
                          onTap: () => onTapRendezVous(entree.value),
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
                      onTap: () => onTapRendezVous(prochain!),
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
