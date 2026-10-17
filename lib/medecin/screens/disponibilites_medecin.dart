import 'package:flutter/material.dart';
import '../../models/medecin.dart';
import '../../models/disponibilite.dart';
import '../../services/disponibilite_service.dart';
import '../../theme/medigo_theme.dart';
import '../../widgets/ui_kit.dart';

/// Onglet "Disponibilités" : le médecin CONSULTE ses plages horaires.
///
/// Mode LECTURE SEULE : la gestion des horaires appartient à la secrétaire
/// de l'hôpital (voir horaires_medecins_secretaire.dart pour l'édition).
/// Reproduit la maquette : titre, bandeau « Lecture seule », une carte
/// regroupant les 7 jours (séparés par des filets, pastilles d'heure ou
/// « Indisponible »), puis la durée d'une consultation.
///
/// Écriture dans Firestore (collection "disponibilites") : chaque plage
/// est un document distinct (matin et après-midi séparés).
class DisponibilitesMedecin extends StatefulWidget {
  final Medecin medecin;

  const DisponibilitesMedecin({super.key, required this.medecin});

  @override
  State<DisponibilitesMedecin> createState() => _DisponibilitesMedecinState();
}

class _DisponibilitesMedecinState extends State<DisponibilitesMedecin> {
  final _service = DisponibiliteService();

  List<Disponibilite> _disponibilites = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    try {
      final dispos = await _service.getDisponibilites(widget.medecin.id);
      if (!mounted) return;
      setState(() {
        _disponibilites = dispos;
        _chargement = false;
        _erreur = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = 'Impossible de charger vos disponibilités';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erreur != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_erreur!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _charger, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Titre + sous-titre (maquette) ─────────────────────────
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mes disponibilités',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Vos horaires de consultation',
              style: TextStyle(fontSize: 14, color: AppColors.texteFaible),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Bandeau « Lecture seule » (maquette) ─────────────────
        const BandeauInfo(
          icone: Icons.lock_outline,
          titre: 'Lecture seule',
          corps:
              'Vos horaires sont gérés par la secrétaire de l\'hôpital. '
              'Pour toute modification, contactez-la directement.',
        ),
        const SizedBox(height: 16),

        // ── Carte des 7 jours (séparés par des filets) ──────────
        CarteMedigo(
          padding: const EdgeInsets.symmetric(vertical: 4),
          rayon: Rayons.carte,
          child: Column(
            children: [
              for (int jour = 1; jour <= 7; jour++) ...[
                // Filet de séparation entre les jours (pas au-dessus du 1er).
                if (jour > 1)
                  Container(height: 1, color: AppColors.trait),
                _LigneJour(
                  jour: jour,
                  // On n'affiche QUE les plages actives : une plage inactive
                  // n'est pas réservable, donc le jour devient « Indisponible ».
                  plages: _disponibilites
                      .where((d) => d.jour == jour && d.actif)
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Durée d'une consultation (maquette) ──────────────────
        CarteMedigo(
          padding: const EdgeInsets.all(16),
          rayon: Rayons.carte,
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Durée d\'une consultation',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const Text(
                '30 min',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.bleuVif,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Une ligne de jour : le nom à gauche, puis à droite les plages actives
/// (pastilles « début à fin ») ou « Indisponible » si le jour n'a aucune
/// plage active.
class _LigneJour extends StatelessWidget {
  final int jour;
  final List<Disponibilite> plages; // plages ACTIVES uniquement

  const _LigneJour({required this.jour, required this.plages});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Nom du jour, à gauche.
          Expanded(
            child: Text(
              Disponibilite.nomJour(jour),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
          // À droite : les plages, ou « Indisponible ».
          if (plages.isEmpty)
            const Text(
              'Indisponible',
              style: TextStyle(fontSize: 13.5, color: AppColors.texteFaible),
            )
          else
            Flexible(
              // Wrap : si plusieurs plages tiennent mal sur un écran étroit,
              // elles passent à la ligne au lieu de déborder.
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: plages
                    .map(
                      (p) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PastilleHeure(heure: p.heureDebut),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              'à',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.texteFaible,
                              ),
                            ),
                          ),
                          _PastilleHeure(heure: p.heureFin),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pastille d'heure des disponibilités : fond bleu clair, heure navy gras.
class _PastilleHeure extends StatelessWidget {
  final String heure;

  const _PastilleHeure({required this.heure});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bleuClair,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        heure,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
    );
  }
}
