import 'package:flutter/material.dart';
import '../../models/secretaire.dart';
import '../../models/patient.dart';
import '../../models/medecin.dart';
import '../../models/rendez_vous.dart';
import 'accueil_secretaire.dart';
import 'liste_patients_secretaire.dart';
import 'enregistrement_patient_secretaire.dart';
import 'liste_rendez_vous_secretaire.dart';
import 'detail_rendez_vous_secretaire.dart';
import 'programmer_rendez_vous_secretaire.dart';
import 'profil_secretaire.dart';

/// Écran principal de l'espace Secrétaire : gère la barre de navigation
/// en bas et bascule entre les 4 onglets (Accueil, Patients, Rendez-vous,
/// Profil). Même structure que EspaceMedecin, pour rester cohérent.
class EspaceSecretaire extends StatefulWidget {
  final Secretaire secretaire;
  final List<Patient> patients;
  final List<Medecin> medecins; // médecins de l'hôpital, pour programmer un RDV
  final List<RendezVous> rendezVousDuJour;
  final Map<String, int> statistiques;

  // Callbacks transmis par le parent : EspaceSecretaire ne fait que les
  // relayer aux bons écrans, sans savoir s'ils parlent à Firestore ou
  // juste à des données de démo en mémoire.
  final void Function({
    required String nom,
    required String prenom,
    required String telephone,
    String? groupeSanguin,
  })? onEnregistrerPatient;

  final void Function({
    required Patient patient,
    required Medecin medecin,
    required DateTime date,
    required String heure,
    String? motif,
  })? onProgrammerRendezVous;

  final Future<void> Function(RendezVous rdv)? onConfirmerRendezVous;
  final Future<void> Function(RendezVous rdv)? onAnnulerRendezVous;
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
    this.onDeconnexion,
  });

  @override
  State<EspaceSecretaire> createState() => _EspaceSecretaireState();
}

class _EspaceSecretaireState extends State<EspaceSecretaire> {
  // 0 = Accueil, 1 = Patients, 2 = Rendez-vous, 3 = Profil.
  int _ongletActif = 0;

  static const _titres = ['Espace Secrétaire', 'Patients', 'Rendez-vous', 'Profil'];

  // Ouvre le détail d'un rendez-vous par-dessus l'écran actuel.
  void _ouvrirDetailRdv(RendezVous rdv) {
    Navigator.push(
      context,
      MaterialPageRoute(
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
        ),
      ),
    );
  }

  // Ouvre le formulaire d'enregistrement d'un nouveau patient.
  void _ouvrirEnregistrementPatient() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnregistrementPatientSecretaire(
          onValider: ({
            required nom,
            required prenom,
            required telephone,
            groupeSanguin,
          }) {
            widget.onEnregistrerPatient?.call(
              nom: nom,
              prenom: prenom,
              telephone: telephone,
              groupeSanguin: groupeSanguin,
            );
            // On revient à l'écran précédent (liste des patients) une
            // fois le formulaire validé.
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // Ouvre le formulaire pour programmer un nouveau rendez-vous.
  void _ouvrirProgrammationRdv() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProgrammerRendezVousSecretaire(
          patients: widget.patients,
          medecins: widget.medecins,
          onValider: ({
            required patient,
            required medecin,
            required date,
            required heure,
            motif,
          }) {
            widget.onProgrammerRendezVous?.call(
              patient: patient,
              medecin: medecin,
              date: date,
              heure: heure,
              motif: motif,
            );
            Navigator.pop(context);
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
        rendezVousDuJour: widget.rendezVousDuJour,
        statistiques: widget.statistiques,
        onTapRendezVous: _ouvrirDetailRdv,
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
      ProfilSecretaire(
        secretaire: widget.secretaire,
        onDeconnexion: widget.onDeconnexion,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(title: Text(_titres[_ongletActif])),
      body: IndexedStack(index: _ongletActif, children: onglets),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _ongletActif,
        onDestinationSelected: (index) =>
            setState(() => _ongletActif = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Rendez-vous',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
