import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/secretaire.dart';
import '../../models/patient.dart';
import '../../models/medecin.dart';
import '../../models/rendez_vous.dart';
import '../../services/secretaire_service.dart';
import 'espace_secretaire.dart';

/// Équivalent de MedecinHomeLoader, côté secrétaire : charge le profil,
/// les patients, les médecins de l'hôpital et les rendez-vous du jour
/// depuis Firestore, puis affiche EspaceSecretaire une fois prêt.
class SecretaireHomeLoader extends StatefulWidget {
  const SecretaireHomeLoader({super.key});

  @override
  State<SecretaireHomeLoader> createState() => _SecretaireHomeLoaderState();
}

class _SecretaireHomeLoaderState extends State<SecretaireHomeLoader> {
  final _service = SecretaireService();

  Secretaire? _secretaire;
  List<Patient> _patients = [];
  List<Medecin> _medecins = [];
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
      final secretaire = await _service.getProfilConnecte();

      // On a besoin de hopitalId (récupéré via le profil) pour toutes
      // les requêtes suivantes, d'où l'ordre : profil d'abord, reste ensuite.
      final hopitalId = secretaire.hopitalId;
      final patients = await _service.getPatients(hopitalId);
      final medecins = await _service.getMedecinsHopital(hopitalId);
      final rendezVous = await _service.getRendezVousDuJour(hopitalId);
      final stats = await _service.getStatistiques(hopitalId);

      if (mounted) {
        setState(() {
          _secretaire = secretaire;
          _patients = patients;
          _medecins = medecins;
          _rendezVous = rendezVous;
          _stats = stats;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = e.toString());
    }
  }

  Future<void> _enregistrerPatient({
    required String nom,
    required String prenom,
    required String telephone,
    String? groupeSanguin,
  }) async {
    await _service.enregistrerPatient(
      nom: nom,
      prenom: prenom,
      telephone: telephone,
      hopitalId: _secretaire!.hopitalId,
      groupeSanguin: groupeSanguin,
    );
    await _charger();
  }

  Future<void> _programmerRendezVous({
    required Patient patient,
    required Medecin medecin,
    required DateTime date,
    required String heure,
    String? motif,
  }) async {
    await _service.programmerRendezVous(
      patientId: patient.id,
      patientNom: patient.nom,
      patientPrenom: patient.prenom,
      medecinId: medecin.id,
      medecinNom: medecin.nomComplet,
      hopitalId: _secretaire!.hopitalId,
      date: date,
      heure: heure,
      motif: motif,
    );
    await _charger();
  }

  Future<void> _confirmer(RendezVous rdv) async {
    await _service.confirmerRendezVous(rdv.id);
    await _charger();
  }

  Future<void> _annuler(RendezVous rdv) async {
    await _service.annulerRendezVous(rdv.id);
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

    if (_secretaire == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return EspaceSecretaire(
      secretaire: _secretaire!,
      patients: _patients,
      medecins: _medecins,
      rendezVousDuJour: _rendezVous,
      statistiques: _stats,
      onEnregistrerPatient: _enregistrerPatient,
      onProgrammerRendezVous: _programmerRendezVous,
      onConfirmerRendezVous: _confirmer,
      onAnnulerRendezVous: _annuler,
      onDeconnexion: _deconnexion,
    );
  }
}
