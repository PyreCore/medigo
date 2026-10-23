// ─────────────────────────────────────────────────────────────────────
// HORAIRES DES MÉDECINS — écran propre à la secrétaire.
//
// La secrétaire gère les plages horaires de TOUS les médecins de son
// hôpital (pas seulement les siens, contrairement au médecin qui ne
// voit que les siennes en lecture seule — voir DisponibilitesMedecin).
//
// Ce qu'elle peut faire, médecin par médecin :
//  · AJOUTER une plage (ex: mardi 08:00 → 16:00) ;
//  · MODIFIER une plage existante ;
//  · SUPPRIMER une plage ;
//  · VALIDER (activer / désactiver) un créneau sans le supprimer.
//
// La VALIDATION est le vrai pouvoir de la secrétaire : elle peut
// « fermer » un créneau (ex: le médecin ne consulte pas l'après-midi)
// tout en le conservant — le réactiver plus tard est un simple clic,
// et aucun rendez-vous déjà pris n'est perdu.
//
// Interface 100 % texte (aucune icône) : parti pris visuel de Medigo.
// ─────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../models/medecin.dart';
import '../../models/disponibilite.dart';
import '../../services/disponibilite_service.dart';
import '../../theme/medigo_theme.dart';
import '../../theme/maquette_tokens.dart';
import '../../widgets/ui_kit.dart';

class HorairesMedecinsSecretaire extends StatefulWidget {
  /// Les médecins de l'HÔPITAL de la secrétaire (liste déjà filtrée
  /// par le chargeur d'écran : elle ne voit que son établissement).
  final List<Medecin> medecins;

  const HorairesMedecinsSecretaire({super.key, required this.medecins});

  @override
  State<HorairesMedecinsSecretaire> createState() =>
      _HorairesMedecinsSecretaireState();
}

