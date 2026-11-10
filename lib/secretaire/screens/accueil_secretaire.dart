// ─────────────────────────────────────────────────────────────────────
// ACCUEIL SECRÉTAIRE — tableau de bord « RDV de l'hôpital ».
// Aligné sur la maquette « Medigo Médecin et Secrétaire » et sur
// l'accueil médecin (même grammaire visuelle) :
//  1. en-tête : date au-dessus, salutation en grand, avatar à droite ;
//  2. zone HÉROS « Demandes à traiter » (dégradé G #2458D3→#28211A) :
//     le nombre de demandes en attente, en grand, bouton blanc
//     « Traiter les demandes » — variante vide « Aucune demande en
//     attente » + « Programmer un rendez-vous » ;
//  3. UNE bande de statistiques (chiffres #16203A séparés par de fins
//     filets verticaux, compteurs animés, sans icône pastelle) ;
//  4. actions rapides (spécifiques au secrétaire : programmer un RDV,
//     nouveau patient) ;
//  5. liste des RDV + ≥ 900 px : panneau « Répartition du jour ».
// Apparition progressive en fondu enchaîné (Apparition) : discret,
// jamais clignotant. La LOGIQUE (données + callbacks) est inchangée.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

import '../../models/rendez_vous.dart';
import '../../models/secretaire.dart';
import '../../theme/maquette_tokens.dart';
import '../../widgets/maquette_widgets.dart';
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

  /// Zone héros « Demandes à traiter » (dégradé G maquette
  /// #2458D3→#28211A) : le nombre de demandes en attente, en grand,
  /// est l'élément le plus visible de l'écran du secrétaire. Toute la
  /// carte ouvre la première demande ; le bouton blanc redit l'action.
  Widget _carteHeroDemandes(int nbDemandes, RendezVous? premiereDemande) {
    final actionable =
        onTapRendezVous != null && premiereDemande != null;
    return GestureDetector(
      onTap: actionable
          ? () => onTapRendezVous!(premiereDemande)
          : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: MaquetteDegrades.principal,
          borderRadius: BorderRadius.circular(MaquetteRayons.carteHaute),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Demandes à traiter',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD6E2FB),
              ),
            ),
            const SizedBox(height: 10),
            // Le chiffre, en grand blanc (56 px w800) — compteur animé
            // au chargement. C'est l'action prioritaire du secrétaire.
            CompteurAnime(
              valeur: nbDemandes,
              style: const TextStyle(
                fontSize: 56,
                height: 1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'en attente de confirmation',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            if (actionable) ...[
              const SizedBox(height: 16),
              // Bouton d'action : pilule blanche pleine largeur.
              _boutonHero(
                'Traiter les demandes',
                () => onTapRendezVous!(premiereDemande),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Variante « aucune demande » de la zone héros : un vrai message
  /// utile et une action de secours — jamais un « 0 » seul.
  Widget _carteHeroVideDemandes() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: MaquetteDegrades.principal,
        borderRadius: BorderRadius.circular(MaquetteRayons.carteHaute),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Demandes à traiter',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFD6E2FB),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Aucune demande en attente',
            style: TextStyle(
              fontSize: 24,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Toutes les demandes sont traitées.\n'
            'Programmez le prochain rendez-vous de votre hôpital.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Colors.white70,
            ),
          ),
          if (onNouveauRendezVous != null) ...[
            const SizedBox(height: 16),
            _boutonHero('Programmer un rendez-vous', onNouveauRendezVous),
          ],
        ],
      ),
    );
  }

  /// Bouton d'action d'une zone héros : pilule blanche, texte bleu,
  /// hauteur 44 px (cible tactile minimale de la maquette).
  Widget _boutonHero(String libelle, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: maquetteCibleMin,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(MaquetteRayons.pillule),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Flexible : sur un écran étroit (360 px), le libellé
            // s'adapte à la place restante au lieu de déborder.
            Flexible(
              child: Text(
                libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MaquetteCouleurs.bleu,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: MaquetteCouleurs.bleu,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Demandes en attente : compteur du service + première demande de
    // la liste (cible du bouton « Traiter les demandes »).
    final demandes = statistiques['enAttente'] ?? 0;
    RendezVous? premiereDemande;
    for (final rdv in rendezVousDuJour) {
      if (rdv.statut == StatutRendezVous.enAttente) {
        premiereDemande = rdv;
        break;
      }
    }
    // Les stats et la liste viennent de deux requêtes distinctes :
    // si elles divergent brièvement (liste avec demande, compteur à 0),
    // on affiche 1 plutôt qu'un héros « 0 » avec un bouton dedans.
    final nbDemandes = demandes > 0
        ? demandes
        : (premiereDemande != null ? 1 : 0);

    // Liste des rendez-vous du jour (cartes maquette + médecin affiché).
    final listeRdv = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EnTeteSectionSpec(titre: 'Rendez-vous du jour'),
        const SizedBox(height: 8),
        if (rendezVousDuJour.isEmpty)
          // Message utile seul : l'action « Programmer » est déjà
          // présente juste au-dessus (actions rapides) et dans le héros.
          const EtatVide(
            message: 'Aucun rendez-vous aujourd\'hui',
            detail: 'Programmez-en un pour commencer la journée.',
          )
        else
          ...rendezVousDuJour.asMap().entries.map(
            (entree) => Apparition(
              delaiMs: 160 + (entree.key * 60),
              child: CarteRdvTableauSpec(
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
        const EnTeteSectionSpec(titre: 'Répartition du jour'),
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
                          color: MaquetteCouleurs.texteSecondaire,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bonjour, ${secretaire.nomComplet}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: MaquetteTypo.titreEcran,
                          fontWeight: FontWeight.w800,
                          color: MaquetteCouleurs.texte,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 26,
                  backgroundColor: MaquetteCouleurs.bleuClair,
                  backgroundImage: imageProfil(photoUrl),
                  child: photoUrl == null
                      ? Text(
                          initiales(secretaire.prenom, secretaire.nom),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: MaquetteCouleurs.bleu,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 2. Zone héros : demandes à traiter (ou variante vide) ──
          Apparition(
            delaiMs: 60,
            child: nbDemandes > 0
                ? _carteHeroDemandes(nbDemandes, premiereDemande)
                : _carteHeroVideDemandes(),
          ),
          const SizedBox(height: 16),

          // ── 3. Bande de statistiques : UNE bande, chiffres grands,
          // filets verticaux, compteurs animés ──────────────────────
          Apparition(
            delaiMs: 120,
            child: BandeStatsSpec(
              chiffres: [
                (
                  valeur: statistiques['rdvAujourdhui'] ?? 0,
                  libelle: 'RDV aujourd\'hui',
                ),
                (
                  valeur: statistiques['enAttente'] ?? 0,
                  libelle: 'En attente',
                ),
                (
                  valeur: statistiques['totalPatients'] ?? 0,
                  libelle: 'Patients suivis',
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
                      child: BoutonDegradeSpec(
                        texte: 'Programmer un rendez-vous',
                        hauteur: 52,
                        maxLines: 2,
                        onPressed: onNouveauRendezVous,
                      ),
                    ),
                  ],
                  if (onNouveauPatient != null) ...[
                    if (onNouveauRendezVous != null) const SizedBox(width: 12),
                    Expanded(
                      child: BoutonContourSpec(
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
