import 'package:cloud_firestore/cloud_firestore.dart';

/// Service de la collection "creneaux_occupes".
///
/// Cette collection ne contient QUE des créneaux : quel médecin, quel jour,
/// quelle heure, pour quel rendez-vous. Elle ne porte AUCUNE donnée
/// personnelle (ni nom, ni prénom, ni motif médical).
///
/// Pourquoi elle existe
/// -------------------
/// L'ancien code calculait les heures déjà prises en lisant TOUS les
/// rendez-vous d'un médecin. Pour que la requête passe, il aurait fallu
/// ouvrir aux patients la lecture de toute la collection "rendez_vous",
/// c'est-à-dire leur laisser lire le nom et le motif de consultation de
/// tous les autres patients. Le code ne montrait que les heures, mais la
/// fuite était réelle : elle existait sur le réseau, pas seulement dans
/// l'écran.
///
/// En isolant les créneaux, on n'expose que ce qui est nécessaire pour
/// afficher les heures disponibles, et la collection reste lisible par
/// tout le monde (`allow read: if true` dans firestore.rules).
///
/// Qui peut écrire
/// ---------------
/// Les règles vérifient que le document renvoie bien à un rendez-vous
/// appartenant à l'appelant : impossible de bloquer un créneau qui ne lui
/// appartient pas. Les rôles de gestion (secrétaire, admin d'hôpital,
/// admin système) et le médecin concerné peuvent aussi intervenir, pour
/// libérer un créneau quand un rendez-vous est annulé ou refusé.
class CreneauService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// La clé de jour stockée dans les documents : "2026-09-30".
  ///
  /// Une chaîne plutôt qu'un Timestamp : elle se compare par égalité sans
  /// risque de fuseau horaire, et un index composite sur (medecinId, date)
  /// suffit pour la requête de lecture.
  static String cleJour(DateTime jour) {
    final mois = jour.month.toString().padLeft(2, '0');
    final jourDuMois = jour.day.toString().padLeft(2, '0');
    return '${jour.year}-$mois-$jourDuMois';
  }

  /// Marque un créneau comme occupé par un rendez-vous.
  ///
  /// À appeler juste après la création du rendez-vous : c'est ce couple
  /// d'écritures qui empêche deux patients de prendre la même heure.
  Future<void> reserver({
    required String rdvId,
    required String medecinId,
    required DateTime date,
    required String heure,
  }) async {
    await _db.collection('creneaux_occupes').add({
      'rdvId': rdvId,
      'medecinId': medecinId,
      'date': cleJour(date),
      'heure': heure,
    });
  }

  /// Libère le créneau d'un rendez-vous (annulation, refus, ou
  /// reprogrammation dont on va écrire un nouveau).
  ///
  /// Silencieux par conception : un créneau déjà absent n'a rien à
  /// libérer, et une erreur ici ne doit jamais faire échouer une
  /// annulation qui, elle, a réussi.
  Future<void> liberer(String rdvId) async {
    try {
      final snapshot = await _db
          .collection('creneaux_occupes')
          .where('rdvId', isEqualTo: rdvId)
          .get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (_) {
      // Créneau fantôme éventuel : l'heure restera affichée comme prise,
      // ce qui est le défaut le moins grave des deux.
    }
  }

  /// Déplace l'occupation d'un rendez-vous vers un nouveau créneau.
  Future<void> deplacer({
    required String rdvId,
    required String medecinId,
    required DateTime date,
    required String heure,
  }) async {
    await liberer(rdvId);
    await reserver(
      rdvId: rdvId,
      medecinId: medecinId,
      date: date,
      heure: heure,
    );
  }
}
