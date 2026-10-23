import 'package:flutter/material.dart';
import '../../models/secretaire.dart';
import '../../models/patient.dart';
import '../../models/medecin.dart';
import '../../models/rendez_vous.dart';
import '../../widgets/structure_espace.dart';
import '../../widgets/ui_kit.dart';
import 'accueil_secretaire.dart';
import 'liste_patients_secretaire.dart';
import 'enregistrement_patient_secretaire.dart';
import 'liste_rendez_vous_secretaire.dart';
import 'detail_rendez_vous_secretaire.dart';
import 'programmer_rendez_vous_secretaire.dart';
import 'horaires_medecins_secretaire.dart';
import 'profil_secretaire.dart';

/// Écran principal de l'espace Secrétaire.
/// La COQUILLE (navigation rail sur web, barre basse sur mobile,
/// en-tête de page) est fournie par StructureEspace ; ici on gère :
///  · l'onglet actif,
///  · la photo à jour (modifiable depuis l'onglet Profil),
///  · l'ouverture des écrans de détail / formulaires,
///  · le relais des callbacks reçus du chargeur d'écran.
class EspaceSecretaire extends StatefulWidget {
  final Secretaire secretaire;
  final List<Patient> patients;
  final List<Medecin> medecins; // médecins de l'hôpital, pour programmer un RDV
  final List<RendezVous> rendezVousDuJour;
  final Map<String, int> statistiques;

  // Callbacks transmis par le parent : EspaceSecretaire ne fait que les
  // relayer aux bons écrans, sans savoir s'ils parlent à Firestore ou
  // juste à des données de démo en mémoire.
  // Chaîne ASYNCHRONE (point 5) : le formulaire attend l'écriture
  // Firestore réelle (chargeur → SecretaireService) pour afficher son
  // état de chargement puis son animation de succès, AVANT de revenir
  // à la liste. L'ancien pop immédiat supprimait ces états.
  final Future<void> Function({
    required String nom,
    required String prenom,
    required String telephone,
    String? groupeSanguin,
  })? onEnregistrerPatient;

  // Chaîne ASYNCHRONE (point 5) : le formulaire attend l'écriture
  // Firestore réelle (chargeur → SecretaireService) pour afficher son
  // état de chargement puis son animation de succès, AVANT de revenir
  // à la liste. L'ancien pop immédiat supprimait ces états.
  final Future<void> Function({
    required Patient patient,
    required Medecin medecin,
    required DateTime date,
    required String heure,
    String? motif,
  })? onProgrammerRendezVous;

  final Future<void> Function(RendezVous rdv)? onConfirmerRendezVous;
  final Future<void> Function(RendezVous rdv)? onAnnulerRendezVous;
  // Refus avec motif : la secrétaire choisit une raison parmi une liste
  // prédéfinie avant de confirmer le refus.
  final Future<void> Function(RendezVous rdv, {String? motif})?
      onRefuserRendezVous;
  final Future<void> Function()? onRafraichir;
  final VoidCallback? onDeconnexion;

  const EspaceSecretaire({
    super.key,
    required this.secretaire,
    required this.patients,
    required this.medecins,
    required this.rendezVousDuJour,
    this.statistiques = const {},
    this.onEnregistrerPatient,
    this.onProgrammerRendezVous,
    this.onConfirmerRendezVous,
    this.onAnnulerRendezVous,
    this.onRefuserRendezVous,
    this.onRafraichir,
    this.onDeconnexion,
  });

  @override
  State<EspaceSecretaire> createState() => _EspaceSecretaireState();
}

class _EspaceSecretaireState extends State<EspaceSecretaire> {
  // 0 = Accueil, 1 = Patients, 2 = Rendez-vous, 3 = Horaires, 4 = Profil.
  int _ongletActif = 0;

  // Photo de profil à jour (voir EspaceMedecin : même mécanisme).
  String? _photoModifiee;

  String? get _photo => _photoModifiee ?? widget.secretaire.photoUrl;

