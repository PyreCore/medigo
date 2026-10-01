import 'package:flutter/material.dart';
import '../../models/rendez_vous.dart';
import '../../widgets/rendez_vous_card.dart';

/// Écran de détail d'un rendez-vous vu par le patient, avec l'action
/// "Annuler". Même structure que DetailRendezVousMedecin, mais les
/// actions offertes sont celles dont le patient est acteur.
class DetailRendezVousPatient extends StatelessWidget {
  final RendezVous rdv;

  // Fonction optionnelle et ASYNCHRONE appelée quand on appuie sur
  // "Annuler". Null = bouton désactivé.
  final Future<void> Function()? onAnnuler;

  // Appelé quand on appuie sur "Modifier". Null = bouton désactivé. Le
  // parent bascule le formulaire de prise de rendez-vous en mode édition.
  final VoidCallback? onModifier;

  const DetailRendezVousPatient({
    super.key,
    required this.rdv,
    this.onAnnuler,
    this.onModifier,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = couleurStatutRdv(rdv.statut);

    // Règle métier : le patient n'a les mains libres sur le rendez-vous que
    // tant que la secrétaire ne l'a pas confirmé. La décision est prise par
    // le modèle (RendezVous.modifiableParPatient) pour que l'écran et le
    // service ne puissent pas diverger.
    final modifiable = rdv.modifiableParPatient;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(title: const Text('Détail du rendez-vous')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom du médecin à gauche, badge de statut à droite.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        rdv.medecinNom ?? 'Médecin à confirmer',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: couleur.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        libelleStatutRdv(rdv.statut),
                        style: TextStyle(
                          color: couleur,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _LigneInfo(
                  icone: Icons.calendar_today,
                  texte: '${rdv.date.day}/${rdv.date.month}/${rdv.date.year}',
                ),
                const SizedBox(height: 8),
                _LigneInfo(icone: Icons.access_time, texte: rdv.heure),
                if (rdv.motif != null && rdv.motif!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _LigneInfo(icone: Icons.notes, texte: rdv.motif!),
                ],
              ],
            ),
          ),
          // Bandeau d'explication du statut. Il est calculé une seule fois
          // pour tous les cas (voir _bandeauStatut) au lieu d'un "if" par
          // statut : ajouter un statut ne demande plus qu'une ligne dans
          // cette méthode, et rien à changer ici.
          if (_bandeauStatut() case final bandeau?) ...[
            const SizedBox(height: 16),
            bandeau,
          ],
          if (modifiable) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.edit_calendar),
                label: const Text('Modifier le rendez-vous'),
                onPressed: onModifier,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC62828),
                  side: const BorderSide(color: Color(0xFFC62828)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.event_busy),
                label: const Text('Annuler le rendez-vous'),
                onPressed: onAnnuler == null
                    ? null
                    : () async {
                        // Confirmation avant d'écrire dans Firestore : on
                        // ne peut pas revenir en arrière une fois annulé.
                        // Variable nommée "confirmeAnnulation" et non
                        // "confirme" : ce dernier désigne déjà le statut du
                        // rendez-vous plus haut, et le réutiliser ici
                        // masquerait ce statut.
                        final confirmeAnnulation = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Annuler ce rendez-vous ?'),
                            content: const Text(
                              'Cette action est définitive. Vous pourrez '
                              'en demander un nouveau à tout moment.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, false),
                                child: const Text('Conserver'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, true),
                                child: const Text('Annuler le RDV'),
                              ),
                            ],
                          ),
                        );
                        if (confirmeAnnulation != true) return;

                        await onAnnuler!();
                        if (context.mounted) Navigator.pop(context);
                      },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Bandeau expliquant au patient où en est son rendez-vous et ce qu'il peut
  // encore en faire. Retourne null quand il n'y a rien à dire : un
  // rendez-vous "terminé" est un document d'archive, pas une information
  // à suivre.
  //
  // Les couleurs ne sont PAS recopiées ici : elles viennent de
  // couleurStatutRdv, la fonction qui colorie déjà le badge affiché dans
  // la carte du dessus. Bandeau et badge ne peuvent donc pas diverger.
  _InfoBandeau? _bandeauStatut() {
    switch (rdv.statut) {
      case StatutRendezVous.enAttente:
        return _InfoBandeau(
          icone: Icons.hourglass_bottom,
          couleur: couleurStatutRdv(rdv.statut),
          texte:
              'Votre demande a bien été envoyée. Le médecin doit encore '
              'la confirmer : vous serez notifié de sa réponse.',
        );
      case StatutRendezVous.confirme:
        return _InfoBandeau(
          icone: Icons.check_circle,
          couleur: couleurStatutRdv(rdv.statut),
          texte:
              'Ce rendez-vous est confirmé. Présentez-vous à l\'accueil '
              '15 minutes avant l\'heure prévue.',
        );
      case StatutRendezVous.refuse:
        return _InfoBandeau(
          icone: Icons.cancel,
          couleur: couleurStatutRdv(rdv.statut),
          texte:
              'Votre demande a été refusée. Contactez la secrétaire pour '
              'demander un nouveau créneau.',
        );
      case StatutRendezVous.annule:
        return _InfoBandeau(
          icone: Icons.event_busy,
          couleur: couleurStatutRdv(rdv.statut),
          texte: 'Ce rendez-vous a été annulé.',
        );
      case StatutRendezVous.termine:
        return null;
    }
  }
}

// Bandeau d'information coloré : une icône et un texte sur fond teinté
// dans la couleur du statut. Partagé par les quatre bandeaux possibles
// pour qu'ils aient tous exactement la même mise en page.
class _InfoBandeau extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String texte;

  const _InfoBandeau({
    required this.icone,
    required this.couleur,
    required this.texte,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: couleur),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texte,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

// Ligne "icône + texte" (date, heure, motif).
class _LigneInfo extends StatelessWidget {
  final IconData icone;
  final String texte;
  const _LigneInfo({required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, size: 18, color: Colors.black45),
        const SizedBox(width: 8),
        Expanded(child: Text(texte)),
      ],
    );
  }
}
