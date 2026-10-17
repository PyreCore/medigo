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

    final plage = await _demanderPlage(context, jour: jour);
    if (plage == null || !mounted) return;

    await _service.enregistrer(
      Disponibilite(
        id: '',
        medecinId: medecin.id,
        jour: jour,
        heureDebut: plage.debut,
        heureFin: plage.fin,
      ),
    );
    await _charger();
  }

  /// Boîte de dialogue de saisie d'une plage (pré-remplie si modification).
  /// Renvoie null si l'utilisateur annule.
  Future<_Plage?> _demanderPlage(
    BuildContext context, {
    required int jour,
    _Plage? existante,
  }) async {
    TimeOfDay debut =
        existante == null
            ? const TimeOfDay(hour: 8, minute: 0)
            : _versTimeOfDay(existante.debut);
    TimeOfDay fin =
        existante == null
            ? const TimeOfDay(hour: 16, minute: 0)
            : _versTimeOfDay(existante.fin);

    final valide = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(
            existante == null
                ? 'Ajouter — ${Disponibilite.nomJour(jour)}'
                : 'Modifier — ${Disponibilite.nomJour(jour)}',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ligne « Heure de début » : texte seul, pas d'icône.
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Heure de début'),
                trailing: Text(
                  debut.format(context),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () async {
                  final choix = await showTimePicker(
                    context: context,
                    initialTime: debut,
                  );
                  if (choix != null) setStateDialog(() => debut = choix);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Heure de fin'),
                trailing: Text(
                  fin.format(context),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () async {
                  final choix = await showTimePicker(
                    context: context,
                    initialTime: fin,
                  );
                  if (choix != null) setStateDialog(() => fin = choix);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.bleuVif,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );

    if (valide != true) return null;

    final debutTexte = _versTexte(debut);
    final finTexte = _versTexte(fin);
    // Les deux textes viennent de TimeOfDay via _versTexte, donc ils sont
    // toujours au format "HH:mm" avec un zéro en tête : l'ordre
    // alphabétique correspond alors à l'ordre horaire ("09:00" < "10:00").
    if (debutTexte.compareTo(finTexte) >= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('L\'heure de fin doit être après l\'heure de début'),
          ),
        );
      }
      return null;
    }

    return _Plage(debut: debutTexte, fin: finTexte);
  }

  Future<void> _modifier(Disponibilite plage) async {
    final nouvelle = await _demanderPlage(
      context,
      jour: plage.jour,
      existante: _Plage(debut: plage.heureDebut, fin: plage.heureFin),
    );
    if (nouvelle == null || !mounted) return;

    await _service.enregistrer(
      Disponibilite(
        id: plage.id,
        medecinId: plage.medecinId,
        jour: plage.jour,
        heureDebut: nouvelle.debut,
        heureFin: nouvelle.fin,
        actif: plage.actif,
      ),
    );
    await _charger();
  }

  Future<void> _supprimer(Disponibilite plage) async {
    await _service.supprimer(plage.id);
    await _charger();
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
    await _charger();
  }

  static String _versTexte(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay _versTimeOfDay(String hhmm) {
    final morceaux = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(morceaux.first) ?? 0,
      minute: morceaux.length > 1 ? (int.tryParse(morceaux[1]) ?? 0) : 0,
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
          for (int jour = 1; jour <= 7; jour++)
            _CarteJour(
              jour: jour,
              plages: _plages.where((p) => p.jour == jour).toList(),
              onAjouter: () => _ajouter(jour),
              onModifier: _modifier,
              onSupprimer: _supprimer,
              onBasculer: _basculer,
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
