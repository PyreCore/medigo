import '../models/medecin.dart';
import '../shared/models/hopital_model.dart';

/// Réservation commencée en mode visiteur, gardée en mémoire le temps que
/// le visiteur se connecte ou crée son compte.
///
/// Le visiteur remplit le formulaire, appuie sur « Envoyer ma demande »,
/// et la connexion lui est demandée. Sans ce brouillon, il arriverait dans
/// son espace avec un formulaire vide et devrait tout refaire. Ici,
/// PatientHomeLoader le reprend et rouvre le formulaire pré-rempli : le
/// patient vérifie et envoie.
///
/// Le brouillon vit en mémoire seulement (une variable statique) : il ne
/// survit pas à la fermeture de l'application, ce qui est voulu — un
/// rendez-vous choisi la veille n'a plus de raison d'être repris. Il expire
/// aussi après [dureeValidite], pour qu'un téléphone partagé ne propose
/// pas au compte suivant la réservation d'un autre.
///
/// Rien ne passe par l'écran de connexion : PatientHomeLoader, ouvert après
/// la connexion comme après l'inscription d'un patient, est le seul à le
/// lire.
class ReservationEnAttente {
  final Hopital hopital;
  final Medecin medecin;
  final DateTime date;
  final String heure;
  final String? motif;
  final DateTime creeLe;

  ReservationEnAttente({
    required this.hopital,
    required this.medecin,
    required this.date,
    required this.heure,
    this.motif,
    DateTime? creeLe,
  }) : creeLe = creeLe ?? DateTime.now();

  static const dureeValidite = Duration(minutes: 30);

  static ReservationEnAttente? _enAttente;

  /// Mémorise la réservation du visiteur (remplace la précédente).
  static void garder(ReservationEnAttente reservation) {
    _enAttente = reservation;
  }

  /// Oublie la réservation (le visiteur a répondu « Plus tard »).
  static void oublier() {
    _enAttente = null;
  }

  /// Rend la réservation en attente et l'efface : elle n'est reprise
  /// qu'UNE fois. Renvoie null si aucune, ou si elle a expiré.
  static ReservationEnAttente? reprendre({DateTime? maintenant}) {
    final reservation = _enAttente;
    _enAttente = null;
    if (reservation == null) return null;
    final age = (maintenant ?? DateTime.now()).difference(reservation.creeLe);
    return age > dureeValidite ? null : reservation;
  }
}
