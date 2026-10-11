import 'package:flutter/material.dart';
import '../../models/rendez_vous.dart';
import '../../theme/medigo_theme.dart';
import '../../widgets/rendez_vous_card.dart';

/// Onglet "Rendez-vous" : liste complète des rendez-vous de l'hôpital
/// (tous médecins confondus), filtrable par statut, avec un bouton "+"
/// pour en programmer un nouveau.
// StatefulWidget car ce widget doit se souvenir du filtre actuellement
// sélectionné (ex: "En attente") entre chaque interaction.
class ListeRendezVousSecretaire extends StatefulWidget {
  final List<RendezVous> rendezVous;
  final void Function(RendezVous)? onTapRendezVous;
  final VoidCallback onNouveauRendezVous;

  const ListeRendezVousSecretaire({
    super.key,
    required this.rendezVous,
    required this.onNouveauRendezVous,
    this.onTapRendezVous,
  });

  @override
  State<ListeRendezVousSecretaire> createState() =>
      _ListeRendezVousSecretaireState();
}

class _ListeRendezVousSecretaireState
    extends State<ListeRendezVousSecretaire> {
  // "null" veut dire "aucun filtre actif" : on affiche tout.
  StatutRendezVous? _filtreActif;

  @override
  Widget build(BuildContext context) {
    // On calcule la liste filtrée à chaque reconstruction de l'écran :
    // si _filtreActif est null, on garde tout (.where retourne toujours
    // vrai) ; sinon, on ne garde que les rendez-vous du statut choisi.
    final rdvFiltres = widget.rendezVous
        .where((rdv) => _filtreActif == null || rdv.statut == _filtreActif)
        .toList();

    return Stack(
      children: [
        Column(
          children: [
            // Ligne horizontale de filtres, défilable si elle ne tient
            // pas sur la largeur de l'écran.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _puceFiltre(null, 'Tous'),
                  const SizedBox(width: 8),
                  _puceFiltre(StatutRendezVous.enAttente, 'En attente'),
                  const SizedBox(width: 8),
                  _puceFiltre(StatutRendezVous.confirme, 'Confirmés'),
                  const SizedBox(width: 8),
                  _puceFiltre(StatutRendezVous.annule, 'Annulés'),
                ],
              ),
            ),
            // Expanded : la liste prend tout l'espace vertical restant
            // sous la ligne de filtres.
            Expanded(
              child: rdvFiltres.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucun rendez-vous pour ce filtre.',
                        style: TextStyle(color: Colors.black45),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      itemCount: rdvFiltres.length,
                      itemBuilder: (context, index) {
                        final rdv = rdvFiltres[index];
                        return RendezVousCard(
                          rdv: rdv,
                          afficherMedecin: true,
                          onTap: widget.onTapRendezVous != null
                              ? () => widget.onTapRendezVous!(rdv)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          // Bouton étendu : libellé texte seul (pas d'icône "+").
          child: FloatingActionButton.extended(
            onPressed: widget.onNouveauRendezVous,
            backgroundColor: const Color(0xFF0B57D0), // bleuMedical
            foregroundColor: Colors.white,
            label: const Text('Nouveau rendez-vous'),
          ),
        ),
      ],
    );
  }

  // Construit une "puce" cliquable pour un filtre donné.
  // Design épuré : texte seul, sans rectangle ni bordure.
  // La puce active est en gras et colorée, les autres en gris.
  Widget _puceFiltre(StatutRendezVous? valeur, String libelle) {
    final estActif = _filtreActif == valeur;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filtreActif = valeur;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          libelle,
          style: TextStyle(
            fontSize: 13,
            fontWeight: estActif ? FontWeight.w700 : FontWeight.w400,
            color: estActif ? AppColors.bleuMedical : AppColors.texteFaible,
          ),
        ),
      ),
    );
  }
}
