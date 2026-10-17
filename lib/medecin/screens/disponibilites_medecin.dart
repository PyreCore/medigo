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
        // Bandeau informatif : la gestion des horaires est réservée
        // à la secrétaire de l'hôpital. Le médecin ne fait que consulter.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Vos horaires sont gérés par la secrétaire de l\'hôpital. '
            'Pour toute modification, contactez-la directement.',
            style: TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
        const SizedBox(height: 16),
        for (int jour = 1; jour <= 7; jour++)
          _CarteJour(
            jour: jour,
            toutesLesPlages: _disponibilites.where((d) => d.jour == jour).toList(),
            onAjouter: null, // désactivé : la secrétaire gère les horaires
            onModifier: null,
            onSupprimer: null,
            onBasculer: null,
          ),
      ],
    );
  }
}

/// Carte d'un jour : la liste de ses plages, avec les actions sur chacune.
/// Les callbacks sont optionnels : si null, l'action correspondante n'est
/// pas affichée (mode lecture seule).
class _CarteJour extends StatelessWidget {
  final int jour;
  final List<Disponibilite> toutesLesPlages; // actives ET inactives
  final VoidCallback? onAjouter;
  final Future<void> Function(Disponibilite)? onModifier;
  final Future<void> Function(Disponibilite)? onSupprimer;
  final Future<void> Function(Disponibilite)? onBasculer;

  const _CarteJour({
    required this.jour,
    required this.toutesLesPlages,
    this.onAjouter,
    this.onModifier,
    this.onSupprimer,
    this.onBasculer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
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
                // Bouton "Ajouter" visible uniquement si onAjouter est fourni.
                if (onAjouter != null)
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
                  onModifier: onModifier,
                  onSupprimer: onSupprimer,
                  onBasculer: onBasculer,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Une plage horaire, avec ses trois actions.
/// Les callbacks sont optionnels : si null, le bouton correspondant
/// n'est pas affiché (mode lecture seule).
class _LignePlage extends StatelessWidget {
  final Disponibilite plage;
  final Future<void> Function(Disponibilite)? onModifier;
  final Future<void> Function(Disponibilite)? onSupprimer;
  final Future<void> Function(Disponibilite)? onBasculer;

  const _LignePlage({
    required this.plage,
    this.onModifier,
    this.onSupprimer,
    this.onBasculer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Pas d'icône (parti pris Medigo, texte seul) : la plage
          // inactive est simplement grisée et barrée. maxLines/ellipsis
          // : sur un écran étroit (360 px), l'heure est coupée proprement
          // au lieu de passer sur plusieurs lignes.
          Expanded(
            child: Text(
              plage.libelle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: plage.actif ? Colors.black87 : Colors.black38,
                decoration: plage.actif ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
        // Interrupteur visible uniquement si onBasculer est fourni.
          if (onBasculer != null)
            Switch(
              value: plage.actif,
              activeThumbColor: const Color(0xFF2E6F6E),
              onChanged: (_) => onBasculer!(plage),
            ),
          // Bouton "Modifier" visible uniquement si onModifier est fourni.
          if (onModifier != null)
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => onModifier!(plage),
            ),
          // Bouton "Supprimer" visible uniquement si onSupprimer est fourni.
          if (onSupprimer != null)
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              onPressed: () => onSupprimer!(plage),
            ),
        ],
      ),
    );
  }
}
