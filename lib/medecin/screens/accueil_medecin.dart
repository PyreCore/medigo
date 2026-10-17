// ─────────────────────────────────────────────────────────────────────
// ACCUEIL MÉDECIN — tableau de bord « RDV du jour ».
// Reproduit la maquette « Medigo Médecin et Secrétaire » :
//  1. en-tête : date au-dessus, salutation en grand, avatar à droite ;
//  2. carte « Prochain rendez-vous » en dégradé signature (bleu → nuit) ;
//  3. rangée de 3 métriques à icône pastel ;
//  4. liste des RDV du jour + lien « Voir tout » ;
//  5. ≥ 900 px : panneau latéral « Répartition du jour » à droite.
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
  final VoidCallback onVoirTout; // lien « Voir tout » → onglet Rendez-vous
  final VoidCallback onVoirPlanning; // (onglet Disponibilités, via nav)
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

  /// Carte « Prochain rendez-vous » (dégradé signature), en haut du
  /// tableau de bord comme dans la maquette. Extraite dans une méthode
  /// pour rester lisible.
  Widget _carteProchain(RendezVous prochain) {
    // Sous-titre : motif · spécialité (chacun toléré vide).
    final motif = (prochain.motif ?? '').trim();
    final specialite = medecin.specialite.trim();
    final sousTitre = [
      if (motif.isNotEmpty) motif else 'Consultation',
      if (specialite.isNotEmpty) specialite,
    ].join(' · ');

    return CarteGradientMedigo(
      onTap: () => onTapRendezVous(prochain),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne de haut : libellé + pastille horaire blanche.
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
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
          // Nom du patient, en grand blanc.
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
            sousTitre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 14),
          // Lien « Voir le détail » + chevron.
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

    // Liste des rendez-vous du jour (cartes maquette : pastille d'heure +
    // nom + motif + badge de statut).
    final listeRdv = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EnTeteSection(
          titre: 'Rendez-vous d\'aujourd\'hui',
          action: 'Voir tout',
          onAction: onVoirTout,
        ),
        const SizedBox(height: 8),
        if (rendezVousDuJour.isEmpty)
          const EtatVide(
            message: 'Aucun rendez-vous aujourd\'hui',
            detail: 'Profitez-en pour préparer vos consultations.',
          )
        else
          ...rendezVousDuJour.asMap().entries.map(
            (entree) => Apparition(
              delaiMs: 160 + (entree.key * 60),
              child: CarteRdvTableau(
                rdv: entree.value,
                onTap: () => onTapRendezVous(entree.value),
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
                        'Bonjour, ${medecin.nomComplet}',
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
                // Avatar à droite (photo base64 ou initiales).
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.bleuClair,
                  backgroundImage: imageProfil(photoUrl),
                  child: photoUrl == null
                      ? Text(
                          initiales(medecin.prenom, medecin.nom),
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
                    valeur: rendezVousDuJour.length.toString(),
                    libelle: 'RDV aujourd\'hui',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TuileStatIcone(
                    icone: Icons.schedule,
                    couleur: AppColors.ambre,
                    fondPastel: AppColors.ambreClair,
                    valeur: enAttente.toString(),
                    libelle: 'En attente',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TuileStatIcone(
                    icone: Icons.people_alt_outlined,
                    couleur: AppColors.vertSante,
                    fondPastel: AppColors.vertClair,
                    valeur: patientsSuivis.toString(),
                    libelle: 'Patients suivis',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 4. Liste + panneau responsive ─────────────────────────
          LayoutBuilder(
            builder: (context, contraintes) {
              // Grand écran : liste + panneau côte à côte (seuil = rail).
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
              // Petit écran : liste seule (le prochain RDV est déjà en haut).
              return listeRdv;
            },
          ),
        ],
      ),
    );
  }
}