class _HorairesMedecinsSecretaireState
    extends State<HorairesMedecinsSecretaire> {
  final _service = DisponibiliteService();

  // Médecin actuellement sélectionné (null = aucun encore choisi).
  Medecin? _medecinChoisi;

  // Plages horaires du médecin sélectionné (actives ET inactives).
  List<Disponibilite> _plages = [];

  bool _chargement = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    // Par défaut, on sélectionne le premier médecin de la liste :
    // l'écran n'est jamais vide, la secrétaire voit tout de suite des
    // horaires (ou un état vide explicite).
    if (widget.medecins.isNotEmpty) {
      _medecinChoisi = widget.medecins.first;
      _charger();
    }
  }

  /// Charge les plages du médecin sélectionné dans Firestore.
  Future<void> _charger() async {
    final medecin = _medecinChoisi;
    if (medecin == null) return;

    setState(() {
      _chargement = true;
      _erreur = null;
    });

    try {
      final plages = await _service.getDisponibilites(medecin.id);
      if (!mounted) return;
      setState(() {
        _plages = plages;
        _chargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = 'Impossible de charger les horaires de ce médecin.';
      });
    }
  }

  /// Ajoute une nouvelle plage pour [jour] (1 = lundi … 7 = dimanche).
  Future<void> _ajouter(int jour) async {
    final medecin = _medecinChoisi;
    if (medecin == null) return;

    final plage = await _demanderPlage(
      context,
      jour: jour,
      // L'écriture Firestore se fait DANS la boîte de dialogue : elle
      // y affiche son spinner et y conserve l'erreur si ça échoue.
      onEnregistrer: (p) => _service.enregistrer(
        Disponibilite(
          id: '',
          medecinId: medecin.id,
          jour: jour,
          heureDebut: p.debut,
          heureFin: p.fin,
        ),
      ),
    );
    if (plage == null || !mounted) return;

    await _charger();
    // Retour visuel : petit message de succès en bas de l'écran.
    _flash('Plage ajoutée — ${Disponibilite.nomJour(jour)}');
  }

  /// Boîte de dialogue de saisie d'une plage (pré-remplie si modification).
  ///
  /// L'ENREGISTREMENT se fait DANS la boîte ([onEnregistrer]) : elle
  /// affiche son spinner pendant l'écriture Firestore et conserve
  /// l'erreur si ça échoue. Renvoie null si l'utilisateur annule.
  Future<_Plage?> _demanderPlage(
    BuildContext context, {
    required int jour,
    required Future<void> Function(_Plage plage) onEnregistrer,
    _Plage? existante,
  }) async {
    final resultat = await showDialog<_Plage>(
      context: context,
      builder: (_) => _DialoguePlage(
        titre: existante == null
            ? 'Ajouter — ${Disponibilite.nomJour(jour)}'
            : 'Modifier — ${Disponibilite.nomJour(jour)}',
        existante: existante,
        onEnregistrer: onEnregistrer,
      ),
    );
    if (resultat == null) return null;

    // Garde de sécurité : la règle « fin > début » est déjà validée EN
    // DIRECT dans la boîte (bouton « Valider » désactivé), mais on
    // revérifie ici, juste avant l'appel du service. Les textes viennent
    // de _versTexte ("HH:mm" zéro en tête) : l'ordre alphabétique =
    // l'ordre horaire ("09:00" < "10:00").
    if (resultat.debut.compareTo(resultat.fin) >= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('L\'heure de fin doit être après l\'heure de début'),
          ),
        );
      }
      return null;
    }
    return resultat;
  }

  Future<void> _modifier(Disponibilite plage) async {
    final nouvelle = await _demanderPlage(
      context,
      jour: plage.jour,
      existante: _Plage(debut: plage.heureDebut, fin: plage.heureFin),
      // L'écriture Firestore se fait DANS la boîte de dialogue.
      onEnregistrer: (p) => _service.enregistrer(
        Disponibilite(
          id: plage.id,
          medecinId: plage.medecinId,
          jour: plage.jour,
          heureDebut: p.debut,
          heureFin: p.fin,
          actif: plage.actif,
        ),
      ),
    );
    if (nouvelle == null || !mounted) return;

    await _charger();
    _flash('Plage modifiée — ${Disponibilite.nomJour(plage.jour)}');
  }

  Future<void> _supprimer(Disponibilite plage) async {
    await _service.supprimer(plage.id);
    if (!mounted) return;
    await _charger();
    _flash('Plage supprimée — ${Disponibilite.nomJour(plage.jour)}');
  }

  /// VALIDATION d'un créneau : active ou désactive la plage sans la
  /// supprimer. Une plage désactivée n'est plus proposée aux patients
  /// qui réservent, mais reste visible ici pour pouvoir la réactiver.
  Future<void> _basculer(Disponibilite plage) async {
    await _service.enregistrer(
      Disponibilite(
        id: plage.id,
        medecinId: plage.medecinId,
        jour: plage.jour,
        heureDebut: plage.heureDebut,
        heureFin: plage.heureFin,
        actif: !plage.actif,
      ),
    );
    if (!mounted) return;
    await _charger();
    _flash(
      '${plage.actif ? 'Créneau désactivé' : 'Créneau activé'} — '
      '${Disponibilite.nomJour(plage.jour)}',
    );
  }

  /// Petit retour de succès en bas d'écran (flottant, bleu maquette).
  void _flash(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: MaquetteCouleurs.bleu,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Entrée en fondu + glissement d'une carte de jour, décalée par
  /// index (stagger lundi → dimanche). La colonne parente porte une
  /// clé ValueKey(médecin) : changer de médecin reconstruit les cartes
  /// et REJOUE cette entrée.
  Widget _animeCarte(int index, Widget enfant) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Interval(
        0.08 * index,
        // Borné à 1 : Interval exige end <= 1 (dernière carte).
        (0.08 * index + 0.6).clamp(0.0, 1.0).toDouble(),
        curve: Curves.easeOutCubic,
      ),
      builder: (context, valeur, enfant) => Opacity(
        opacity: valeur.clamp(0.0, 1.0).toDouble(),
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - valeur)),
          child: enfant,
        ),
      ),
      child: enfant,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Aucun médecin dans l'hôpital : état vide explicite.
    if (widget.medecins.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          EtatVide(
            message: 'Aucun médecin dans votre hôpital',
            detail:
                'Enregistrez d\'abord un compte médecin pour gérer ses horaires.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Titre + sous-titre ────────────────────────────────────
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Horaires des médecins',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Gérez les plages de consultation de votre hôpital',
                style: TextStyle(fontSize: 14, color: AppColors.texteFaible),
              ),
            ],
          ),
        ),

        // ── Sélecteur de médecin (pilules de texte, sans icône) ────
        const Text(
          'Choisir un médecin',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.texte,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.medecins.map((medecin) {
            final selectionne = medecin.id == _medecinChoisi?.id;
            return _PiluleMedecin(
              libelle: medecin.nomComplet,
              selectionnee: selectionne,
              onTap: () {
                // Changer de médecin = recharger ses plages.
                setState(() => _medecinChoisi = medecin);
                _charger();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // ── Bandeau explicatif (la secrétaire a la main) ───────────
        CarteMedigo(
          padding: const EdgeInsets.all(14),
          child: Text(
            'Vous gérez les horaires des médecins de votre hôpital. '
            'Une plage désactivée n\'est plus proposée aux patients '
            'mais reste conservée : vous pouvez la réactiver à tout moment.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AppColors.texteFaible,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Plages du médecin sélectionné ──────────────────────────
        if (_chargement)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_erreur != null)
          CarteMedigo(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(
                  _erreur!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.texte),
                ),
                const SizedBox(height: 12),
                BoutonContour(texte: 'Réessayer', onPressed: _charger),
              ],
            ),
          )
        else
          Column(
            // Clé = médecin : changer de médecin reconstruit la
            // colonne et rejoue l'entrée fondu + glissement des cartes.
            key: ValueKey(_medecinChoisi?.id),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int jour = 1; jour <= 7; jour++)
                _animeCarte(
                  jour - 1,
                  _CarteJour(
                    jour: jour,
                    plages: _plages.where((p) => p.jour == jour).toList(),
                    onAjouter: () => _ajouter(jour),
                    onModifier: _modifier,
                    onSupprimer: _supprimer,
                    onBasculer: _basculer,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Pilule de sélection d'un médecin (texte seul, pastille bleue quand
/// sélectionné — même vocabulaire visuel que la barre de navigation).
class _PiluleMedecin extends StatelessWidget {
  final String libelle;
  final bool selectionnee;
  final VoidCallback onTap;

  const _PiluleMedecin({
    required this.libelle,
    required this.selectionnee,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Rayons.pillule),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color:
              selectionnee ? AppColors.bleuVif : AppColors.surface,
          borderRadius: BorderRadius.circular(Rayons.pillule),
          border: Border.all(
            color:
                selectionnee ? AppColors.bleuVif : AppColors.trait,
          ),
        ),
        child: Text(
          'Dr $libelle',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selectionnee ? Colors.white : AppColors.texteFaible,
          ),
        ),
      ),
    );
  }
}

/// Carte d'un jour : ses plages horaires, avec les 4 actions de la
/// secrétaire (ajouter / modifier / supprimer / valider).
class _CarteJour extends StatelessWidget {
  final int jour;
  final List<Disponibilite> plages;
  final VoidCallback onAjouter;
  final Future<void> Function(Disponibilite) onModifier;
  final Future<void> Function(Disponibilite) onSupprimer;
  final Future<void> Function(Disponibilite) onBasculer;

  const _CarteJour({
    required this.jour,
    required this.plages,
    required this.onAjouter,
    required this.onModifier,
    required this.onSupprimer,
    required this.onBasculer,
  });

  @override
  Widget build(BuildContext context) {
    return CarteMedigo(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre du jour + bouton « Ajouter » (texte seul).
          Row(
            children: [
              Expanded(
                child: Text(
                  Disponibilite.nomJour(jour),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.texte,
                  ),
                ),
              ),
              TextButton(
                onPressed: onAjouter,
                child: const Text('Ajouter'),
              ),
            ],
          ),
          if (plages.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Aucune plage — ce jour est fermé',
                style: TextStyle(fontSize: 13, color: AppColors.texteFaible),
              ),
            )
          else
            ...plages.map(
              (plage) => _LignePlage(
                plage: plage,
                onModifier: () => onModifier(plage),
                onSupprimer: () => onSupprimer(plage),
                onBasculer: () => onBasculer(plage),
              ),
            ),
        ],
      ),
    );
  }
}

