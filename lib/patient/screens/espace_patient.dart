import 'package:flutter/material.dart';
import '../../models/medecin.dart';
import '../../models/patient.dart';
import '../../models/rendez_vous.dart';
import '../../shared/models/hopital_model.dart';
import 'accueil_patient.dart';
import 'liste_rendez_vous_patient.dart';
import 'detail_rendez_vous_patient.dart';
import 'prendre_rendez_vous_patient.dart';
import 'profil_patient.dart';

/// Écran principal de l'espace Patient : gère la barre de navigation en
/// bas et bascule entre les 4 onglets (Accueil, Mes rendez-vous, Prendre
/// rendez-vous, Profil). Même structure que EspaceMedecin et
/// EspaceSecretaire, pour rester cohérente avec le reste de l'application.
class EspacePatient extends StatefulWidget {
  final Patient patient;

  // Hôpitaux partenaires : c'est le catalogue que le formulaire de
  // réservation propose en premier. Les médecins et spécialités, eux,
  // dépendent de l'hôpital choisi et sont chargés par le formulaire.
  final List<Hopital> hopitaux;

  final List<RendezVous> rendezVous; // tous les rendez-vous du patient
  final List<RendezVous> rendezVousDuJour; // sous-ensemble pour l'accueil
  final Map<String, int> statistiques;

  // Callbacks transmis par le parent : EspacePatient ne fait que les
  // relayer aux bons écrans, sans savoir s'ils parlent à Firestore ou
  // à des données de démo en mémoire.
  final Future<void> Function()? onRafraichir;
  final Future<void> Function({
    required Medecin medecin,
    required DateTime date,
    required String heure,
    String? motif,
  })? onDemanderRendezVous;
  final Future<void> Function(RendezVous rdv)? onAnnulerRendezVous;
  final Future<void> Function(RendezVous rdv, DateTime date, String heure, String? motif)?
  onModifierRendezVous;

  // Appelé par EspacePatient après une reprogrammation réussie, pour
  // quitté le mode édition du formulaire. Le loader recharge les données
  // dans la foulée.
  final VoidCallback? onFinModification;
  final VoidCallback? onDeconnexion;

  const EspacePatient({
    super.key,
    required this.patient,
    required this.hopitaux,
    required this.rendezVous,
    required this.rendezVousDuJour,
    this.statistiques = const {},
    this.onRafraichir,
    this.onDemanderRendezVous,
    this.onAnnulerRendezVous,
    this.onModifierRendezVous,
    this.onFinModification,
    this.onDeconnexion,
  });

  @override
  State<EspacePatient> createState() => _EspacePatientState();
}

class _EspacePatientState extends State<EspacePatient> {
  // Index de l'onglet actuellement affiché : 0 = Accueil,
  // 1 = Mes rendez-vous, 2 = Prendre rendez-vous, 3 = Profil.
  int _ongletActif = 0;

  // Rendez-vous en cours de reprogrammation, non null = le formulaire de
  // l'onglet 2 est en mode édition. Mémorisé ici (et non dans le formulaire)
  // parce que c'est l'onglet qui doit décider du mode, et qu'il doit pouvoir
  // l'annuler si le patient renonce et repasse par un nouveau rendez-vous.
  RendezVous? _rdvAModifier;

  static const _titres = [
    'Espace Patient',
    'Mes rendez-vous',
    'Prendre rendez-vous',
    'Profil',
  ];

  // Ouvre le détail d'un rendez-vous par-dessus l'écran actuel. Comme le
  // parent expose onAnnulerRendezVous sous la forme (rdv) alors que le
  // détail l'appelle sans argument, on referme ici la parenthèse.
  void _ouvrirDetailRdv(RendezVous rdv) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailRendezVousPatient(
          rdv: rdv,
          onAnnuler: widget.onAnnulerRendezVous == null
              ? null
              : () => widget.onAnnulerRendezVous!(rdv),
          // "Modifier" ne ouvre pas un écran : on bascule sur l'onglet du
          // formulaire en le passant en mode édition. Le détail se referme
          // pour ne pas laisser une copie de l'ancien rendez-vous sous le
          // formulaire.
          onModifier: widget.onModifierRendezVous == null
              ? null
              : () {
                  Navigator.pop(context);
                  setState(() {
                    _rdvAModifier = rdv;
                    _ongletActif = 2;
                  });
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onglets = [
      AccueilPatient(
        patient: widget.patient,
        rendezVousDuJour: widget.rendezVousDuJour,
        statistiques: widget.statistiques,
        onVoirTout: () => setState(() => _ongletActif = 1),
        // Prendre rendez-vous depuis l'accueil remet le formulaire en mode
        // création : sans cela, un ancien rendez-vous en attente de
        // reprogrammation continuerait de pré-remplir le formulaire.
        onPrendreRendezVous: () => setState(() {
          _rdvAModifier = null;
          _ongletActif = 2;
        }),
        onTapRendezVous: _ouvrirDetailRdv,
        onRafraichir: widget.onRafraichir,
      ),
      ListeRendezVousPatient(
        rendezVous: widget.rendezVous,
        onTapRendezVous: _ouvrirDetailRdv,
        onNouveauRendezVous: () => setState(() {
          _rdvAModifier = null;
          _ongletActif = 2;
        }),
      ),
      PrendreRendezVousPatient(
        hopitaux: widget.hopitaux,
        // La clé force Flutter à reconstruire le formulaire quand on passe
        // d'un rendez-vous à un autre (ou à une création) : sans elle, le
        // State du formulaire garderait l'ancien pré-remplissage.
        key: ValueKey(
          _rdvAModifier == null
              ? 'nouveau'
              : 'modif-${_rdvAModifier!.id}',
        ),
        rendezVousAModifier: _rdvAModifier,
        onValider: widget.onDemanderRendezVous == null
            ? null
            : ({
                required medecin,
                required date,
                required heure,
                motif,
              }) {
                widget.onDemanderRendezVous!(
                  medecin: medecin,
                  date: date,
                  heure: heure,
                  motif: motif,
                );
                // On ramène sur l'accueil : c'est là que le patient voit
                // sa nouvelle demande (le loader a rafraîchi les données
                // entre-temps). Sans ça, il resterait sur un formulaire
                // vide et croirait que l'envoi a échoué.
                setState(() => _ongletActif = 0);
              },
        onValiderModification:
            widget.onModifierRendezVous == null || _rdvAModifier == null
            ? null
            : ({required date, required heure, motif}) {
                final rdv = _rdvAModifier!;
                widget.onModifierRendezVous!(rdv, date, heure, motif);
                setState(() {
                  _rdvAModifier = null;
                  _ongletActif = 0;
                });
                widget.onFinModification?.call();
              },
      ),
      ProfilPatient(
        patient: widget.patient,
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
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Mes RDV',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Prendre RDV',
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
