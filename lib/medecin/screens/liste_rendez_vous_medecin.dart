import 'package:flutter/material.dart';
import '../../models/rendez_vous.dart';
import '../../theme/maquette_tokens.dart';
import '../../widgets/maquette_widgets.dart';
import '../../widgets/ui_kit.dart'; // EtatVide(), dateDuJour()

/// Onglet / écran "Rendez-vous" (maquette §4.2) : titre + sous-titre,
/// puces de période défilantes (actif = dégradé G), puis les
/// rendez-vous REGROUPÉS PAR DATE en cartes à avatar (initiales 48 px).
///
/// RÈGLE D'AFFICHAGE : le médecin ne voit que ses rendez-vous
/// CONFIRMÉS et TERMINÉS (« non terminés » compris). Les rendez-vous
/// en attente sont gérés par la secrétaire ; les refusés/annulés ne
/// le concernent plus. Voir l'arbitrage du point 3.
///
/// Filtre appliqué côté Dart : le chargeur a déjà téléchargé TOUS les
/// rendez-vous du médecin (nécessaire pour la détection des
/// notifications toutes les 5 s), une seconde requête Firestore ne
/// ferait que doubler les lectures pour un résultat identique.
// "StatefulWidget" : contrairement à AccueilMedecin (StatelessWidget),
// cet écran a besoin de RETENIR une information qui change dans le temps
// PAR LUI-MÊME (quel filtre est sélectionné) sans dépendre du parent.
class ListeRendezVousMedecin extends StatefulWidget {
  final List<RendezVous> rendezVous; // tous les rendez-vous à afficher

  /// Ids des consultations marquées « non terminées » : les cartes
  /// affichent la pastille « Non terminé » (style neutre).
  final Set<String> idsNonTermines;

  final ValueChanged<RendezVous> onTapRendezVous; // callback quand on tape une carte

  const ListeRendezVousMedecin({
    super.key,
    required this.rendezVous,
    this.idsNonTermines = const {},
    required this.onTapRendezVous,
  });

  @override
  State<ListeRendezVousMedecin> createState() =>
      _ListeRendezVousMedecinState();
}

/// Filtres de période (maquette §4.2) : remplace les anciennes puces
/// de statut, que le médecin ne pilote plus.
enum _Periode { tous, aujourdhui, aVenir, passes }

class _ListeRendezVousMedecinState extends State<ListeRendezVousMedecin> {
  // Variable d'état : la période sélectionnée (« Tous » par défaut,
  // comme l'ancien comportement « tout voir »).
  _Periode _periode = _Periode.tous;

  static const Map<_Periode, String> _libelles = {
    _Periode.tous: 'Tous',
    _Periode.aujourdhui: 'Aujourd\'hui',
    _Periode.aVenir: 'À venir',
    _Periode.passes: 'Passés',
  };

  /// Libellé d'en-tête de groupe de date : « Aujourd'hui », « Demain »
  /// ou la date longue (« Vendredi 24 octobre »).
  String _libelleJour(DateTime jour) {
    final maintenant = DateTime.now();
    final debutAujourdhui = DateTime(
      maintenant.year,
      maintenant.month,
      maintenant.day,
    );
    if (!jour.isAfter(debutAujourdhui)) return 'Aujourd\'hui';
    if (jour == debutAujourdhui.add(const Duration(days: 1))) return 'Demain';
    return dateDuJour(jour);
  }

  @override
  Widget build(BuildContext context) {
    final maintenant = DateTime.now();
    final debutJour = DateTime(
      maintenant.year,
      maintenant.month,
      maintenant.day,
    );
    final finJour = debutJour.add(const Duration(days: 1));

    // Règle d'affichage : confirmés et terminés seulement.
    final visibles = widget.rendezVous
        .where(
          (r) =>
              r.statut == StatutRendezVous.confirme ||
              r.statut == StatutRendezVous.termine,
        )
        .toList();

    // Période sélectionnée, puis tri chronologique (« du plus proche
    // au plus ancien », comme le sous-titre de l'écran).
    final rdvFiltres =
        visibles.where((r) {
          switch (_periode) {
            case _Periode.tous:
              return true;
            case _Periode.aujourdhui:
              return !r.date.isBefore(debutJour) && r.date.isBefore(finJour);
            case _Periode.aVenir:
              return !r.dateHeure.isBefore(maintenant);
            case _Periode.passes:
              return r.dateHeure.isBefore(maintenant);
          }
        }).toList()
          ..sort((a, b) => a.dateHeure.compareTo(b.dateHeure));

    // Regroupement par date (minuit du jour comme clé), dans l'ordre.
    final groupes = <DateTime, List<RendezVous>>{};
    for (final rdv in rdvFiltres) {
      final jour = DateTime(rdv.date.year, rdv.date.month, rdv.date.day);
      groupes.putIfAbsent(jour, () => []).add(rdv);
    }
    final jours = groupes.keys.toList()..sort();

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

        // ── Puces de période (pilules défilantes, actif = dégradé G) ─
        // Hauteur fixe : une ListView horizontale doit connaître sa hauteur.
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            children: [
              for (final periode in _Periode.values)
                ChipFiltreSpec(
                  label: _libelles[periode]!,
                  selectionne: _periode == periode,
                  onTap: () => setState(() => _periode = periode),
                ),
            ],
          ),
        ),

        // ── Liste des rendez-vous groupés par date ────────────────
        // Expanded : la liste prend tout l'espace vertical restant.
        Expanded(
          child: rdvFiltres.isEmpty
              ? const Center(
                  child: EtatVide(
                    message: 'Aucun rendez-vous pour ce filtre.',
                    detail: 'Essayez une autre période ci-dessus.',
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    for (final jour in jours) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                        child: Text(
                          _libelleJour(jour),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: MaquetteCouleurs.texteSecondaire,
                          ),
                        ),
                      ),
                      for (final rdv in groupes[jour]!)
                        CarteRdvListeSpec(
                          rdv: rdv,
                          nonTermine: widget.idsNonTermines.contains(rdv.id),
                          onTap: () => widget.onTapRendezVous(rdv),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
