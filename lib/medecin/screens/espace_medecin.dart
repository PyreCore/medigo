import 'package:flutter/material.dart';
import '../../models/medecin.dart';
import '../../models/rendez_vous.dart';
import '../../widgets/structure_espace.dart';
import '../../widgets/ui_kit.dart';
import 'accueil_medecin.dart';
import 'detail_rendez_vous_medecin.dart';
import 'disponibilites_medecin.dart';
import 'liste_rendez_vous_medecin.dart';
import 'profil_medecin.dart';

/// Écran principal de l'espace Médecin.
/// La COQUILLE (navigation rail sur web, barre basse sur mobile,
/// en-tête de page, largeur maximale du contenu) est fournie par
/// StructureEspace ; ici on ne gère que :
///  · l'onglet actif,
///  · la photo à jour (modifiable depuis l'onglet Profil),
///  · l'ouverture du détail d'un rendez-vous par-dessus l'espace.
class EspaceMedecin extends StatefulWidget {
  // Toutes les données reçues "d'en haut" (via le chargeur d'écran).
  final Medecin medecin;

  /// Rendez-vous visibles du médecin (CONFIRMÉS et TERMINÉS seulement) :
  /// le chargeur applique la règle d'affichage avant de les transmettre.
  final List<RendezVous> rendezVousDuJour;
  final int patientsSuivis;

  // Callbacks optionnels transmis plus loin aux écrans enfants.
  // EspaceMedecin ne fait qu'un "relais" : il ne sait pas CE QUE ces
  // fonctions font vraiment (Firestore ou démo), il les fait passer.
  final Future<void> Function()? onRafraichir;

  /// Passe un rendez-vous confirmé au statut « terminé ».
  final Future<void> Function(RendezVous rdv)? onTerminerRendezVous;

  /// Marque la consultation comme NON terminée (statut « terminé » +
  /// drapeau consultationTerminee = false côté service).
  final Future<void> Function(RendezVous rdv)? onNonTermineRendezVous;

  /// Ids des consultations marquées « non terminées » (statut terminé +
  /// drapeau) : les écrans affichent « Non terminé » en style neutre.
  final Set<String> idsNonTermines;

  /// Bannière « Nouveau rendez-vous » de l'accueil (détectée par le
  /// chargeur toutes les 5 s), et son rappel de fermeture.
  final ({String titre, String sousTitre})? notificationRdv;
  final VoidCallback? onFermerNotificationRdv;

  final VoidCallback? onDeconnexion;

  const EspaceMedecin({
    super.key,
    required this.medecin,
    required this.rendezVousDuJour,
    this.patientsSuivis = 0,
    this.idsNonTermines = const {},
    this.notificationRdv,
    this.onFermerNotificationRdv,
    this.onRafraichir,
    this.onTerminerRendezVous,
    this.onNonTermineRendezVous,
    this.onDeconnexion,
  });

  @override
  State<EspaceMedecin> createState() => _EspaceMedecinState();
}

class _EspaceMedecinState extends State<EspaceMedecin> {
  // 0 = Accueil, 1 = Rendez-vous, 2 = Disponibilités, 3 = Profil.
  int _ongletActif = 0;

  // Photo de profil à jour. null = pas encore modifiée dans cette
  // session : on lit alors celle du modèle (voir getter ci-dessous).
  String? _photoModifiee;

  // Photo affichée partout (rail, accueil, profil).
  String? get _photo => _photoModifiee ?? widget.medecin.photoUrl;

  // Ouvre l'écran de détail d'un rendez-vous PAR-DESSUS l'espace
  // (Navigator.push : pile d'écrans, bouton retour automatique).
  void _ouvrirDetailRdv(RendezVous rdv) {
    Navigator.push(
      context,
      // Transition premium (fondu + glissement) plutôt que Material.
      routeMedigo(
        builder: (_) => DetailRendezVousMedecin(
          rdv: rdv,
          // Spécialité du médecin connecté : affichée dans le sous-titre
          // de la carte patient (« Consultation de suivi · Cardiologie »).
          specialiteMedecin: widget.medecin.specialite,
          // Déjà marquée « non terminée » ? Le pied affiche alors un
          // bloc neutre au lieu des boutons Terminer / Non terminé.
          consultationNonTerminee:
              widget.idsNonTermines.contains(rdv.id),
          // Si le parent n'a pas fourni la fonction, on transmet null
          // (bouton désactivé dans le détail). Sinon, on l'appelle avec
          // le "rdv" concerné au moment du clic.
          onTerminer: widget.onTerminerRendezVous == null
              ? null
              : () => widget.onTerminerRendezVous!(rdv),
          onNonTermine: widget.onNonTermineRendezVous == null
              ? null
              : () => widget.onNonTermineRendezVous!(rdv),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onglets = [
      AccueilMedecin(
        medecin: widget.medecin,
        photoUrl: _photo,
        rendezVousDuJour: widget.rendezVousDuJour,
        patientsSuivis: widget.patientsSuivis,
        idsNonTermines: widget.idsNonTermines,
        notificationRdv: widget.notificationRdv,
        onFermerNotificationRdv: widget.onFermerNotificationRdv,
        onRafraichir: widget.onRafraichir,
        // Changement d'onglet sans nouvelle route : setState redessine.
        onVoirTout: () => setState(() => _ongletActif = 1),
        onVoirPlanning: () => setState(() => _ongletActif = 2),
        onTapRendezVous: _ouvrirDetailRdv,
      ),
      ListeRendezVousMedecin(
        rendezVous: widget.rendezVousDuJour,
        idsNonTermines: widget.idsNonTermines,
        onTapRendezVous: _ouvrirDetailRdv,
      ),
      // L'onglet Disponibilités a besoin de l'identité du médecin pour lire
      // et écrire ses plages dans Firestore.
      DisponibilitesMedecin(medecin: widget.medecin),
      ProfilMedecin(
        medecin: widget.medecin,
        photoUrl: _photo,
        // Quand le profil change la photo, on la stocke ici : le rail,
        // l'accueil et le profil affichent tous la nouvelle valeur.
        onPhotoChange: (url) => setState(() => _photoModifiee = url),
        onDeconnexion: widget.onDeconnexion,
      ),
    ];

    return StructureEspace(
      titreEspace: 'Espace Médecin',
      nomUtilisateur: widget.medecin.nomComplet,
      initialesUser: initiales(widget.medecin.prenom, widget.medecin.nom),
      photoUser: _photo,
      indexActif: _ongletActif,
      onChoisirOnglet: (index) => setState(() => _ongletActif = index),
      libelles: const ['Accueil', 'Rendez-vous', 'Disponibilités', 'Profil'],
      onglets: onglets,
    );
  }
}
