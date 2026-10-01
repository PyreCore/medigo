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
  final List<RendezVous> rendezVousDuJour;
  final int enAttente;
  final int patientsSuivis;

  // Callbacks optionnels transmis plus loin aux écrans enfants.
  // EspaceMedecin ne fait qu'un "relais" : il ne sait pas CE QUE ces
  // fonctions font vraiment (Firestore ou démo), il les fait passer.
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
          // Si le parent n'a pas fourni la fonction, on transmet null
          // (bouton désactivé dans le détail). Sinon, on l'appelle avec
          // le "rdv" concerné au moment du clic.
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
    final onglets = [
      AccueilMedecin(
        medecin: widget.medecin,
        photoUrl: _photo,
        rendezVousDuJour: widget.rendezVousDuJour,
        enAttente: widget.enAttente,
        patientsSuivis: widget.patientsSuivis,
        onRafraichir: widget.onRafraichir,
        // Changement d'onglet sans nouvelle route : setState redessine.
        onVoirTout: () => setState(() => _ongletActif = 1),
        onVoirPlanning: () => setState(() => _ongletActif = 2),
        onTapRendezVous: _ouvrirDetailRdv,
      ),
      ListeRendezVousMedecin(
        rendezVous: widget.rendezVousDuJour,
        onTapRendezVous: _ouvrirDetailRdv,
      ),
      const DisponibilitesMedecin(),
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