/// Une plage horaire avec ses trois actions (valider / modifier /
/// supprimer). La plage désactivée est grisée et barrée pour qu'on
/// comprenne d'un coup d'œil qu'elle ne propose plus de créneau.
class _LignePlage extends StatelessWidget {
  final Disponibilite plage;
  final VoidCallback onModifier;
  final VoidCallback onSupprimer;
  final VoidCallback onBasculer;

  const _LignePlage({
    required this.plage,
    required this.onModifier,
    required this.onSupprimer,
    required this.onBasculer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Heure de la plage (grisée + barrée si inactive).
          // maxLines/ellipsis : si les trois actions à droite prennent
          // trop de place (petit écran), l'heure est coupée proprement.
          Expanded(
            child: Text(
              plage.libelle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: plage.actif ? AppColors.texte : AppColors.texteFaible,
                decoration: plage.actif ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
          // VALIDER : le texte du bouton change selon l'état, pour que
          // la secrétaire voie toujours ce que le clic fera.
          _ActionTexte(
            libelle: plage.actif ? 'Désactiver' : 'Activer',
            couleur: plage.actif ? AppColors.ambre : AppColors.vertSante,
            onTap: onBasculer,
          ),
          const SizedBox(width: 4),
          _ActionTexte(
            libelle: 'Modifier',
            couleur: AppColors.bleuVif,
            onTap: onModifier,
          ),
          const SizedBox(width: 4),
          _ActionTexte(
            libelle: 'Supprimer',
            couleur: AppColors.rouge,
            onTap: onSupprimer,
          ),
        ],
      ),
    );
  }
}

