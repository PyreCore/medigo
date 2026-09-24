import 'package:flutter/material.dart';
import '../../models/medecin.dart';
import '../../models/rendez_vous.dart';
import 'accueil_medecin.dart';
import 'detail_rendez_vous_medecin.dart';
import 'disponibilites_medecin.dart';
import 'liste_rendez_vous_medecin.dart';
import 'profil_medecin.dart';

/// Écran principal de l'espace Médecin : gère la barre de navigation
/// en bas et bascule entre les 4 onglets (Accueil, Rendez-vous,
/// Disponibilités, Profil).
// StatefulWidget car cet écran doit RETENIR quel onglet est actuellement
// sélectionné (_ongletActif ci-dessous), une info qui change quand
// l'utilisateur tape sur la barre de navigation.
class EspaceMedecin extends StatefulWidget {
  // Toutes les données reçues "d'en haut" (de main.dart pour l'instant,
  // bientôt directement de Firestore via MedecinService).
  final Medecin medecin;
  final List<RendezVous> rendezVousDuJour;
  final int enAttente;
  final int patientsSuivis;

  // Callbacks optionnels transmis plus loin aux écrans enfants (Accueil,
  // Détail...). EspaceMedecin ne fait qu'un "relais" : il ne sait pas
  // CE QUE ces fonctions font vraiment (Firestore ou juste une démo en
  // mémoire), il se contente de les faire passer aux bons endroits.
  final Future<void> Function()? onRafraichir;
  final Future<void> Function(RendezVous rdv)? onAccepterRendezVous;
  final Future<void> Function(RendezVous rdv)? onRefuserRendezVous;
  final VoidCallback? onDeconnexion;

  const EspaceMedecin({
    super.key,
    required this.medecin,
    required this.rendezVousDuJour,
    this.enAttente = 0,
    this.patientsSuivis = 0,
    this.onRafraichir,
    this.onAccepterRendezVous,
    this.onRefuserRendezVous,
    this.onDeconnexion,
  });

  @override
  State<EspaceMedecin> createState() => _EspaceMedecinState();
}

// La classe State associée, qui contient la mémoire (quel onglet est actif).
class _EspaceMedecinState extends State<EspaceMedecin> {
  // Index de l'onglet actuellement affiché : 0 = Accueil, 1 = Rendez-vous,
  // 2 = Disponibilités, 3 = Profil. On démarre sur Accueil (0).
  int _ongletActif = 0;

  // Liste "statique" (const, partagée par toutes les instances de cette
  // classe, calculée une seule fois) des titres affichés dans l'AppBar
  // selon l'onglet actif. L'ordre doit correspondre à l'ordre des
  // NavigationDestination plus bas (index 0 = 'Espace Médecin', etc.).
  static const _titres = [
    'Espace Médecin',
    'Rendez-vous',
    'Disponibilités',
    'Profil',
  ];

  // Méthode privée (pas de "build", donc pas appelée automatiquement par
  // Flutter — on l'appelle nous-mêmes quand on tape sur un rendez-vous)
  // qui ouvre l'écran de détail PAR-DESSUS l'écran actuel.
  void _ouvrirDetailRdv(RendezVous rdv) {
    // Navigator.push ajoute un nouvel écran "au-dessus" de la pile de
    // navigation (comme empiler une nouvelle carte sur un jeu de cartes) ;
    // un bouton "retour" apparaît automatiquement pour revenir en arrière.
    Navigator.push(
      context,
      // MaterialPageRoute définit la transition (glissement depuis la
      // droite, typique Android/Material) et le widget à afficher.
      MaterialPageRoute(
        builder: (_) => DetailRendezVousMedecin(
          rdv: rdv,
          // Opérateur ternaire : si le parent n'a pas fourni de fonction
          // onAccepterRendezVous, on transmet "null" (bouton désactivé
          // dans l'écran de détail). Sinon, on transmet une fonction qui,
          // quand on l'appelle SANS argument (voir DetailRendezVousMedecin,
          // qui appelle juste onAccepter!()), va appeler la vraie fonction
          // du parent EN LUI PASSANT ce "rdv" précis.
          onAccepter: widget.onAccepterRendezVous == null
              ? null
              : () => widget.onAccepterRendezVous!(rdv),
          onRefuser: widget.onRefuserRendezVous == null
              ? null
              : () => widget.onRefuserRendezVous!(rdv),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // On construit les 4 onglets à chaque fois que build() est appelé
    // (donc à chaque changement d'onglet, puisque setState() redéclenche
    // build()). Ce n'est pas un souci de performance ici car ce sont des
    // StatelessWidget légers.
    final onglets = [
      AccueilMedecin(
        medecin: widget.medecin,
        rendezVousDuJour: widget.rendezVousDuJour,
        enAttente: widget.enAttente,
        patientsSuivis: widget.patientsSuivis,
        onRafraichir: widget.onRafraichir,
        // Quand on appuie sur "Voir tout" dans l'accueil, on ne navigue
        // pas vers un nouvel écran : on change simplement _ongletActif
        // à 1 (Rendez-vous), et setState() redessine avec le bon onglet.
        onVoirTout: () => setState(() => _ongletActif = 1),
        onTapRendezVous: _ouvrirDetailRdv,
      ),
      ListeRendezVousMedecin(
        rendezVous: widget.rendezVousDuJour,
        onTapRendezVous: _ouvrirDetailRdv,
      ),
      const DisponibilitesMedecin(),
      ProfilMedecin(
        medecin: widget.medecin,
        onDeconnexion: widget.onDeconnexion,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        // On affiche le titre correspondant à l'onglet actif dans la liste
        // _titres définie plus haut.
        title: Text(_titres[_ongletActif]),
        // L'icône de notification (cloche) ne s'affiche QUE sur l'onglet
        // Accueil (index 0) : sur les autres onglets, "actions" vaut null
        // donc rien n'apparaît à droite de l'AppBar.
        actions: _ongletActif == 0
            ? [
                IconButton(
                  icon: const Icon(Icons.notifications_none),
                  onPressed: () {}, // pas encore implémenté
                ),
              ]
            : null,
      ),
      // IndexedStack empile TOUS les onglets les uns sur les autres (dans
      // la mémoire), mais n'affiche QUE celui dont l'index correspond à
      // "index: _ongletActif". L'avantage sur "onglets[_ongletActif]" tout
      // seul : les autres onglets restent construits en arrière-plan, donc
      // si on tape "Rendez-vous" (onglet 1), fait défiler, revient sur
      // "Accueil" (onglet 0), puis retape "Rendez-vous", le défilement de
      // la liste des rendez-vous est CONSERVÉ (pas remis à zéro).
      body: IndexedStack(index: _ongletActif, children: onglets),
      // NavigationBar = la barre du bas façon Material 3, avec les 4 icônes.
      bottomNavigationBar: NavigationBar(
        // Indique quelle icône est actuellement mise en surbrillance.
        selectedIndex: _ongletActif,
        // Appelé automatiquement par Flutter quand l'utilisateur tape
        // sur une des 4 icônes, avec "index" = l'icône tapée (0 à 3).
        onDestinationSelected: (index) =>
            setState(() => _ongletActif = index),
        // La liste des 4 boutons de navigation, dans l'ordre affiché.
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined), // icône quand PAS sélectionné
            selectedIcon: Icon(Icons.home), // icône quand sélectionné (pleine)
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Rendez-vous',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: 'Disponibilités',
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
