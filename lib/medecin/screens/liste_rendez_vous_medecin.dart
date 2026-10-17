import 'package:flutter/material.dart';
import '../../models/rendez_vous.dart';
import '../../theme/medigo_theme.dart';
import '../../widgets/rendez_vous_card.dart';
import '../../widgets/ui_kit.dart';

/// Onglet / écran "Rendez-vous" : titre + sous-titre (maquette), barre de
/// filtres par statut, puis la liste des rendez-vous (cartes à avatar).
// "StatefulWidget" : contrairement à AccueilMedecin (StatelessWidget),
// cet écran a besoin de RETENIR une information qui change dans le temps
// PAR LUI-MÊME (quel filtre est sélectionné) sans dépendre du parent.
class ListeRendezVousMedecin extends StatefulWidget {
  final List<RendezVous> rendezVous; // tous les rendez-vous à afficher
  final ValueChanged<RendezVous> onTapRendezVous; // callback quand on tape une carte

  const ListeRendezVousMedecin({
    super.key,
    required this.rendezVous,
    required this.onTapRendezVous,
  });

  @override
  State<ListeRendezVousMedecin> createState() =>
      _ListeRendezVousMedecinState();
}

class _ListeRendezVousMedecinState extends State<ListeRendezVousMedecin> {
  // Variable d'état : le filtre actuellement sélectionné.
  // "null" = pas de filtre = on affiche tous les statuts.
  StatutRendezVous? _filtre;

  // Ordre des chips de filtre : on met d'abord ceux que la maquette montre
  // à l'écran (En attente, Confirmés, Terminés), puis les autres (qui
  // défilent horizontalement) pour garder le filtre complet.
  static const List<StatutRendezVous> _ordreFiltres = [
    StatutRendezVous.enAttente,
    StatutRendezVous.confirme,
    StatutRendezVous.termine,
    StatutRendezVous.refuse,
    StatutRendezVous.annule,
  ];

  @override
  Widget build(BuildContext context) {
    // Liste filtrée : sans filtre on garde tout, sinon on ne garde que le
    // statut sélectionné.
    final rdvFiltres = _filtre == null
        ? widget.rendezVous
        : widget.rendezVous.where((r) => r.statut == _filtre).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Titre + sous-titre (reproduit la maquette) ─────────────
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rendez-vous',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Tous vos rendez-vous, du plus proche au plus ancien',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.texteFaible,
                ),
              ),
            ],
          ),
        ),

        // ── Chips de filtre (pilules horizontales) ────────────────
        // Hauteur fixe : une ListView horizontale doit connaître sa hauteur.
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            children: [
              // Chip « Tous » : aucun filtre actif.
              ChipFiltrePilule(
                label: 'Tous',
                selectionne: _filtre == null,
                onTap: () => setState(() => _filtre = null),
              ),
              // Un chip par statut, dans l'ordre choisi ci-dessus.
              ..._ordreFiltres.map(
                (s) => ChipFiltrePilule(
                  label: libelleStatutRdv(s),
                  selectionne: _filtre == s,
                  onTap: () => setState(() => _filtre = s),
                ),
              ),
            ],
          ),
        ),

        // ── Liste des rendez-vous ──────────────────────────────────
        // Expanded : la liste prend tout l'espace vertical restant.
        Expanded(
          child: rdvFiltres.isEmpty
              ? const Center(
                  child: EtatVide(
                    message: 'Aucun rendez-vous dans cette catégorie',
                    detail: 'Essayez un autre filtre ci-dessus.',
                  ),
                )
              // ListView.builder : n'a construit que les cartes visibles.
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: rdvFiltres.length,
                  itemBuilder: (context, index) {
                    final rdv = rdvFiltres[index];
                    return CarteRdvListe(
                      rdv: rdv,
                      onTap: () => widget.onTapRendezVous(rdv),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
