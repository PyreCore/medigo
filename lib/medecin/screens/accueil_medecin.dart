// ─────────────────────────────────────────────────────────────────────
// ACCUEIL MÉDECIN — tableau de bord « RDV du jour ».
// Reproduit la maquette §4.1 « Medigo Médecin et Secrétaire » :
//  1. en-tête : date en 13 px gris, « Bonjour, Dr X » 24 px w800,
//     bouton CLOCHE 44 px à droite (pastille rouge si notification) ;
//  2. bannière de notification dégradable, fermable, 6 s ;
//  3. zone HÉROS « Prochain rendez-vous » (dégradé G #2458D3→#28211A)
//     avec bouton d'action blanc — variante vide « Aucun rendez-vous
//     à venir » + « Voir le planning » quand rien n'est programmé ;
//  4. UNE bande de statistiques : chiffres grands #16203A séparés par
//     de fines lignes verticales, sans icône pastelle ni carte
//     individuelle (compteurs animés au chargement) ;
//  5. section « Rendez-vous d'aujourd'hui » + « Voir tout » ;
//  6. liste du jour (cartes à boîte horaire 56 x 56).
// Apparition progressive en fondu enchaîné (Apparition) : discret,
// jamais clignotant. La LOGIQUE (données + callbacks reçus du
// parent) est inchangée.
// ─────────────────────────────────────────────────────────────────────
import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/medecin.dart';
import '../../models/rendez_vous.dart';
import '../../theme/maquette_tokens.dart';
import '../../widgets/maquette_widgets.dart';
import '../../widgets/rendez_vous_card.dart'; // RepartitionStatuts (panneau PC)
import '../../widgets/ui_kit.dart'; // helpers : dateDuJour(), initiales()…

class AccueilMedecin extends StatefulWidget {
  final Medecin medecin;

  /// Photo à jour (peut changer après modification du profil).
  final String? photoUrl;

  final List<RendezVous> rendezVousDuJour;
  final int patientsSuivis;

  /// Ids des consultations marquées « non terminées » : les cartes
  /// affichent la pastille « Non terminé » (style neutre).
  final Set<String> idsNonTermines;

  /// Bannière « Nouveau rendez-vous » remontée par le chargeur
  /// (null = rien à afficher).
  final ({String titre, String sousTitre})? notificationRdv;

  /// Appelé quand l'utilisateur ferme la bannière (croix ou expiration).
  final VoidCallback? onFermerNotificationRdv;

  // Callbacks : ce widget n'a jamais accès à la navigation directement,
  // il appelle ces fonctions et laisse l'espace parent décider.
  final VoidCallback onVoirTout; // lien « Voir tout » → onglet Rendez-vous
  final VoidCallback onVoirPlanning; // (onglet Disponibilités, via nav)
  final ValueChanged<RendezVous> onTapRendezVous;
  final Future<void> Function()? onRafraichir;

  const AccueilMedecin({
    super.key,
    required this.medecin,
    this.photoUrl,
    required this.rendezVousDuJour,
    this.patientsSuivis = 0,
    this.idsNonTermines = const {},
    this.notificationRdv,
    this.onFermerNotificationRdv,
    required this.onVoirTout,
    required this.onVoirPlanning,
    required this.onTapRendezVous,
    this.onRafraichir,
  });

  @override
  State<AccueilMedecin> createState() => _AccueilMedecinState();
}

class _AccueilMedecinState extends State<AccueilMedecin> {
  // ── Bannière de notification (maquette §4.1) ────────────────────
  // Visible tant qu'elle n'est pas fermée (croix OU expiration 6 s).
  ({String titre, String sousTitre})? _banniere;
  Timer? _timerBanniere;

  @override
  void initState() {
    super.initState();
    _afficherBanniere(widget.notificationRdv);
  }

  @override
  void didUpdateWidget(covariant AccueilMedecin ancien) {
    super.didUpdateWidget(ancien);
    // Nouvelle notification reçue du chargeur (référence différente) :
    // on la (re)montre et on relance le minuteur d'expiration.
    if (widget.notificationRdv != null &&
        widget.notificationRdv != ancien.notificationRdv) {
      _afficherBanniere(widget.notificationRdv);
    }
  }

