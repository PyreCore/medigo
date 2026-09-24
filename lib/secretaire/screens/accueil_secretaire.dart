import 'package:flutter/material.dart';
import '../../models/secretaire.dart';
import '../../models/rendez_vous.dart';
import '../../widgets/rendez_vous_card.dart';

/// Onglet "Accueil" de l'espace secrétaire : en-tête avec le nom de la
/// secrétaire et son hôpital, quelques statistiques, et la liste des
/// rendez-vous du jour pour TOUT l'hôpital (tous médecins confondus).
class AccueilSecretaire extends StatelessWidget {
  final Secretaire secretaire;
  final List<RendezVous> rendezVousDuJour;
  final Map<String, int> statistiques;

  // Fonction appelée quand on tape sur un rendez-vous, pour aller voir
  // son détail. Le "?" la rend optionnelle.
  final void Function(RendezVous)? onTapRendezVous;

  const AccueilSecretaire({
    super.key,
    required this.secretaire,
    required this.rendezVousDuJour,
    required this.statistiques,
    this.onTapRendezVous,
  });

  @override
  Widget build(BuildContext context) {
    // ListView au lieu de Column : permet de défiler si le contenu
    // dépasse la hauteur de l'écran (utile s'il y a beaucoup de RDV).
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // En-tête : nom de la secrétaire + hôpital.
        Text(
          'Bonjour, ${secretaire.nomComplet}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          secretaire.hopitalNom,
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),

        // Row de 3 cartes de statistiques, comme sur le tableau de bord médecin.
        Row(
          children: [
            Expanded(
              child: _CarteStat(
                valeur: statistiques['rdvAujourdhui'] ?? 0,
                libelle: 'RDV aujourd\'hui',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CarteStat(
                valeur: statistiques['enAttente'] ?? 0,
                libelle: 'En attente',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CarteStat(
                valeur: statistiques['totalPatients'] ?? 0,
                libelle: 'Patients',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        const Text(
          'Rendez-vous du jour',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),

        // "..." (spread operator) : si rendezVousDuJour est vide, on
        // insère une seule Text "Aucun rendez-vous" ; sinon, on transforme
        // chaque RendezVous en RendezVousCard et on les insère toutes.
        if (rendezVousDuJour.isEmpty)
          const Text(
            'Aucun rendez-vous aujourd\'hui.',
            style: TextStyle(color: Colors.black45),
          )
        else
          ...rendezVousDuJour.map(
            (rdv) => RendezVousCard(
              rdv: rdv,
              // On affiche le nom du médecin ici, car contrairement au
              // médecin, la secrétaire voit plusieurs médecins mélangés.
              afficherMedecin: true,
              onTap: onTapRendezVous != null
                  ? () => onTapRendezVous!(rdv)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Petite carte réutilisée 3 fois ci-dessus, gardée privée à ce fichier
/// (underscore _ devant le nom) car elle n'a pas d'utilité ailleurs.
class _CarteStat extends StatelessWidget {
  final int valeur;
  final String libelle;

  const _CarteStat({required this.valeur, required this.libelle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Text(
            '$valeur',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            libelle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
