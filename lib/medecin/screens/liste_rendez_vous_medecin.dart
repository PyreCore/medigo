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

  // ── Corbeille (ajout) ────────────────────────────────────────────

  /// Contenu de la corbeille du médecin : rendez-vous + date de mise à
  /// la corbeille (record structurel, cf. MedecinService.getCorbeille).
  final List<({RendezVous rdv, DateTime corbeilleLe})> corbeille;

  /// Appelé à l'ouverture de l'onglet Corbeille (purge à 30 jours puis
  /// rechargement) — voir MedecinHomeLoader._ouvrirCorbeille.
  final Future<void> Function()? onOuvrirCorbeille;

  /// Remet un rendez-vous corbeillé dans les listes normales.
  final Future<void> Function(RendezVous rdv)? onRestaurer;

  /// Suppression définitive (confirmation demandée dans l'écran avant
  /// l'appel de ce callback).
  final Future<void> Function(RendezVous rdv)? onSupprimerDefinitivement;

  const ListeRendezVousMedecin({
    super.key,
    required this.rendezVous,
    this.idsNonTermines = const {},
    required this.onTapRendezVous,
    this.corbeille = const [],
    this.onOuvrirCorbeille,
    this.onRestaurer,
    this.onSupprimerDefinitivement,
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

  // (AJOUT) false = vue « Rendez-vous » (liste normale), true = vue
  // « Corbeille ». Un segment sous le titre bascule entre les deux.
  bool _vueCorbeille = false;

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

  // ── Vue « Corbeille » (ajout) ─────────────────────────────────────

  /// Bascule entre la liste normale et la corbeille. L'ouverture de la
  /// corbeille déclenche la purge à 30 jours (callback → chargeur →
  /// MedecinService.purgerCorbeille).
  void _ouvrirVue(bool corbeille) {
    if (_vueCorbeille == corbeille) return;
    setState(() => _vueCorbeille = corbeille);
    if (corbeille) widget.onOuvrirCorbeille?.call();
  }

  /// Mention d'une ligne de corbeille : compte à rebours pour un
  /// éventuel annulé / refusé (purgés à 30 jours), mention honnête
  /// pour les terminés (jamais purgés : historique patient).
  static String _mentionCorbeille(RendezVous rdv, DateTime corbeilleLe) {
    if (rdv.statut == StatutRendezVous.termine) return 'Conservé — historique';
    final jours = 30 - DateTime.now().difference(corbeilleLe).inDays;
    // Plancher à 1 : la purge a lieu à l'ouverture de l'onglet.
    return jours <= 1
        ? 'Suppression dans 1 jour'
        : 'Suppression dans $jours jours';
  }

  /// Confirmation OBLIGATOIRE avant la suppression définitive (même
  /// boîte de dialogue que les actions du détail médecin).
  Future<void> _confirmerSuppression(RendezVous rdv) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: MaquetteCouleurs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MaquetteRayons.carte),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Supprimer définitivement ?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MaquetteCouleurs.texte,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Le rendez-vous de ${rdv.patientNomComplet} sera supprimé '
                'de façon définitive. Cette action est irréversible.',
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: MaquetteCouleurs.texteSecondaire,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: BoutonContourSpec(
                      texte: 'Annuler',
                      couleur: MaquetteCouleurs.texteSecondaire,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BoutonContourSpec(
                      texte: 'Supprimer',
                      couleur: MaquetteCouleurs.refuseTexte,
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm != true) return;
    await widget.onSupprimerDefinitivement?.call(rdv);
  }

  /// Segment « Rendez-vous / Corbeille » : la part active passe par le
  /// dégradé principal (même code couleur que les puces de période).
  Widget _segment({
    required String libelle,
    required bool actif,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: actif ? MaquetteDegrades.principal : null,
            color: actif ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(MaquetteRayons.puce),
          ),
          child: Text(
            libelle,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: actif ? Colors.white : MaquetteCouleurs.texteSecondaire,
            ),
          ),
        ),
      ),
    );
  }

  /// Liste des rendez-vous corbeillisés (ajout).
  Widget _listeCorbeille() {
    if (widget.corbeille.isEmpty) {
      return const Center(
        child: EtatVide(
          message: 'La corbeille est vide.',
          detail: 'Vos rendez-vous terminés mis à la corbeille '
              'apparaîtront ici.',
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: widget.corbeille.length,
      itemBuilder: (context, index) {
        final entree = widget.corbeille[index];
        return _carteCorbeille(
          entree.rdv,
          entree.corbeilleLe,
          premiere: index == 0,
          derniere: index == widget.corbeille.length - 1,
        );
      },
    );
  }

  /// Ligne de corbeille (style « filet », point 4) : identité du
  /// rendez-vous, mention de suppression, puis Restaurer / Supprimer
  /// (avec confirmation). Non cliquable : les actions de la corbeille
  /// sont ces deux boutons.
  Widget _carteCorbeille(
    RendezVous rdv,
    DateTime corbeilleLe, {
    required bool premiere,
    required bool derniere,
  }) {
    final motif = (rdv.motif ?? '').trim();
    return LigneFiletSpec(
      padding: const EdgeInsets.all(14),
      premiere: premiere,
      derniere: derniere,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarInitialesSpec(
                lettres: initiales(rdv.patientPrenom, rdv.patientNom),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rdv.patientNomComplet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: MaquetteCouleurs.texte,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${jourRelatif(rdv.date)} · ${rdv.heure}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: MaquetteCouleurs.texteSecondaire,
                      ),
                    ),
                    if (motif.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        motif,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: MaquetteCouleurs.texteSecondaire,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PastilleStatutSpec(
                statut: rdv.statut,
                nonTermine: widget.idsNonTermines.contains(rdv.id),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: MaquetteCouleurs.bordure),
          const SizedBox(height: 8),
          Text(
            _mentionCorbeille(rdv, corbeilleLe),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: rdv.statut == StatutRendezVous.termine
                  ? MaquetteCouleurs.texteSecondaire
                  : MaquetteCouleurs.refuseTexte,
            ),
          ),
          if (widget.onRestaurer != null ||
              widget.onSupprimerDefinitivement != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (widget.onRestaurer != null)
                  Expanded(
                    child: BoutonContourSpec(
                      texte: 'Restaurer',
                      couleur: MaquetteCouleurs.bleu,
                      hauteur: 44,
                      onPressed: () => widget.onRestaurer!(rdv),
                    ),
                  ),
                if (widget.onRestaurer != null &&
                    widget.onSupprimerDefinitivement != null)
                  const SizedBox(width: 10),
                if (widget.onSupprimerDefinitivement != null)
                  Expanded(
                    child: BoutonContourSpec(
                      texte: 'Supprimer',
                      couleur: MaquetteCouleurs.refuseTexte,
                      hauteur: 44,
                      onPressed: () => _confirmerSuppression(rdv),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
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

        // ── Segments : liste normale / corbeille (ajout) ──────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: MaquetteCouleurs.surface,
              borderRadius: BorderRadius.circular(MaquetteRayons.carte),
              border: Border.all(color: MaquetteCouleurs.bordure),
            ),
            child: Row(
              children: [
                _segment(
                  libelle: 'Rendez-vous',
                  actif: !_vueCorbeille,
                  onTap: () => _ouvrirVue(false),
                ),
                _segment(
                  libelle: 'Corbeille',
                  actif: _vueCorbeille,
                  onTap: () => _ouvrirVue(true),
                ),
              ],
            ),
          ),
        ),

        // ── Puces de période (pilules défilantes, actif = dégradé G) ─
        // Hauteur fixe : une ListView horizontale doit connaître sa hauteur.
        // Masquées en vue corbeille : la période ne s'applique qu'à la
        // liste normale.
        if (!_vueCorbeille)
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

        // ── Liste des rendez-vous groupés par date, ou corbeille ──
        // Expanded : la liste prend tout l'espace vertical restant.
        Expanded(
          child: _vueCorbeille
              ? _listeCorbeille()
              : rdvFiltres.isEmpty
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
                      for (var i = 0; i < groupes[jour]!.length; i++)
                        // Position dans le bloc de lignes réglées du
                        // groupe : rayons sur la 1ʳᵉ / dernière ligne.
                        CarteRdvListeSpec(
                          rdv: groupes[jour]![i],
                          nonTermine:
                              widget.idsNonTermines.contains(groupes[jour]![i].id),
                          premiere: i == 0,
                          derniere: i == groupes[jour]!.length - 1,
                          onTap: () => widget.onTapRendezVous(groupes[jour]![i]),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
