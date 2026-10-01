import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// "unawaited" : on lance la programmation des rappels sans l'attendre, pour
// ne pas retarder l'affichage de l'espace. Importé de dart:async, pas de
// flutter, car c'est un utilitaire du langage.
import 'dart:async';
import '../../models/medecin.dart';
import '../../models/patient.dart';
import '../../models/rendez_vous.dart';
import '../../services/patient_service.dart';
import '../../shared/models/hopital_model.dart';
import '../../services/notification_service.dart';
import 'espace_patient.dart';

/// Écran "intermédiaire" affiché juste après la connexion d'un patient :
/// il charge son dossier et ses données depuis Firestore (via
/// PatientService), affiche un indicateur pendant ce temps, puis montre
/// EspacePatient une fois les données prêtes. Même structure que
/// MedecinHomeLoader et SecretaireHomeLoader.
class PatientHomeLoader extends StatefulWidget {
  const PatientHomeLoader({super.key});

  @override
  State<PatientHomeLoader> createState() => _PatientHomeLoaderState();
}

class _PatientHomeLoaderState extends State<PatientHomeLoader> {
  final _service = PatientService();

  // Nullable : tant que les données ne sont pas arrivées, ces variables
  // valent null et on affiche un indicateur de chargement à la place.
  Patient? _patient;
  List<RendezVous> _rendezVous = [];
  List<RendezVous> _rendezVousDuJour = [];
  Map<String, int> _stats = {};
  String? _erreur;

  // Liste des hôpitaux partenaires. Elle seule est chargée ici : les
  // médecins et les spécialités dépendent de l'hôpital choisi, donc ils sont
  // chargés par le formulaire de réservation au moment où le patient en
  // désigne un.
  List<Hopital> _hopitaux = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _erreur = null);
    try {
      // getProfilConnecte() s'appuie sur FirebaseAuth.instance.currentUser,
      // donc le patient ne peut pas consulter le dossier d'un autre en
      // changeant un paramètre. Il renvoie null si le compte connecté
      // n'a pas le rôle "patient" (cas d'un compte mal configuré).
      final patient = await _service.getProfilConnecte();
      if (patient == null) {
        setState(() => _erreur = 'Aucun dossier patient pour ce compte');
        return;
      }

      // Les VALEURS à remplir par le patient ne dépendent que de lui : nom,
      // prénom, email, téléphone. Son établissement n'en fait PAS partie —
      // il le choisit à chaque prise de rendez-vous, dans l'onglet
      // « Prendre rendez-vous ».
      final hopitaux = await _service.getHopitaux();

      // UN seul appel Firestore pour tous les rendez-vous : on en déduit
      // la journée et les statistiques côté Dart (voir PatientService),
      // plutôt que de faire trois requêtes qui reliraient la même
      // collection à chaque rafraîchissement.
      // On interroge par l'UID DU COMPTE (et non par l'id du dossier) : les
      // règles de sécurité n'acceptent une requête "rendez_vous" d'un patient
      // que sur ce champ, le dossier n'étant pas résolvable depuis une
      // requête Firestore.
      final uid = patient.userId;
      final tous = uid == null
          ? <RendezVous>[]
          : await _service.getRendezVous(uid);
      final duJour = PatientService.filtreDuJour(tous);
      final stats = PatientService.calculerStatistiques(tous);

      // On ne met à jour l'état qu'une seule fois, avec toutes les
      // données prêtes en même temps, plutôt que 5 fois séparément
      // (évite des reconstructions d'écran inutiles).
      if (mounted) {
        setState(() {
          _patient = patient;
          _hopitaux = hopitaux;
          _rendezVous = tous;
          _rendezVousDuJour = duJour;
          _stats = stats;
        });

        // Les rappels sont reprogrammés à CHAQUE chargement, et non à chaque
        // action : c'est ce qui fait qu'une annulation ou une
        // reprogrammation disparaisse des rappels, puisque le set complet
        // est reconstruit à partir de Firestore. On n'attend pas ce
        // rechargement pour afficher l'écran.
        unawaited(NotificationService.instance.planifierRappels(tous));
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = e.toString());
    }
  }

  Future<void> _demanderRendezVous({
    required Medecin medecin,
    required DateTime date,
    required String heure,
    String? motif,
  }) async {
    await _service.demanderRendezVous(
      patient: _patient!,
      medecin: medecin,
      date: date,
      heure: heure,
      motif: motif,
    );
    // On recharge tout après l'action, pour que l'écran reflète bien
    // le nouveau rendez-vous (et les stats à jour) sans logique
    // compliquée de mise à jour manuelle d'une seule ligne dans la liste.
    await _charger();
  }

  Future<void> _annulerRendezVous(RendezVous rdv) async {
    await _service.annulerRendezVous(rdv.id);
    await _charger();
  }

  /// Reprogramme un rendez-vous puis recharge l'espace.
  ///
  /// Le service peut refuser (rendez-vous passé, déjà annulé) : on affiche
  /// le message plutôt que de laisser croire que la reprogrammation a
  /// abouti, car le patient vient de quitter l'onglet de modification.
  Future<void> _modifierRendezVous(
    RendezVous rdv,
    DateTime date,
    String heure,
    String? motif,
  ) async {
    try {
      await _service.modifierRendezVous(
        rdv.id,
        date: date,
        heure: heure,
        motif: motif,
      );
      await _charger();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _deconnexion() async {
    await FirebaseAuth.instance.signOut();
    // Un téléphone partagé ne doit pas laisser les rappels du compte qui
    // vient de sortir : ils continuaient d'afficher le nom du médecin.
    await NotificationService.instance.toutAnnuler();
    if (mounted) {
      // Deconnexion : on revient a l'accueil PUBLIC et on vide la pile.
      // Un simple pushReplacementNamed laisserait l'espace prive sous
      // l'accueil, et le bouton retour renverrait dans un ecran qui
      // suppose encore une session ouverte.
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cas 1 : une erreur est survenue (profil absent, pas de réseau...).
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

    // Cas 2 : les données ne sont pas encore arrivées.
    if (_patient == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Cas 3 : tout est prêt, on affiche l'écran principal avec les vraies
    // données et les vraies actions branchées sur Firestore.
    return EspacePatient(
      patient: _patient!,
      hopitaux: _hopitaux,
      rendezVous: _rendezVous,
      rendezVousDuJour: _rendezVousDuJour,
      statistiques: _stats,
      onRafraichir: _charger,
      onDemanderRendezVous: _demanderRendezVous,
      onAnnulerRendezVous: _annulerRendezVous,
      onModifierRendezVous: _modifierRendezVous,
      onDeconnexion: _deconnexion,
    );
  }
}
