import 'package:flutter/material.dart';
import '../../models/rendez_vous.dart';
import '../../widgets/rendez_vous_card.dart';

/// Écran de détail d'un rendez-vous, avec les actions Confirmer/Annuler
/// réservées à la secrétaire (différent des actions du médecin, qui
/// "accepte" ou "refuse" une consultation).
class DetailRendezVousSecretaire extends StatelessWidget {
  final RendezVous rdv;
  final VoidCallback onConfirmer;
  final VoidCallback onAnnuler;

  const DetailRendezVousSecretaire({
    super.key,
    required this.rdv,
    required this.onConfirmer,
    required this.onAnnuler,
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

          const SizedBox(height: 24),

          // On ne propose Confirmer/Annuler que si le rendez-vous est
          // encore "en_attente" : inutile de confirmer un RDV déjà
          // confirmé, ou d'annuler un RDV déjà annulé/terminé.
          if (rdv.statut == StatutRendezVous.enAttente)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onAnnuler,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      side: const BorderSide(color: Color(0xFFC62828)),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirmer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                    ),
                    child: const Text('Confirmer'),
                  ),
                ),
              ],
            ),
        ],
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
