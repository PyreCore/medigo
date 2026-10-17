import 'package:flutter/material.dart';
import '../../models/rendez_vous.dart';
import '../../theme/medigo_theme.dart';
import '../../widgets/ui_kit.dart';

/// Écran de détail d'un rendez-vous, avec actions accepter / refuser.
/// Reproduit la maquette : en-tête (retour + titre + badge), carte en
/// dégradé lavande→indigo (avatar, nom, Date/Heure/Motif), carte
/// « Informations du patient » à icônes, pied de boutons fixe.
// StatelessWidget : cet écran affiche juste les infos du rdv reçu et
// délègue les actions (accepter/refuser) au parent.
class DetailRendezVousMedecin extends StatelessWidget {
  final RendezVous rdv;

  // Fonctions optionnelles et ASYNCHRONES (Future<void> car elles vont
  // appeler Firestore). Si null, le bouton correspondant est désactivé.
  final Future<void> Function()? onAccepter;
  final Future<void> Function()? onRefuser;

  const DetailRendezVousMedecin({
    super.key,
    required this.rdv,
    this.onAccepter,
    this.onRefuser,
  });

  // Carte principale (dégradé) : avatar + nom + sous-titre, puis les
  // lignes Date / Heure / Motif séparées par de fins filets.
  Widget _carteInfo(String dateLongue) {
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
              // Avatar blanc + initiales bleues (comme la maquette).
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
                    const Text(
                      'Consultation de suivi',
                      style: TextStyle(
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
          // Lignes « libellé …… valeur », chacune précédée d'un filet.
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
        border: Border.all(
          color: AppColors.rougeBadge.withValues(alpha: 0.3),
        ),
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

  // Carte « Informations du patient » : 3 lignes à icône pastel,
  // exactement la maquette. (Le modèle RendezVous ne porte pas le
  // téléphone / la date de naissance / le groupe sanguin : on affiche
  // « Non renseigné » plutôt que d'inventer des données.)
  Widget _infosPatient() {
    return CarteMedigo(
      padding: const EdgeInsets.all(16),
      rayon: Rayons.carte,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations du patient',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 2),
          _LignePatient(
            icone: Icons.phone_outlined,
            fond: AppColors.bleuClair,
            couleur: AppColors.bleuVif,
            libelle: 'Téléphone',
            valeur: 'Non renseigné',
          ),
          _LignePatient(
            icone: Icons.calendar_month_outlined,
            fond: AppColors.bleuClair,
            couleur: AppColors.bleuVif,
            libelle: 'Date de naissance',
            valeur: 'Non renseigné',
          ),
          _LignePatient(
            icone: Icons.bloodtype_outlined,
            fond: AppColors.roseClair,
            couleur: AppColors.rougeBadge,
            libelle: 'Groupe sanguin',
            valeur: 'Non renseigné',
          ),
        ],
      ),
    );
  }

  // Pied fixe : Refuser (contour rouge) + Accepter (dégradé signature).
  // Il ne s'affiche QUE si le rendez-vous est encore en attente.
  Widget _piedActions(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.trait)),
      ),
      child: Row(
        children: [
          Expanded(
            child: BoutonContour(
              texte: 'Refuser',
              couleur: AppColors.rouge,
              hauteur: 52,
              onPressed: onRefuser == null
                  ? null
                  : () async {
                      await onRefuser!();
                      if (context.mounted) Navigator.pop(context);
                    },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: BoutonDegrade(
              texte: 'Accepter',
              hauteur: 52,
              onPressed: onAccepter == null
                  ? null
                  : () async {
                      await onAccepter!();
                      if (context.mounted) Navigator.pop(context);
                    },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // On ne propose Accepter/Refuser que si le rendez-vous est en attente.
    final enAttente = rdv.statut == StatutRendezVous.enAttente;
    // Date longue en français + année, ex : « Jeudi 15 octobre 2026 ».
    final dateLongue = '${dateDuJour(rdv.date)} ${rdv.date.year}';

    // Pas d'AppBar Material : on construit l'en-tête de la maquette
    // (chevron de retour + titre + badge de statut) nous-mêmes.
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
                  const SizedBox(height: 16),
                  _infosPatient(),
                ],
              ),
            ),

            // ── Pied de boutons (seulement si en attente) ─────────────
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

// Ligne « pastille icône + libellé + valeur » de la carte patient,
// précédée d'un filet gris.
class _LignePatient extends StatelessWidget {
  final IconData icone;
  final Color fond;
  final Color couleur;
  final String libelle;
  final String valeur;

  const _LignePatient({
    required this.icone,
    required this.fond,
    required this.couleur,
    required this.libelle,
    required this.valeur,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: 1, color: AppColors.trait),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: fond, shape: BoxShape.circle),
                child: Icon(icone, size: 19, color: couleur),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      libelle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.texteFaible,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      valeur,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
