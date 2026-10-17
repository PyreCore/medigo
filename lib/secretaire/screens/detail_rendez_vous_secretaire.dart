import 'package:flutter/material.dart';
import '../../models/rendez_vous.dart';
import '../../theme/medigo_theme.dart';
import '../../widgets/ui_kit.dart';
import 'refuser_rendez_vous_secretaire.dart';

/// Écran de détail d'un rendez-vous (secrétaire), avec les actions
/// Confirmer / Annuler / Refuser.
/// Reproduit la maquette du détail : en-tête (retour + titre + badge),
/// carte en dégradé (avatar, nom, médecin, Date/Heure/Motif), bandeau de
/// refus, pied de boutons fixe.
class DetailRendezVousSecretaire extends StatelessWidget {
  final RendezVous rdv;
  final VoidCallback onConfirmer;
  final VoidCallback onAnnuler;
  // Refus avec motif : la secrétaire choisit une raison avant de confirmer.
  final Future<void> Function(RendezVous rdv, {String? motif}) onRefuser;

  const DetailRendezVousSecretaire({
    super.key,
    required this.rdv,
    required this.onConfirmer,
    required this.onAnnuler,
    required this.onRefuser,
  });

  // Carte dégradée : avatar + nom + médecin, puis Date / Heure / Motif.
  Widget _carteInfo(String dateLongue) {
    final medecin = (rdv.medecinNom ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: degradeDetail,
        borderRadius: BorderRadius.circular(Rayons.carte),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initiales(rdv.patientPrenom, rdv.patientNom),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.bleuVif,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rdv.patientNomComplet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      medecin.isNotEmpty ? medecin : 'Consultation de suivi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.texteFaible,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _LigneDetail(libelle: 'Date', valeur: dateLongue, separateur: true),
          _LigneDetail(libelle: 'Heure', valeur: rdv.heure, separateur: true),
          if (rdv.motif != null && rdv.motif!.isNotEmpty)
            _LigneDetail(libelle: 'Motif', valeur: rdv.motif!, separateur: true),
        ],
      ),
    );
  }

  // Bandeau « refusé » : la raison du refus reste toujours visible.
  Widget _bandeauRefus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.roseClair,
        borderRadius: BorderRadius.circular(Rayons.carte),
        border: Border.all(color: AppColors.rougeBadge.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rendez-vous refusé',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.rougeBadge,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rdv.motifRefus!,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: AppColors.texte,
            ),
          ),
        ],
      ),
    );
  }

  // Pied fixe : Annuler + Confirmer, puis Refuser en pleine largeur.
  Widget _piedActions(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.trait)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: BoutonContour(
                  texte: 'Annuler',
                  couleur: AppColors.rouge,
                  hauteur: 52,
                  onPressed: onAnnuler,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BoutonPrincipal(
                  texte: 'Confirmer',
                  couleur: AppColors.vertSante,
                  hauteur: 52,
                  onPressed: onConfirmer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          BoutonContour(
            texte: 'Refuser',
            couleur: AppColors.rouge,
            pleineLargeur: true,
            hauteur: 52,
            onPressed: () => _ouvrirRefus(context),
          ),
        ],
      ),
    );
  }

  /// Ouvre l'écran de sélection du motif de refus.
  void _ouvrirRefus(BuildContext context) {
    Navigator.push(
      context,
      routeMedigo(
        builder: (_) => RefuserRendezVousSecretaire(
          rdvId: rdv.id,
          onRefuser: (rdvId, {motif}) async {
            // Ferme le détail AVANT l'appel au service (pas de double-pop).
            if (context.mounted) Navigator.pop(context);
            await onRefuser(rdv, motif: motif);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enAttente = rdv.statut == StatutRendezVous.enAttente;
    final dateLongue = '${dateDuJour(rdv.date)} ${rdv.date.year}';

    return Scaffold(
      backgroundColor: AppColors.fond,
      body: SafeArea(
        child: Column(
          children: [
            // ── En-tête : retour + titre + badge statut ──────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.chevron_left,
                      size: 28,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Expanded(
                    child: Text(
                      'Détail du rendez-vous',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  PastilleStatut(statut: rdv.statut),
                ],
              ),
            ),

            // ── Contenu défilant ──────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _carteInfo(dateLongue),
                  if (rdv.statut == StatutRendezVous.refuse &&
                      rdv.motifRefus != null &&
                      rdv.motifRefus!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _bandeauRefus(),
                  ],
                ],
              ),
            ),

            // ── Pied d'actions (seulement si en attente) ──────────────
            if (enAttente) _piedActions(context),
          ],
        ),
      ),
    );
  }
}

// Ligne « libellé …… valeur » de la carte dégradée, précédée d'un filet.
class _LigneDetail extends StatelessWidget {
  final String libelle;
  final String valeur;
  final bool separateur;

  const _LigneDetail({
    required this.libelle,
    required this.valeur,
    this.separateur = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (separateur)
          Container(height: 1, color: AppColors.navy.withValues(alpha: 0.08)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                libelle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.texteFaible,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  valeur,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
