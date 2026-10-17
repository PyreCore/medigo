import 'package:flutter/material.dart';
import '../../models/rendez_vous.dart';
import '../../theme/maquette_tokens.dart';
import '../../widgets/maquette_widgets.dart';
import '../../widgets/rendez_vous_card.dart'; // libelleStatutRdv()
import '../../widgets/ui_kit.dart'; // EtatVide()

/// Onglet / écran "Rendez-vous" (maquette §4.2) : titre + sous-titre,
/// puces de filtre défilantes (actif = dégradé G), puis la liste des
/// rendez-vous en cartes à avatar (initiales 48 px).
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

  // Ordre des chips de filtre : « Tous » puis les statuts, du plus
  // courant au plus rare (les puces défilent horizontalement).
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
        // ── Titre + sous-titre (maquette §4.2) ────────────────────
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rendez-vous',
                style: TextStyle(
                  fontSize: MaquetteTypo.titreEcran,
                  fontWeight: FontWeight.w800,
                  color: MaquetteCouleurs.texte,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Tous vos rendez-vous, du plus proche au plus ancien',
                style: TextStyle(
                  fontSize: 13,
                  color: MaquetteCouleurs.texteSecondaire,
                ),
              ),
            ],
          ),
        ),

        // ── Puces de filtre (pilules défilantes, actif = dégradé G) ─
        // Hauteur fixe : une ListView horizontale doit connaître sa hauteur.
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            children: [
              // Chip « Tous » : aucun filtre actif.
              ChipFiltreSpec(
                label: 'Tous',
                selectionne: _filtre == null,
                onTap: () => setState(() => _filtre = null),
              ),
              // Une puce par statut, dans l'ordre choisi ci-dessus.
              ..._ordreFiltres.map(
                (s) => ChipFiltreSpec(
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
                    message: 'Aucun rendez-vous dans cette catégorie.',
                    detail: 'Essayez un autre filtre ci-dessus.',
                  ),
                )
              // ListView.builder : n'a construit que les cartes visibles.
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: rdvFiltres.length,
                  itemBuilder: (context, index) {
                    final rdv = rdvFiltres[index];
                    return CarteRdvListeSpec(
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
