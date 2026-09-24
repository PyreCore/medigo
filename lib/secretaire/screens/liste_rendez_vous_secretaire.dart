import 'package:flutter/material.dart';
import '../../models/rendez_vous.dart';
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
          child: FloatingActionButton(
            onPressed: widget.onNouveauRendezVous,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  // Construit une "puce" cliquable (ChoiceChip) pour un filtre donné.
  // "valeur" est le statut associé (ou null pour "Tous").
  Widget _puceFiltre(StatutRendezVous? valeur, String libelle) {
    return ChoiceChip(
      label: Text(libelle),
      // "selected" détermine si la puce apparaît "active" visuellement :
      // vrai quand le filtre actuellement choisi correspond à cette puce.
      selected: _filtreActif == valeur,
      // Appelé quand on tape sur la puce. "setState" prévient Flutter
      // qu'une donnée a changé et qu'il doit redessiner l'écran.
      onSelected: (_) {
        setState(() {
          _filtreActif = valeur;
        });
      },
    );
  }
}
