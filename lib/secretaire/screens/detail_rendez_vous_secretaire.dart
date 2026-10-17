import 'package:flutter/material.dart';
import '../../models/rendez_vous.dart';
import '../../theme/medigo_theme.dart';
import '../../widgets/rendez_vous_card.dart';
import '../../widgets/ui_kit.dart';
import 'refuser_rendez_vous_secretaire.dart';

/// Écran de détail d'un rendez-vous, avec les actions Confirmer/Refuser/Annuler
/// réservées à la secrétaire (différent des actions du médecin, qui
/// "accepte" ou "refuse" une consultation).
class DetailRendezVousSecretaire extends StatelessWidget {
  final RendezVous rdv;
  final VoidCallback onConfirmer;
  final VoidCallback onAnnuler;
  // Refus avec motif : la secrétaire choisit une raison parmi une liste
  // prédéfinie (ou saisit un motif libre) avant de confirmer le refus.
  final Future<void> Function(RendezVous rdv, {String? motif}) onRefuser;

  const DetailRendezVousSecretaire({
    super.key,
    required this.rdv,
    required this.onConfirmer,
    required this.onAnnuler,
    required this.onRefuser,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détail du rendez-vous')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // On réutilise la carte déjà utilisée ailleurs, non cliquable
          // ici (pas de onTap) puisqu'on est déjà sur son écran de détail.
          RendezVousCard(rdv: rdv, afficherMedecin: true),
          const SizedBox(height: 20),

          _ligneInfo('Patient', rdv.patientNomComplet),
          // "??" affiche 'Non renseigné' si medecinNom est null.
          _ligneInfo('Médecin', rdv.medecinNom ?? 'Non renseigné'),
          _ligneInfo('Date', '${rdv.date.day}/${rdv.date.month}/${rdv.date.year}'),
          _ligneInfo('Heure', rdv.heure),
          if (rdv.motif != null) _ligneInfo('Motif', rdv.motif!),
          // Motif de refus : visible même après coup pour que la
          // secrétaire sache pourquoi ce RDV a été refusé.
          if (rdv.statut == StatutRendezVous.refuse &&
              rdv.motifRefus != null &&
              rdv.motifRefus!.isNotEmpty)
            _ligneInfo('Motif du refus', rdv.motifRefus!),

          const SizedBox(height: 24),

          // On ne propose les actions que si le rendez-vous est
          // encore "en_attente" : inutile de confirmer un RDV déjà
          // confirmé, ou d'annuler/refuser un RDV déjà traité.
          if (rdv.statut == StatutRendezVous.enAttente) ...[
            // Ligne 1 : Annuler (rouge) + Confirmer (vert).
            Row(
              children: [
                Expanded(
                  child: BoutonContour(
                    texte: 'Annuler',
                    couleur: AppColors.rouge,
                    onPressed: onAnnuler,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BoutonPrincipal(
                    texte: 'Confirmer',
                    couleur: AppColors.vertSante,
                    onPressed: onConfirmer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Ligne 2 : Refuser (rouge, pleine largeur).
            BoutonContour(
              texte: 'Refuser',
              couleur: AppColors.rouge,
              pleineLargeur: true,
              onPressed: () => _ouvrirRefus(context),
            ),
          ],
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
            // Ferme l'écran de détail AVANT l'appel au service.
            // L'écran de refus se ferme de son côté (Navigator.pop
            // dans _confirmerRefus). Comme ça, pas de double-pop
            // qui figerait l'interface.
            if (context.mounted) Navigator.pop(context);
            await onRefuser(rdv, motif: motif);
          },
        ),
      ),
    );
  }

  // Petite ligne "label : valeur" réutilisée pour chaque info du RDV.
  Widget _ligneInfo(String label, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              valeur,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