  void _afficherBanniere(({String titre, String sousTitre})? notif) {
    _timerBanniere?.cancel();
    if (notif == null) return;
    setState(() => _banniere = notif);
    // Durée « raisonnable » : la bannière se ferme toute seule après 6 s
    // (et peut être fermée plus tôt avec la croix).
    _timerBanniere = Timer(const Duration(seconds: 6), _fermerBanniere);
  }

  void _fermerBanniere() {
    _timerBanniere?.cancel();
    if (mounted) setState(() => _banniere = null);
    // On prévient aussi le chargeur : la pastille rouge de la cloche
    // disparaît tant qu'aucune nouvelle notification n'arrive.
    widget.onFermerNotificationRdv?.call();
  }

  @override
  void dispose() {
    _timerBanniere?.cancel();
    super.dispose();
  }

  /// Zone héros « Prochain rendez-vous » (dégradé G maquette
  /// #2458D3→#28211A), en haut du tableau de bord : le patient, en
  /// grand, est l'élément le plus visible de l'écran. Toute la carte
  /// ouvre le détail ; le bouton blanc redit l'action (cible 44 px).
  Widget _carteProchain(RendezVous prochain) {
    // Sous-titre : motif · spécialité (chacun toléré vide).
    final motif = (prochain.motif ?? '').trim();
    final specialite = widget.medecin.specialite.trim();
    final sousTitre = [
      if (motif.isNotEmpty) motif else 'Consultation',
      if (specialite.isNotEmpty) specialite,
    ].join(' · ');

    return GestureDetector(
      onTap: () => widget.onTapRendezVous(prochain),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: MaquetteDegrades.principal,
          borderRadius: BorderRadius.circular(MaquetteRayons.carteHaute),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne haute : libellé 13 px + pastille horaire blanche.
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Prochain rendez-vous',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD6E2FB),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(MaquetteRayons.pillule),
                  ),
                  child: Text(
                    prochain.heure,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: MaquetteCouleurs.bleu,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Nom du patient, en grand blanc (26 px w800).
            Text(
              prochain.patientNomComplet,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 26,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sousTitre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            // Bouton d'action : pilule blanche pleine largeur.
            _boutonHero(
              'Voir le détail',
              () => widget.onTapRendezVous(prochain),
            ),
          ],
        ),
      ),
    );
  }

  /// Variante « rien à venir » de la zone héros : un vrai message
  /// utile et un bouton d'action — jamais un vide ni un « 0 » seul.
  Widget _carteHeroVide() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: MaquetteDegrades.principal,
        borderRadius: BorderRadius.circular(MaquetteRayons.carteHaute),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prochain rendez-vous',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFD6E2FB),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Aucun rendez-vous à venir',
            style: TextStyle(
              fontSize: 24,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Vos patients peuvent prendre rendez-vous en ligne.\n'
            'Profitez-en pour consulter vos disponibilités.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          _boutonHero('Voir le planning', widget.onVoirPlanning),
        ],
      ),
    );
  }

  /// Bouton d'action d'une zone héros : pilule blanche, texte bleu,
  /// hauteur 44 px (cible tactile minimale de la maquette).
  Widget _boutonHero(String libelle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: maquetteCibleMin,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(MaquetteRayons.pillule),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              libelle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MaquetteCouleurs.bleu,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: MaquetteCouleurs.bleu,
            ),
          ],
        ),
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

    // Rendez-vous du JOUR (la section s'appelle « Rendez-vous
    // d'aujourd'hui » : on filtre sur la journée). La liste reçue ne
    // contient que des rendez-vous CONFIRMÉS et TERMINÉS (filtre fait
    // par le chargeur) : le compteur suit la même règle que la liste.
    final duJour = widget.rendezVousDuJour
        .where((r) => !r.date.isBefore(debutJour) && r.date.isBefore(finJour))
        .toList();

    // « À venir » : les prochains rendez-vous visibles (confirmés) à
    // venir. Remplace l'ancienne tuile « En attente » : le médecin ne
    // voit plus les rendez-vous en attente (arbitrage du point 3).
    final aVenir = widget.rendezVousDuJour
        .where((r) => r.dateHeure.isAfter(maintenant))
        .length;

    // Prochain rendez-vous CONFIRMÉ à venir ; à défaut, rien (les
    // rendez-vous en attente sont gérés par la secrétaire).
    RendezVous? prochain;
    for (final rdv in widget.rendezVousDuJour) {
      if (rdv.statut == StatutRendezVous.confirme &&
          rdv.dateHeure.isAfter(maintenant)) {
        prochain = rdv;
        break;
      }
    }

    // Liste des rendez-vous du jour (cartes maquette).
    final listeRdv = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EnTeteSectionSpec(
          titre: 'Rendez-vous d\'aujourd\'hui',
          action: 'Voir tout',
          onAction: widget.onVoirTout,
        ),
        const SizedBox(height: 8),
        if (duJour.isEmpty)
          const EtatVide(
            message: 'Aucun rendez-vous aujourd\'hui',
            detail: 'Profitez-en pour consulter vos disponibilités.',
          )
        else
          ...duJour.asMap().entries.map(
            (entree) => Apparition(
              delaiMs: 160 + (entree.key * 60),
              child: CarteRdvTableauSpec(
                rdv: entree.value,
                nonTermine:
                    widget.idsNonTermines.contains(entree.value.id),
                onTap: () => widget.onTapRendezVous(entree.value),
              ),
            ),
          ),
      ],
    );

    // Panneau latéral (≥ 900 px) : répartition du jour par statut.
    final panneau = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EnTeteSectionSpec(titre: 'Répartition du jour'),
        const SizedBox(height: 8),
        RepartitionStatuts(rdvs: duJour),
      ],
    );

    return RefreshIndicator(
      onRefresh: widget.onRafraichir ?? () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ── 1. En-tête : date 13 px, salutation 24 px, cloche ────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateDuJour(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: MaquetteCouleurs.texteSecondaire,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bonjour, ${widget.medecin.nomComplet}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: MaquetteTypo.titreEcran,
                        fontWeight: FontWeight.w800,
                        color: MaquetteCouleurs.texte,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Cloche : pastille rouge tant qu'une notification
              // n'a pas été fermée. Le clic ré-affiche la bannière.
              BoutonClocheSpec(
                avecPastille: widget.notificationRdv != null,
                onTap: () {
                  if (widget.notificationRdv != null) {
                    _afficherBanniere(widget.notificationRdv);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── 2. Bannière de notification (fermable, 6 s) ──────────
          if (_banniere != null) ...[
            BanniereNotificationSpec(
              titre: _banniere!.titre,
              sousTitre: _banniere!.sousTitre,
              onFermer: _fermerBanniere,
            ),
            const SizedBox(height: 12),
          ],

          // ── 3. Zone héros : prochain RDV (ou variante vide) ───────
          Apparition(
            delaiMs: 0,
            child: prochain != null
                ? _carteProchain(prochain)
                : _carteHeroVide(),
          ),
          const SizedBox(height: 16),

          // ── 4. Bande de statistiques : UNE bande, chiffres grands,
          // filets verticaux, compteurs animés ──────────────────────
          Apparition(
            delaiMs: 60,
            child: BandeStatsSpec(
              chiffres: [
                (valeur: duJour.length, libelle: 'RDV aujourd\'hui'),
                (valeur: aVenir, libelle: 'À venir'),
                (valeur: widget.patientsSuivis, libelle: 'Patients suivis'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 5. Liste + panneau responsive ────────────────────────
          LayoutBuilder(
            builder: (context, contraintes) {
              // Grand écran : liste + panneau côte à côte (seuil = rail).
              if (contraintes.maxWidth >= 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: listeRdv),
                    const SizedBox(width: 24),
                    Expanded(flex: 3, child: panneau),
                  ],
                );
              }
              // Petit écran : liste seule (le prochain RDV est déjà en haut).
              return listeRdv;
            },
          ),
        ],
      ),
    );
  }
}
