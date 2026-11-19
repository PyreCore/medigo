import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/secretaire.dart';
import '../../models/patient.dart';
import '../../models/medecin.dart';
import '../../models/rendez_vous.dart';
import '../../services/secretaire_service.dart';
import '../../theme/medigo_theme.dart';
import '../../widgets/ui_kit.dart';
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

  /// (AJOUT) Contenu de la corbeille (RDV + date de mise à la corbeille).
  List<({RendezVous rdv, DateTime corbeilleLe})> _corbeille = [];

  /// Vrai dès la première ouverture de l'onglet Corbeille : la
  /// corbeille n'est téléchargée (et rafraîchie toutes les 5 s) qu'à
  /// partir de ce moment-là, pour ne pas ajouter une requête Firestore
  /// inutile à chaque chargement tant que l'utilisateur n'y est pas allé.
  bool _corbeilleOuverte = false;

  /// Timer qui recharge automatiquement les données toutes les 5 s.
  /// Permet à la secrétaire de voir les nouvelles demandes sans
  /// rafraîchir manuellement la page.
  Timer? _timerRafraichir;

  /// Ancienne liste des RDV en attente, pour détecter les nouvelles
  /// demandes à chaque rechargement et afficher une notification.
  Set<String> _anciensIdsEnAttente = {};

  @override
  void initState() {
    super.initState();
    _charger();
    // Rechargement automatique toutes les 5 secondes.
    _timerRafraichir = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _charger(),
    );
  }

  @override
  void dispose() {
    _timerRafraichir?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() => _erreur = null);
    try {
      final secretaire = await _service.getProfilConnecte();

      // On a besoin de hopitalId (récupéré via le profil) pour toutes
      // les requêtes suivantes, d'où l'ordre : profil d'abord, reste ensuite.
      final hopitalId = secretaire.hopitalId;
      final patients = await _service.getPatientsPourHopital(hopitalId);
      final medecins = await _service.getMedecinsHopital(hopitalId);
      // getTousRendezVous (et non getRendezVousDuJour) : la secrétaire
      // doit voir TOUS les RDV de l'hôpital, y compris ceux qu'elle
      // programme à des dates futures. Le filtre "du jour" est fait
      // dans l'éconglet Rendez-vous si besoin.
      final rendezVous = await _service.getTousRendezVous(hopitalId);
      final stats = await _service.getStatistiques(hopitalId);
      // (AJOUT) Corbeille : seulement après la première ouverture de
      // l'onglet (cf. _corbeilleOuverte).
      final corbeille = _corbeilleOuverte
          ? await _service.getCorbeille(hopitalId)
          : <({RendezVous rdv, DateTime corbeilleLe})>[];

      // 'totalPatients' n'est pas calculé par le service (compter demanderait
      // une requête Firestore de plus) : on connaît déjà le nombre exact de
      // patients affichés, la liste étant chargée juste au-dessus.
      final statistiques = {...stats, 'totalPatients': patients.length};

      if (mounted) {
        // Détection de nouvelles demandes : on compare les IDs des
        // RDV en attente actuels avec ceux du chargement précédent.
        final idsEnAttente = rendezVous
            .where((r) => r.statut == StatutRendezVous.enAttente)
            .map((r) => r.id)
            .toSet();
        final nouveaux = idsEnAttente.difference(_anciensIdsEnAttente);

        setState(() {
          _secretaire = secretaire;
          _patients = patients;
          _medecins = medecins;
          _rendezVous = rendezVous;
          _stats = statistiques;
          _corbeille = corbeille;
        });

        // Notification si de nouvelles demandes sont arrivées
        // (uniquement après le chargement initial, pas au démarrage).
        if (_anciensIdsEnAttente.isNotEmpty && nouveaux.isNotEmpty) {
          messageFlash(
            context,
            nouveaux.length == 1
                ? 'Nouvelle demande de rendez-vous'
                : '${nouveaux.length} nouvelles demandes de rendez-vous',
          );
        }

        // On mémorise les IDs actuels pour le prochain rechargement.
        _anciensIdsEnAttente = idsEnAttente;
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
    // Retour visuel : message de confirmation en bas de l'écran.
    if (mounted) messageFlash(context, 'Patient enregistré');
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
      // patient.userId = uid du COMPTE : le rendez-vous du guichet doit
      // apparaître dans l'espace Patient, qui filtre sur "patientUid".
      patientUid: patient.userId,
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
    if (mounted) messageFlash(context, 'Rendez-vous programmé');
  }

  Future<void> _confirmer(RendezVous rdv) async {
    await _service.confirmerRendezVous(rdv.id);
    await _charger();
    if (mounted) messageFlash(context, 'Rendez-vous confirmé');
  }

  Future<void> _refuser(RendezVous rdv, {String? motif}) async {
    await _service.refuserRendezVous(rdv.id, motif: motif);
    await _charger();
    if (mounted) messageFlash(context, 'Rendez-vous refusé');
  }

  Future<void> _annuler(RendezVous rdv) async {
    await _service.annulerRendezVous(rdv.id);
    await _charger();
    if (mounted) messageFlash(context, 'Rendez-vous annulé');
  }

  // ── Corbeille (ajout) ────────────────────────────────────────────

  Future<void> _mettreALaCorbeille(RendezVous rdv) async {
    await _service.mettreALaCorbeille(rdv.id);
    await _charger();
    if (mounted) messageFlash(context, 'Rendez-vous mis à la corbeille');
  }

  Future<void> _restaurer(RendezVous rdv) async {
    await _service.restaurer(rdv.id);
    await _charger();
    if (mounted) messageFlash(context, 'Rendez-vous restauré');
  }

  Future<void> _supprimerDefinitivement(RendezVous rdv) async {
    await _service.supprimerDefinitivement(rdv.id);
    await _charger();
    if (mounted) {
      messageFlash(context, 'Rendez-vous supprimé définitivement');
    }
  }

  /// Ouverture de l'onglet Corbeille : purge à 30 jours (sans Cloud
  /// Functions : elle part du client, à chaque ouverture — pas à chaque
  /// rafraîchissement des 5 s), puis rechargement. Un échec de purge
  /// n'écrase pas l'écran : message d'erreur discret, la liste s'affiche
  /// quand même.
  Future<void> _ouvrirCorbeille() async {
    _corbeilleOuverte = true;
    var purges = 0;
    try {
      purges = await _service.purgerCorbeille(_secretaire!.hopitalId);
    } catch (_) {
      if (mounted) {
        messageFlash(
          context,
          'Purge automatique impossible pour le moment',
          succes: false,
        );
      }
    }
    await _charger();
    if (mounted && purges > 0) {
      messageFlash(
        context,
        purges == 1
            ? '1 rendez-vous supprimé de la corbeille'
            : '$purges rendez-vous supprimés de la corbeille',
      );
    }
  }

  Future<void> _deconnexion() async {
    await FirebaseAuth.instance.signOut();
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
    if (_erreur != null) {
      return Scaffold(
        backgroundColor: AppColors.fond,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Impossible de charger votre espace',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.texte,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Erreur : $_erreur',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.texteFaible,
                  ),
                ),
                const SizedBox(height: 20),
                BoutonPrincipal(
                  texte: 'Réessayer',
                  pleineLargeur: false,
                  onPressed: _charger,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_secretaire == null) {
      // Squelette pulsant « moulé » sur le tableau de bord.
      return const Scaffold(
        backgroundColor: AppColors.fond,
        body: SqueletteChargement(
          message: 'Chargement de votre espace…',
        ),
      );
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
      onRefuserRendezVous: _refuser,
      corbeille: _corbeille,
      onOuvrirCorbeille: _ouvrirCorbeille,
      onMettreALaCorbeille: _mettreALaCorbeille,
      onRestaurerRendezVous: _restaurer,
      onSupprimerRendezVous: _supprimerDefinitivement,
      onRafraichir: _charger,
      onDeconnexion: _deconnexion,
    );
  }
}
