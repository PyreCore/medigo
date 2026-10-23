// ─────────────────────────────────────────────────────────────────────
// DÉTAIL D'UN RENDEZ-VOUS (MÉDECIN) — maquette §4.3.
//
//  · en-tête : bouton retour 44 px, titre 19 px, pastille de statut
//    (« Non terminé » en style neutre si le drapeau est posé) ;
//  · carte patient : avatar initiales 56 px, nom 18 px w800, motif 13,
//    puis lignes Date / Heure / Motif séparées par un trait ;
//  · carte « Informations du patient » : téléphone, date de naissance,
//    groupe sanguin, LUS DANS FIREBASE (MedecinService) avec
//    indicateur de chargement et gestion d'erreur ;
//  · si refusé : bloc « Motif du refus » (#FDE8E6) ;
//  · pied fixe selon le statut — le médecin n'a QUE deux actions,
//    sur un rendez-vous CONFIRMÉ dont l'heure est passée ou en cours :
//    « Terminer » / « Non terminé » (chaque action passe par une
//    boîte de confirmation, puis un message de succès) ;
//  · la CONFIRMATION (acceptation) et le refus appartiennent à la
//    secrétaire : aucun bouton « Confirmer » ici.
// La LOGIQUE (callbacks reçus du parent) est inchangée.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../models/rendez_vous.dart';
import '../../services/medecin_service.dart';
import '../../theme/maquette_tokens.dart';
import '../../widgets/maquette_widgets.dart';
import '../../widgets/ui_kit.dart'; // dateDuJour(), initiales()

class DetailRendezVousMedecin extends StatefulWidget {
  final RendezVous rdv;

  /// Spécialité du médecin connecté (sous-titre de la carte patient).
  final String? specialiteMedecin;

  /// Passe le rendez-vous au statut « terminé » (bouton du pied).
  final Future<void> Function()? onTerminer;

  /// Marque la consultation comme NON terminée (statut « terminé » +
  /// drapeau consultationTerminee = false côté service).
  final Future<void> Function()? onNonTermine;

  /// Vrai si ce rendez-vous est déjà marqué « non terminé » : le pied
  /// affiche alors un bloc neutre « Consultation non terminée ».
  final bool consultationNonTerminee;

  const DetailRendezVousMedecin({
    super.key,
    required this.rdv,
    this.specialiteMedecin,
    this.onTerminer,
    this.onNonTermine,
    this.consultationNonTerminee = false,
  });

  @override
  State<DetailRendezVousMedecin> createState() =>
      _DetailRendezVousMedecinState();
}

class _DetailRendezVousMedecinState extends State<DetailRendezVousMedecin> {
  // Service créé LAZY (à la première utilisation) : l'instanciation
  // immédiate casserait les tests widget sans Firebase initialisé, car
  // le constructeur de MedecinService accède à FirebaseFirestore.instance.
  MedecinService? _service;
  MedecinService get service => _service ??= MedecinService();

  // Informations patient (téléphone / naissance / groupe sanguin),
  // lues dans Firestore à l'ouverture de l'écran.
  ({String? telephone, DateTime? dateNaissance, String? groupeSanguin})?
      _infosPatient;
  bool _chargementInfos = true;
  bool _erreurInfos = false;

  @override
  void initState() {
    super.initState();
    _chargerInfosPatient();
  }

  Future<void> _chargerInfosPatient() async {
    setState(() {
      _chargementInfos = true;
      _erreurInfos = false;
    });
    try {
      final infos = await service.getInfosPatientRendezVous(widget.rdv.id);
      if (!mounted) return;
      setState(() {
        _infosPatient = infos;
        _chargementInfos = false;
      });
    } catch (_) {
      // Erreur réseau / règles Firestore : on n'affiche jamais de crash,
      // on retombe sur « Non renseigné » avec une possibilité de réessayer.
      if (!mounted) return;
      setState(() {
        _chargementInfos = false;
        _erreurInfos = true;
      });
    }
  }

  // Affiche « Non renseigné » seulement quand la donnée est ABSENTE de
  // Firestore (jamais en dur quand elle existe).
  String _ouNonRenseigne(String? valeur) =>
      (valeur == null || valeur.trim().isEmpty) ? 'Non renseigné' : valeur;