/// Bouton d'action en texte seul (aucune icône — parti pris Medigo).
class _ActionTexte extends StatelessWidget {
  final String libelle;
  final Color couleur;
  final VoidCallback onTap;

  const _ActionTexte({
    required this.libelle,
    required this.couleur,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          libelle,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: couleur,
          ),
        ),
      ),
    );
  }
}

/// Plage saisie dans la boîte de dialogue, avant enregistrement.
class _Plage {
  final String debut;
  final String fin;

  const _Plage({required this.debut, required this.fin});
}

// ─────────────────────────────────────────────────────────────────────
// Boîte de dialogue « Ajouter / Modifier une plage » — maquette :
//  · validation EN DIRECT : « La fin doit être après le début » sous
//    l'heure de fin, bouton « Valider » désactivé tant que l'ordre est
//    invalide ;
//  · spinner pendant l'enregistrement Firestore (l'erreur reste dans
//    la boîte si ça échoue, on ne la referme pas) ;
//  · lignes en fondu + glissement (stagger), heures en bleu #2458D3.
// ─────────────────────────────────────────────────────────────────────
class _DialoguePlage extends StatefulWidget {
  final String titre;
  final _Plage? existante;
  final Future<void> Function(_Plage plage) onEnregistrer;

  const _DialoguePlage({
    required this.titre,
    required this.onEnregistrer,
    this.existante,
  });

  @override
  State<_DialoguePlage> createState() => _DialoguePlageState();
}

