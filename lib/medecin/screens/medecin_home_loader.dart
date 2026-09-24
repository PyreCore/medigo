import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/medecin.dart';
import '../../models/rendez_vous.dart';
import '../../services/medecin_service.dart';
import 'espace_medecin.dart';

/// Écran "intermédiaire" affiché juste après la connexion d'un médecin :
/// il charge son profil et ses rendez-vous depuis Firestore (via
/// MedecinService), affiche un indicateur pendant ce temps, puis montre
/// EspaceMedecin une fois les données prêtes. C'est ici que les données
/// RÉELLES (Firestore) remplacent les données mock qu'on utilisait pour
/// tester dans main.dart.
class MedecinHomeLoader extends StatefulWidget {
  const MedecinHomeLoader({super.key});

  @override
  State<MedecinHomeLoader> createState() => _MedecinHomeLoaderState();
}

class _MedecinHomeLoaderState extends State<MedecinHomeLoader> {
  final _service = MedecinService();

  // Nullable : tant que les données ne sont pas arrivées, ces variables
  // valent null et on affiche un indicateur de chargement à la place.
  Medecin? _medecin;
  List<RendezVous> _rendezVous = [];
  Map<String, int> _stats = {};
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _erreur = null);
    try {
      // On charge le profil d'abord, car on a besoin de son id pour
      // demander ensuite SES rendez-vous et SES statistiques.
      final medecin = await _service.getProfilConnecte();
      final rendezVous = await _service.getRendezVousDuJour(medecin.id);
      final stats = await _service.getStatistiques(medecin.id);

      // On ne met à jour l'état qu'une seule fois, avec toutes les
      // données prêtes en même temps, plutôt que 3 fois séparément
      // (évite 2 reconstructions d'écran inutiles).
      if (mounted) {
        setState(() {
          _medecin = medecin;
          _rendezVous = rendezVous;
          _stats = stats;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = e.toString());
    }
  }

  Future<void> _accepter(RendezVous rdv) async {
    await _service.accepterRendezVous(rdv.id);
    // On recharge tout après l'action, pour que l'écran reflète bien
    // le nouveau statut (et les stats à jour) sans logique compliquée
    // de mise à jour manuelle d'une seule ligne dans la liste.
    await _charger();
  }

  Future<void> _refuser(RendezVous rdv) async {
    await _service.refuserRendezVous(rdv.id);
    await _charger();
  }

  Future<void> _deconnexion() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cas 1 : une erreur est survenue (ex: pas de connexion internet,
    // profil introuvable...).
    if (_erreur != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Erreur : $_erreur', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _charger, child: const Text('Réessayer')),
              ],
            ),
          ),
        ),
      );
    }

    // Cas 2 : les données ne sont pas encore arrivées, on affiche un
    // indicateur de chargement au centre de l'écran.
    if (_medecin == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Cas 3 : tout est prêt, on affiche l'écran principal avec les
    // vraies données et les vraies actions branchées sur Firestore.
    return EspaceMedecin(
      medecin: _medecin!,
      rendezVousDuJour: _rendezVous,
      enAttente: _stats['enAttente'] ?? 0,
      patientsSuivis: _stats['patientsSuivis'] ?? 0,
      onRafraichir: _charger,
      onAccepterRendezVous: _accepter,
      onRefuserRendezVous: _refuser,
      onDeconnexion: _deconnexion,
    );
  }
}