  // ── Carte patient (blanche, maquette §4.3) ──────────────────────
  Widget _cartePatient(String dateLongue) {
    final motif = (widget.rdv.motif ?? '').trim();
    final specialite = (widget.specialiteMedecin ?? '').trim();
    final sousTitre = [
      if (motif.isNotEmpty) motif else 'Consultation',
      if (specialite.isNotEmpty) specialite,
    ].join(' · ');

    return CarteSpec(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarInitialesSpec(
                lettres: initiales(
                  widget.rdv.patientPrenom,
                  widget.rdv.patientNom,
                ),
                rayon: 28, // 56 px de large (maquette)
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.rdv.patientNomComplet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: MaquetteCouleurs.texte,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sousTitre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: MaquetteCouleurs.texteSecondaire,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Lignes « libellé …… valeur », séparées par un trait.
          _LigneDetail(libelle: 'Date', valeur: dateLongue),
          _LigneDetail(libelle: 'Heure', valeur: widget.rdv.heure),
          if (motif.isNotEmpty)
            _LigneDetail(libelle: 'Motif', valeur: widget.rdv.motif!),
        ],
      ),
    );
  }

  // ── Bandeau « Motif du refus » (#FDE8E6) ────────────────────────
  Widget _bandeauRefus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MaquetteCouleurs.refuseFond,
        borderRadius: BorderRadius.circular(MaquetteRayons.carte),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Motif du refus',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: MaquetteCouleurs.refuseTexte,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.rdv.motifRefus ?? '',
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: MaquetteCouleurs.texte,
            ),
          ),
        ],
      ),
    );
  }

  // ── Carte « Informations du patient » (données Firestore) ───────
  Widget _infosPatientCarte() {
    return CarteSpec(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations du patient',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: MaquetteCouleurs.texte,
            ),
          ),
          const SizedBox(height: 2),
          if (_chargementInfos)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: MaquetteCouleurs.bleu,
                  ),
                ),
              ),
            )
          else ...[
            _LignePatient(
              icone: Icons.phone_outlined,
              fond: MaquetteCouleurs.bleuClair,
              couleur: MaquetteCouleurs.bleu,
              libelle: 'Téléphone',
              valeur: _ouNonRenseigne(_infosPatient?.telephone),
            ),
            _LignePatient(
              icone: Icons.calendar_month_outlined,
              fond: MaquetteCouleurs.bleuClair,
              couleur: MaquetteCouleurs.bleu,
              libelle: 'Date de naissance',
              valeur: _infosPatient?.dateNaissance == null
                  ? 'Non renseigné'
                  : '${dateDuJour(_infosPatient!.dateNaissance)} '
                        '${_infosPatient!.dateNaissance!.year}',
            ),
            _LignePatient(
              icone: Icons.bloodtype_outlined,
              fond: MaquetteCouleurs.refuseFond,
              couleur: MaquetteCouleurs.refuseTexte,
              libelle: 'Groupe sanguin',
              valeur: _ouNonRenseigne(_infosPatient?.groupeSanguin),
            ),
            if (_erreurInfos)
              TextButton(
                onPressed: _chargerInfosPatient,
                child: const Text(
                  'Infos indisponibles — Réessayer',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ── Pied fixe : actions selon le statut (maquette §4.3) ─────────
  // Le médecin n'a que DEUX actions, et seulement sur un rendez-vous
  // CONFIRMÉ dont l'heure est passée ou en cours : Terminer / Non
  // terminé. La confirmation (acceptation) et le refus sont gérés par
  // la secrétaire — aucun bouton « Confirmer » ici.
  Widget _piedActions() {
    switch (widget.rdv.statut) {
      case StatutRendezVous.enAttente:
        // Confirmation par la secrétaire : pas d'action côté médecin.
        return const BlocEtatSpec(
          texte: 'En attente de confirmation par la secrétaire',
          fond: MaquetteCouleurs.attenteFond,
          couleurTexte: MaquetteCouleurs.attenteTexte,
        );
      case StatutRendezVous.confirme:
        // Actions disponibles UNIQUEMENT une fois l'heure passée ou
        // la consultation en cours ; avant, simple information.
        if (widget.rdv.dateHeure.isAfter(DateTime.now())) {
          return BlocEtatSpec(
            texte: 'Consultation prévue à ${widget.rdv.heure}',
            fond: MaquetteCouleurs.bleuClair,
            couleurTexte: MaquetteCouleurs.bleu,
          );
        }
        return Row(
          children: [
            Expanded(
              child: BoutonContourSpec(
                texte: 'Non terminé',
                couleur: MaquetteCouleurs.texteSecondaire,
                onPressed: widget.onNonTermine == null
                    ? null
                    : _marquerNonTermineeAvecConfirmation,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BoutonDegradeSpec(
                texte: 'Terminer',
                icone: Icons.check_rounded,
                onPressed: widget.onTerminer == null
                    ? null
                    : _terminerAvecConfirmation,
              ),
            ),
          ],
        );
      case StatutRendezVous.termine:
        // Consultation marquée « non terminée » : bloc neutre orange,
        // distinct du gris « Consultation terminée ».
        return widget.consultationNonTerminee
            ? const BlocEtatSpec(
                texte: 'Consultation non terminée',
                fond: MaquetteCouleurs.attenteFond,
                couleurTexte: MaquetteCouleurs.attenteTexte,
              )
            : const BlocEtatSpec(
                texte: 'Consultation terminée',
                fond: MaquetteCouleurs.termineFond,
                couleurTexte: MaquetteCouleurs.termineTexte,
              );
      case StatutRendezVous.refuse:
      case StatutRendezVous.annule:
        return const BlocEtatSpec(
          texte: 'Rendez-vous refusé',
          fond: MaquetteCouleurs.refuseFond,
          couleurTexte: MaquetteCouleurs.refuseTexte,
        );
    }
  }

  // ── Boîte de confirmation avant d'enregistrer (maquette) ────────
  // Annuler → rien n'est écrit ; l'action demandée → le callback du
  // parent (Firestore) est appelé, puis un message de succès s'affiche
  // (publié par le chargeur après le rechargement).
  Future<bool> _demanderConfirmation({
    required String titre,
    required String message,
    required String action,
  }) async {
    final resultat = await showDialog<bool>(
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
              Text(
                titre,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MaquetteCouleurs.texte,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
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
                    child: BoutonDegradeSpec(
                      texte: action,
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
    return resultat ?? false;
  }

  Future<void> _terminerAvecConfirmation() async {
    final confirme = await _demanderConfirmation(
      titre: 'Terminer la consultation ?',
      message: 'Le rendez-vous passera au statut « Terminé ».',
      action: 'Terminer',
    );
    if (!confirme || !mounted) return;
    // Navigator capturé avant l'appel asynchrone (lint).
    final navigator = Navigator.of(context);
    await widget.onTerminer!();
    if (mounted) navigator.pop();
  }

  Future<void> _marquerNonTermineeAvecConfirmation() async {
    final confirme = await _demanderConfirmation(
      titre: 'Marquer comme non terminée ?',
      message: 'La consultation sera enregistrée comme non terminée '
          'dans votre suivi.',
      action: 'Non terminé',
    );
    if (!confirme || !mounted) return;
    final navigator = Navigator.of(context);
    await widget.onNonTermine!();
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Date longue en français + année, ex : « Jeudi 15 octobre 2026 ».
    final dateLongue =
        '${dateDuJour(widget.rdv.date)} ${widget.rdv.date.year}';

    // Pas d'AppBar Material : on construit l'en-tête de la maquette
    // (chevron de retour + titre + badge de statut) nous-mêmes.
    return Scaffold(
      backgroundColor: MaquetteCouleurs.fond,
      body: SafeArea(
        child: Column(
          children: [
            // ── En-tête : retour + titre + badge statut ──────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 20, 4),
              child: Row(
                children: [
                  SizedBox(
                    width: maquetteCibleMin,
                    height: maquetteCibleMin,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.chevron_left,
                        size: 28,
                        color: MaquetteCouleurs.texte,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Expanded(
                    child: Text(
                      'Détail du rendez-vous',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: MaquetteCouleurs.texte,
                      ),
                    ),
                  ),
                  PastilleStatutSpec(
                    statut: widget.rdv.statut,
                    nonTermine: widget.consultationNonTerminee,
                  ),
                ],
              ),
            ),

            // ── Contenu défilant ──────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  _cartePatient(dateLongue),
                  if (widget.rdv.statut == StatutRendezVous.refuse &&
                      widget.rdv.motifRefus != null &&
                      widget.rdv.motifRefus!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _bandeauRefus(),
                  ],
                  const SizedBox(height: 16),
                  _infosPatientCarte(),
                ],
              ),
            ),

            // ── Pied de boutons fixe (tous statuts, cf. maquette) ─────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(
                color: MaquetteCouleurs.surface,
                border: Border(top: BorderSide(color: MaquetteCouleurs.bordure)),
              ),
              child: _piedActions(),
            ),
          ],
        ),
      ),
    );
  }
}

