import 'package:flutter/material.dart';
import '../../models/rendez_vous.dart';
import '../../theme/medigo_theme.dart';
import '../../widgets/maquette_widgets.dart'; // LigneFiletSpec (filet)
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

  /// (AJOUT) Contenu de la corbeille : rendez-vous + date de mise à la
  /// corbeille (record structurel, cf. SecretaireService.getCorbeille).
  final List<({RendezVous rdv, DateTime corbeilleLe})> corbeille;

  /// (AJOUT) Appelé à l'ouverture de l'onglet Corbeille : purge les
  /// documents de plus de 30 jours puis recharge la liste.
  final Future<void> Function()? onOuvrirCorbeille;

  /// (AJOUT) Remet un rendez-vous corbeillé dans les listes normales.
  final Future<void> Function(RendezVous rdv)? onRestaurer;

  /// (AJOUT) Suppression définitive : la confirmation est demandée
  /// DANS l'écran (_confirmerSuppression) avant d'appeler ce callback.
  final Future<void> Function(RendezVous rdv)? onSupprimerDefinitivement;

  const ListeRendezVousSecretaire({
    super.key,
    required this.rendezVous,
    required this.onNouveauRendezVous,
    this.onTapRendezVous,
    this.corbeille = const [],
    this.onOuvrirCorbeille,
    this.onRestaurer,
    this.onSupprimerDefinitivement,
  });

  @override
  State<ListeRendezVousSecretaire> createState() =>
      _ListeRendezVousSecretaireState();
}