class _DialoguePlageState extends State<_DialoguePlage>
    with SingleTickerProviderStateMixin {
  late TimeOfDay _debut =
      widget.existante == null
          ? const TimeOfDay(hour: 8, minute: 0)
          : _versTimeOfDay(widget.existante!.debut);
  late TimeOfDay _fin =
      widget.existante == null
          ? const TimeOfDay(hour: 16, minute: 0)
          : _versTimeOfDay(widget.existante!.fin);

  bool _envoi = false;
  String? _erreurEnvoi;

  // Animation d'ENTRÉE des deux lignes (fondu + glissement).
  late final AnimationController _entree = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  @override
  void dispose() {
    _entree.dispose();
    super.dispose();
  }

  /// Règle de validation EN DIRECT : la fin doit être APRÈS le début.
  bool get _ordreValide => _versTexte(_debut).compareTo(_versTexte(_fin)) < 0;

  Future<void> _choisir(bool estDebut) async {
    final choix = await showTimePicker(
      context: context,
      initialTime: estDebut ? _debut : _fin,
    );
    if (choix != null && mounted) {
      setState(() {
        if (estDebut) {
          _debut = choix;
        } else {
          _fin = choix;
        }
      });
    }
  }

  Future<void> _valider() async {
    if (_envoi || !_ordreValide) return;
    setState(() {
      _envoi = true;
      _erreurEnvoi = null;
    });
    final plage = _Plage(debut: _versTexte(_debut), fin: _versTexte(_fin));
    try {
      // On ATTEND réellement l'écriture Firestore : spinner pendant
      // l'envoi, et l'erreur reste affichée ici si ça échoue.
      await widget.onEnregistrer(plage);
      if (!mounted) return;
      Navigator.pop(context, plage);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _erreurEnvoi = 'Enregistrement impossible — réessayez.';
      });
    }
  }

  Widget _anime(int index, Widget enfant) {
    final interval = Interval(
      0.2 * index,
      // Borné à 1 : Interval exige end <= 1.
      (0.2 * index + 0.6).clamp(0.0, 1.0).toDouble(),
      curve: Curves.easeOutCubic,
    );
    final anim = _entree.drive(CurveTween(curve: interval));
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(anim),
        child: enfant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: MaquetteCouleurs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MaquetteRayons.carte),
      ),
      title: Text(
        widget.titre,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: MaquetteCouleurs.texte,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ligne « Heure de début » : texte seul, pas d'icône.
          _anime(0, _ligneHeure('Heure de début', _debut, () => _choisir(true))),
          const SizedBox(height: 4),
          // « Heure de fin » : message d'erreur EN DIRECT si l'ordre
          // des heures est invalide.
          _anime(
            1,
            _ligneHeure(
              'Heure de fin',
              _fin,
              () => _choisir(false),
              erreur:
                  _ordreValide ? null : 'La fin doit être après le début',
            ),
          ),
          if (_erreurEnvoi != null) ...[
            const SizedBox(height: 10),
            Text(
              _erreurEnvoi!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: MaquetteCouleurs.refuseTexte,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _envoi ? null : () => Navigator.pop(context),
          child: const Text(
            'Annuler',
            style: TextStyle(color: MaquetteCouleurs.texteSecondaire),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: MaquetteCouleurs.bleu,
            disabledBackgroundColor: const Color(0xFFD7DCE8),
          ),
          // Désactivé pendant l'envoi OU si l'ordre est invalide
          // (validation en direct).
          onPressed: (_envoi || !_ordreValide) ? null : _valider,
          child: _envoi
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Valider',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ],
    );
  }

  /// Une ligne « Heure de début/fin » : libellé + heure cliquable
  /// (carte maquette, heure en bleu #2458D3), avec l'erreur éventuelle.
  Widget _ligneHeure(
    String libelle,
    TimeOfDay heure,
    VoidCallback onTap, {
    String? erreur,
  }) {
    const rayon = BorderRadius.all(Radius.circular(12));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: rayon,
          onTap: _envoi ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: MaquetteCouleurs.fond,
              borderRadius: rayon,
              border: Border.all(
                color: erreur == null
                    ? MaquetteCouleurs.bordure
                    : MaquetteCouleurs.refuseTexte,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    libelle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: MaquetteCouleurs.texte,
                    ),
                  ),
                ),
                Text(
                  heure.format(context),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MaquetteCouleurs.bleu,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (erreur != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              erreur,
              style: const TextStyle(
                fontSize: 12,
                color: MaquetteCouleurs.refuseTexte,
              ),
            ),
          ),
      ],
    );
  }

  static String _versTexte(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay _versTimeOfDay(String hhmm) {
    final morceaux = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(morceaux.first) ?? 0,
      minute: morceaux.length > 1 ? (int.tryParse(morceaux[1]) ?? 0) : 0,
    );
  }
}