// Ligne « libellé …… valeur » de la carte patient, précédée d'un trait.
class _LigneDetail extends StatelessWidget {
  final String libelle;
  final String valeur;

  const _LigneDetail({required this.libelle, required this.valeur});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 1),
        Container(height: 1, color: MaquetteCouleurs.bordure),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                libelle,
                style: const TextStyle(
                  fontSize: 13,
                  color: MaquetteCouleurs.texteSecondaire,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  valeur,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MaquetteCouleurs.texte,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Ligne « pastille icône 36 px + libellé + valeur » de la carte
// « Informations du patient », séparée par un filet.
class _LignePatient extends StatelessWidget {
  final IconData icone;
  final Color fond;
  final Color couleur;
  final String libelle;
  final String valeur;

  const _LignePatient({
    required this.icone,
    required this.fond,
    required this.couleur,
    required this.libelle,
    required this.valeur,
  });

  @override
  Widget build(BuildContext context) {
    final nonRenseigne = valeur == 'Non renseigné';
    return Column(
      children: [
        Container(height: 1, color: MaquetteCouleurs.bordure),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: fond, shape: BoxShape.circle),
                child: Icon(icone, size: 18, color: couleur),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      libelle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: MaquetteCouleurs.texteSecondaire,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      valeur,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: nonRenseigne
                            ? MaquetteCouleurs.texteSecondaire
                            : MaquetteCouleurs.texte,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