class _ListeRendezVousSecretaireState
    extends State<ListeRendezVousSecretaire> {
  // "null" = aucun filtre actif : on affiche tout.
  StatutRendezVous? _filtreActif;

  // (AJOUT) false = vue « Rendez-vous » (liste normale), true = vue
  // « Corbeille ». Un segment sous le titre bascule entre les deux.
  bool _vueCorbeille = false;

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

  /// Ligne de liste en style « filet » (point 4) : le même contenu que
  /// CarteRdvListe (avatar à initiales, nom, « jour · heure »,
  /// sous-titre, pastille de statut) mais SANS carte individuelle —
  /// les lignes sont collées et séparées par un trait 1 px.
  Widget _ligneFilet(
    RendezVous rdv, {
    required String sousTitre,
    required bool premiere,
    required bool derniere,
    VoidCallback? onTap,
  }) {
    return LigneFiletSpec(
      padding: const EdgeInsets.all(14),
      premiere: premiere,
      derniere: derniere,
      onTap: onTap,
      child: Row(
        children: [
          AvatarInitiales(
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
                    fontWeight: FontWeight.w800,
                    color: AppColors.texte,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${jourRelatif(rdv.date)} · ${rdv.heure}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.texteFaible,
                  ),
                ),
                if (sousTitre.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sousTitre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.texteFaible,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          PastilleStatut(statut: rdv.statut),
        ],
      ),
    );
  }

  // ── Vue « Corbeille » (ajout) ─────────────────────────────────────

  /// Bascule entre la liste normale et la corbeille. L'ouverture de la
  /// corbeille déclenche la purge des documents de plus de 30 jours
  /// (callback → chargeur → SecretaireService.purgerCorbeille).
  void _ouvrirVue(bool corbeille) {
    if (_vueCorbeille == corbeille) return;
    setState(() => _vueCorbeille = corbeille);
    if (corbeille) widget.onOuvrirCorbeille?.call();
  }

  /// Mention d'une ligne de corbeille : compte à rebours pour les
  /// annulés / refusés (purgés à 30 jours à l'ouverture), mention
  /// honnête pour les terminés (jamais purgés : historique patient et
  /// éligibilité aux avis).
  static String _mentionCorbeille(RendezVous rdv, DateTime corbeilleLe) {
    if (rdv.statut == StatutRendezVous.termine) return 'Conservé — historique';
    final jours = 30 - DateTime.now().difference(corbeilleLe).inDays;
    // Plancher à 1 : la purge a lieu à l'ouverture de l'onglet, la ligne
    // ne devrait jamais afficher 0 ni une valeur négative.
    return jours <= 1
        ? 'Suppression dans 1 jour'
        : 'Suppression dans $jours jours';
  }

  /// Confirmation OBLIGATOIRE avant la suppression définitive (aucune
  /// action irréversible sans boîte de dialogue).
  Future<void> _confirmerSuppression(RendezVous rdv) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rayons.carte),
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
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Le rendez-vous de ${rdv.patientNomComplet} sera supprimé '
                'de façon définitive. Cette action est irréversible.',
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppColors.texte,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: BoutonContour(
                      texte: 'Annuler',
                      couleur: AppColors.texteFaible,
                      hauteur: 48,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BoutonContour(
                      texte: 'Supprimer',
                      couleur: AppColors.rouge,
                      hauteur: 48,
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

  /// Segment « Rendez-vous / Corbeille » : conteneur blanc à deux
  /// parts, la part active passe en bleu vif.
  Widget _segment({
    required String libelle,
    required bool actif,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: actif ? AppColors.bleuVif : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            libelle,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: actif ? Colors.white : AppColors.texteFaible,
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
          detail: 'Les rendez-vous terminés, annulés ou refusés que vous '
              'mettez à la corbeille apparaîtront ici.',
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
    final medecin = (rdv.medecinNom ?? '').trim();
    final motif = (rdv.motif ?? '').trim();
    final sousTitre = [
      if (medecin.isNotEmpty) medecin,
      if (motif.isNotEmpty) motif,
    ].join(' · ');

    return LigneFiletSpec(
      padding: const EdgeInsets.all(14),
      premiere: premiere,
      derniere: derniere,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarInitiales(
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
                        fontWeight: FontWeight.w800,
                        color: AppColors.texte,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${jourRelatif(rdv.date)} · ${rdv.heure}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.texteFaible,
                      ),
                    ),
                    if (sousTitre.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        sousTitre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.texteFaible,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PastilleStatut(statut: rdv.statut),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: AppColors.trait),
          const SizedBox(height: 8),
          Text(
            _mentionCorbeille(rdv, corbeilleLe),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: rdv.statut == StatutRendezVous.termine
                  ? AppColors.texteFaible
                  : AppColors.rouge,
            ),
          ),
          if (widget.onRestaurer != null ||
              widget.onSupprimerDefinitivement != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (widget.onRestaurer != null)
                  Expanded(
                    child: BoutonContour(
                      texte: 'Restaurer',
                      couleur: AppColors.bleuVif,
                      hauteur: 44,
                      onPressed: () => widget.onRestaurer!(rdv),
                    ),
                  ),
                if (widget.onRestaurer != null &&
                    widget.onSupprimerDefinitivement != null)
                  const SizedBox(width: 10),
                if (widget.onSupprimerDefinitivement != null)
                  Expanded(
                    child: BoutonContour(
                      texte: 'Supprimer',
                      couleur: AppColors.rouge,
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

            // ── Segments : liste normale / corbeille (ajout) ──────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.trait),
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

            // ── Pilules de filtre (défilables, vue liste seule) ────
            if (!_vueCorbeille)
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

            // ── Liste des rendez-vous, ou de la corbeille ──────────
            Expanded(
              child: _vueCorbeille
                  ? _listeCorbeille()
                  : rdvFiltres.isEmpty
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
                            return _ligneFilet(
                              rdv,
                              sousTitre: _ligneMedecin(rdv),
                              premiere: index == 0,
                              derniere: index == rdvFiltres.length - 1,
                              onTap: widget.onTapRendezVous == null
                                  ? null
                                  : () => widget.onTapRendezVous!(rdv),
                            );
                          },
                        ),
            ),
          ],
        ),
        // ── Bouton flottant « Nouveau rendez-vous » (masqué en ────
        // corbeille : on n'programme pas depuis la corbeille).
        if (!_vueCorbeille)
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
