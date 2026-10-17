import 'package:flutter/material.dart';
import '../../models/rendez_vous.dart';
import '../../theme/medigo_theme.dart';
import '../../widgets/rendez_vous_card.dart';
import '../../widgets/ui_kit.dart';

/// Onglet "Rendez-vous" (secrétaire) : liste de TOUS les rendez-vous de
/// l'hôpital (tous médecins), filtrable par statut, avec un bouton
/// flottant pour en programmer un nouveau.
/// Reproduit la maquette : titre + sous-titre, pilules de filtre, cartes
/// à avatar affichant le médecin.
// StatefulWidget car il doit se souvenir du filtre sélectionné.
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
  // "null" = aucun filtre actif : on affiche tout.
  StatutRendezVous? _filtreActif;

  // Ordre des chips (comme l'accueil/liste médecin) : les plus courants
  // d'abord, les autres défilent horizontalement.
  static const List<StatutRendezVous> _ordreFiltres = [
    StatutRendezVous.enAttente,
    StatutRendezVous.confirme,
    StatutRendezVous.termine,
    StatutRendezVous.refuse,
    StatutRendezVous.annule,
  ];

  // Ligne d'information d'une carte : « Dr X · motif » (le secrétaire a
  // besoin de voir LE MÉDECIN, tous confondus).
  static String _ligneMedecin(RendezVous rdv) {
    final medecin = (rdv.medecinNom ?? '').trim();
    final motif = (rdv.motif ?? '').trim();
    if (medecin.isNotEmpty && motif.isNotEmpty) return '$medecin · $motif';
    if (medecin.isNotEmpty) return medecin;
    return motif;
  }

  @override
  Widget build(BuildContext context) {
    // Liste filtrée.
    final rdvFiltres = widget.rendezVous
        .where((rdv) => _filtreActif == null || rdv.statut == _filtreActif)
        .toList();

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Titre + sous-titre (maquette) ─────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                    'Tous les rendez-vous de l\'hôpital',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.texteFaible,
                    ),
                  ),
                ],
              ),
            ),

            // ── Pilules de filtre (défilables) ────────────────────
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                children: [
                  ChipFiltrePilule(
                    label: 'Tous',
                    selectionne: _filtreActif == null,
                    onTap: () => setState(() => _filtreActif = null),
                  ),
                  ..._ordreFiltres.map(
                    (s) => ChipFiltrePilule(
                      label: libelleStatutRdv(s),
                      selectionne: _filtreActif == s,
                      onTap: () => setState(() => _filtreActif = s),
                    ),
                  ),
                ],
              ),
            ),

            // ── Liste des rendez-vous ──────────────────────────────
            Expanded(
              child: rdvFiltres.isEmpty
                  ? const Center(
                      child: EtatVide(
                        message: 'Aucun rendez-vous pour ce filtre.',
                        detail: 'Essayez un autre filtre ci-dessus.',
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: rdvFiltres.length,
                      itemBuilder: (context, index) {
                        final rdv = rdvFiltres[index];
                        return CarteRdvListe(
                          rdv: rdv,
                          sousTitre: _ligneMedecin(rdv),
                          onTap: widget.onTapRendezVous == null
                              ? null
                              : () => widget.onTapRendezVous!(rdv),
                        );
                      },
                    ),
            ),
          ],
        ),
        // ── Bouton flottant « Nouveau rendez-vous » ───────────────
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: widget.onNouveauRendezVous,
            backgroundColor: AppColors.bleuVif,
            foregroundColor: Colors.white,
            label: const Text('Nouveau rendez-vous'),
          ),
        ),
      ],
    );
  }
}