  // Ouvre le détail d'un rendez-vous par-dessus l'écran actuel.
  void _ouvrirDetailRdv(RendezVous rdv) {
    Navigator.push(
      context,
      routeMedigo(
        builder: (_) => DetailRendezVousSecretaire(
          rdv: rdv,
          onConfirmer: () async {
            if (widget.onConfirmerRendezVous != null) {
              await widget.onConfirmerRendezVous!(rdv);
              // "mounted" vérifie que l'écran est toujours affiché avant
              // de naviguer : évite un crash si l'utilisateur a déjà
              // quitté l'écran pendant que Firestore répondait.
              if (mounted) Navigator.pop(context);
            }
          },
          onAnnuler: () async {
            if (widget.onAnnulerRendezVous != null) {
              await widget.onAnnulerRendezVous!(rdv);
              if (mounted) Navigator.pop(context);
            }
          },
          onRefuser: (rdv, {motif}) async {
            // Pas de pop ici (point 5) : le formulaire de refus gère
            // lui-même son animation de succès puis referme LE
            // FORMULAIRE puis LE DÉTAIL (double-pop) — l'ancien pop
            // immédiat refermait le formulaire avant la fin du service.
            await widget.onRefuserRendezVous?.call(rdv, motif: motif);
          },
        ),
      ),
    );
  }

  // Ouvre le formulaire d'enregistrement d'un nouveau patient.
  void _ouvrirEnregistrementPatient() {
    Navigator.push(
      context,
      routeMedigo(
        builder: (_) => EnregistrementPatientSecretaire(
          // ASYNC (point 5) : on attend la fin de l'enregistrement
          // Firestore. PAS de pop ici : le formulaire affiche son
          // chargement puis son animation de succès, et se ferme
          // lui-même ensuite (l'ancien pop immédiat coupait ces états).
          onValider: ({
            required nom,
            required prenom,
            required telephone,
            groupeSanguin,
          }) async {
            await widget.onEnregistrerPatient?.call(
              nom: nom,
              prenom: prenom,
              telephone: telephone,
              groupeSanguin: groupeSanguin,
            );
          },
        ),
      ),
    );
  }

  // Ouvre le formulaire pour programmer un nouveau rendez-vous.
  void _ouvrirProgrammationRdv() {
    Navigator.push(
      context,
      routeMedigo(
        builder: (_) => ProgrammerRendezVousSecretaire(
          patients: widget.patients,
          medecins: widget.medecins,
          // ASYNC (point 5) : on attend la fin de l'enregistrement
          // Firestore. PAS de pop ici : le formulaire affiche son
          // chargement puis son animation de succès, et se ferme
          // lui-même ensuite (l'ancien pop immédiat coupait ces états).
          onValider: ({
            required patient,
            required medecin,
            required date,
            required heure,
            motif,
          }) async {
            await widget.onProgrammerRendezVous?.call(
              patient: patient,
              medecin: medecin,
              date: date,
              heure: heure,
              motif: motif,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onglets = [
      AccueilSecretaire(
        secretaire: widget.secretaire,
        photoUrl: _photo,
        rendezVousDuJour: widget.rendezVousDuJour,
        statistiques: widget.statistiques,
        onTapRendezVous: _ouvrirDetailRdv,
        // Actions rapides du dashboard (visibles sur mobile ET web).
        onNouveauRendezVous: _ouvrirProgrammationRdv,
        onNouveauPatient: _ouvrirEnregistrementPatient,
        onRafraichir: widget.onRafraichir,
      ),
      ListePatientsSecretaire(
        patients: widget.patients,
        onNouveauPatient: _ouvrirEnregistrementPatient,
      ),
      ListeRendezVousSecretaire(
        rendezVous: widget.rendezVousDuJour,
        onTapRendezVous: _ouvrirDetailRdv,
        onNouveauRendezVous: _ouvrirProgrammationRdv,
      ),
      // Gestion des horaires de TOUS les médecins de l'hôpital
      // (ajout / modification / validation des créneaux).
      HorairesMedecinsSecretaire(medecins: widget.medecins),
      ProfilSecretaire(
        secretaire: widget.secretaire,
        photoUrl: _photo,
        onPhotoChange: (url) => setState(() => _photoModifiee = url),
        onDeconnexion: widget.onDeconnexion,
      ),
    ];

    return StructureEspace(
      titreEspace: 'Espace Secrétaire',
      nomUtilisateur: widget.secretaire.nomComplet,
      initialesUser: initiales(
        widget.secretaire.prenom,
        widget.secretaire.nom,
      ),
      photoUser: _photo,
      indexActif: _ongletActif,
      onChoisirOnglet: (index) => setState(() => _ongletActif = index),
      libelles: const [
        'Accueil',
        'Patients',
        'Rendez-vous',
        'Horaires',
        'Profil',
      ],
      onglets: onglets,
    );
  }
}
