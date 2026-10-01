import 'package:flutter/material.dart';
import '../../models/medecin.dart';
import '../../models/disponibilite.dart';
import '../../services/disponibilite_service.dart';

/// Onglet "Disponibilités" : le médecin déclare ses plages horaires, et ces
/// plages become les créneaux que les patients peuvent réserver.
///
/// Écriture dans Firestore (collection "disponibilites", voir
/// models/disponibilite.dart). Chaque modification est enregistrée
/// immédiatement : un médecin qui coupe l'application après avoir retiré un
/// créneau ne doit pas perdre sa saisie.
///
/// Le médecin peut déclarer PLUSIEURS plages pour un même jour (matin et
/// après-midi) : ce sont des documents distincts, pas un début et une fin
/// dans un seul. Un intervalle unique ne permettrait pas de modéliser une pause
/// déjeuner, qui est précisément le cas le plus fréquent.
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

  /// Crée une nouvelle plage pour [jour].
  Future<void> _ajouter(int jour) async {
    final plage = await _demanderPlage(context, jour: jour);
    if (plage == null || !mounted) return;

    await _service.enregistrer(
      Disponibilite(
        id: '',
        medecinId: widget.medecin.id,
        jour: jour,
        heureDebut: plage.debut,
        heureFin: plage.fin,
      ),
    );
    await _charger();
  }

  /// Ouvre la boîte de dialogue de saisie d'une plage, pré-remplie si on
  /// modifie une plage existante. Renvoie null si l'utilisateur annule.
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
                ? 'Ajouter une plage — ${Disponibilite.nomJour(jour)}'
                : 'Modifier la plage — ${Disponibilite.nomJour(jour)}',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_arrow),
                title: const Text('Heure de début'),
                trailing: Text(debut.format(context)),
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
                leading: const Icon(Icons.stop),
                title: const Text('Heure de fin'),
                trailing: Text(fin.format(context)),
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
                backgroundColor: const Color(0xFF2E6F6E),
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
    // toujours au format "HH:mm" avec un zéro en tête : l'ordre alphabétique
    // correspond alors à l'ordre horaire ("09:00" < "10:00").
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

  Future<void> _modifier(Disponibilite disponibilite) async {
    final plage = await _demanderPlage(
      context,
      jour: disponibilite.jour,
      existante: _Plage(
        debut: disponibilite.heureDebut,
        fin: disponibilite.heureFin,
      ),
    );
    if (plage == null || !mounted) return;

    await _service.enregistrer(
      Disponibilite(
        id: disponibilite.id,
        medecinId: disponibilite.medecinId,
        jour: disponibilite.jour,
        heureDebut: plage.debut,
        heureFin: plage.fin,
        actif: disponibilite.actif,
      ),
    );
    await _charger();
  }

  Future<void> _supprimer(Disponibilite disponibilite) async {
    await _service.supprimer(disponibilite.id);
    await _charger();
  }

  /// Active ou désactive une plage. Désactiver la conserve : le médecin peut
  /// la réactiver, et surtout on ne perd pas l'historique de ce qu'il
  /// proposait (des rendez-vous patients ont peut-être été pris dessus).
  Future<void> _basculer(Disponibilite disponibilite) async {
    await _service.enregistrer(
      Disponibilite(
        id: disponibilite.id,
        medecinId: disponibilite.medecinId,
        jour: disponibilite.jour,
        heureDebut: disponibilite.heureDebut,
        heureFin: disponibilite.heureFin,
        actif: !disponibilite.actif,
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Les créneaux que vous déclarez ici sont ceux que les patients '
            'peuvent réserver. Un créneau déjà pris disparaît de leur liste.',
            style: TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
        const SizedBox(height: 16),
        for (int jour = 1; jour <= 7; jour++)
          _CarteJour(
            jour: jour,
            toutesLesPlages: _disponibilites.where((d) => d.jour == jour).toList(),
            onAjouter: () => _ajouter(jour),
            onModifier: _modifier,
            onSupprimer: _supprimer,
            onBasculer: _basculer,
          ),
      ],
    );
  }
}

/// Une plage saisie dans la boîte de dialogue, avant d'être enregistrée.
class _Plage {
  final String debut;
  final String fin;

  const _Plage({required this.debut, required this.fin});
}

/// Carte d'un jour : la liste de ses plages, avec les actions sur chacune.
class _CarteJour extends StatelessWidget {
  final int jour;
  final List<Disponibilite> toutesLesPlages; // actives ET inactives
  final VoidCallback onAjouter;
  final Future<void> Function(Disponibilite) onModifier;
  final Future<void> Function(Disponibilite) onSupprimer;
  final Future<void> Function(Disponibilite) onBasculer;

  const _CarteJour({
    required this.jour,
    required this.toutesLesPlages,
    required this.onAjouter,
    required this.onModifier,
    required this.onSupprimer,
    required this.onBasculer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    Disponibilite.nomJour(jour),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onAjouter,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
            if (toutesLesPlages.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'Aucune plage déclarée',
                  style: TextStyle(fontSize: 13, color: Colors.black45),
                ),
              )
            else
              ...toutesLesPlages.map(
                (plage) => _LignePlage(
                  plage: plage,
                  onModifier: () => onModifier(plage),
                  onSupprimer: () => onSupprimer(plage),
                  onBasculer: () => onBasculer(plage),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Une plage horaire, avec ses trois actions.
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
    return Row(
      children: [
        Icon(
          plage.actif ? Icons.schedule : Icons.schedule_outlined,
          size: 18,
          color: plage.actif ? const Color(0xFF2E6F6E) : Colors.black26,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            plage.libelle,
            style: TextStyle(
              fontSize: 14,
              color: plage.actif ? Colors.black87 : Colors.black38,
              decoration: plage.actif ? null : TextDecoration.lineThrough,
            ),
          ),
        ),
        Switch(
          value: plage.actif,
          activeThumbColor: const Color(0xFF2E6F6E),
          onChanged: (_) => onBasculer(),
        ),
        IconButton(
          tooltip: 'Modifier',
          icon: const Icon(Icons.edit_outlined, size: 20),
          onPressed: onModifier,
        ),
        IconButton(
          tooltip: 'Supprimer',
          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
          onPressed: onSupprimer,
        ),
      ],
    );
  }
}
