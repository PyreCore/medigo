import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/disponibilite.dart';

/// Accès Firestore aux disponibilités déclarées par les médecins.
///
/// Collection "disponibilites", un document par plage horaire
/// hebdomadaire (voir models/disponibilite.dart pour le schéma exact).
///
/// Toutes les requêtes utilisent UN SEUL filtre d'égalité sur "medecinId" :
/// conformément à la contrainte documentée dans MedecinService
/// (sans index composite dans la console Firebase, Firestore répond
/// failed-precondition et bloque l'écran), on s'interdit tout "where" second.
/// Le filtrage par jour se fait donc en Dart.
class DisponibiliteService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Toutes les plages d'un médecin, triées par jour puis par heure de
  /// début. Les plages inactives sont renvoyées aussi : l'écran du médecin
  /// doit pouvoir afficher une plage qu'il a désactivée, sinon il ne
  /// pourrait jamais la réactiver.
  Future<List<Disponibilite>> getDisponibilites(String medecinId) async {
    final snapshot = await _db
        .collection('disponibilites')
        .where('medecinId', isEqualTo: medecinId)
        .get();

    final liste = snapshot.docs
        .map((doc) => Disponibilite.fromJson({'id': doc.id, ...doc.data()}))
        .toList();

    liste.sort((a, b) {
      if (a.jour != b.jour) return a.jour.compareTo(b.jour);
      return a.heureDebut.compareTo(b.heureDebut);
    });
    return liste;
  }

  /// Les plages actives d'un médecin pour un jour de semaine donné
  /// (1 = lundi … 7 = dimanche).
  static List<Disponibilite> pourJour(
    List<Disponibilite> toutes,
    int jour,
  ) {
    return toutes.where((d) => d.actif && d.jour == jour).toList();
  }

  /// Enregistre une plage. Si [id] est fourni, la plage est modifiée, sinon
  /// une nouvelle est créée.
  ///
  /// Renvoyer l'id du document créé est nécessaire : l'écran du médecin
  /// recharge la liste après chaque écriture et a besoin de cet id pour
  /// pouvoir modifier ou supprimer la plage qu'il vient de créer.
  Future<String> enregistrer(Disponibilite disponibilite) async {
    if (disponibilite.id.isEmpty) {
      final ref = await _db
          .collection('disponibilites')
          .add(disponibilite.toMap());
      return ref.id;
    }

    await _db
        .collection('disponibilites')
        .doc(disponibilite.id)
        .update(disponibilite.toMap());
    return disponibilite.id;
  }

  Future<void> supprimer(String id) async {
    await _db.collection('disponibilites').doc(id).delete();
  }

  /// Créneaux qu'un patient peut réellement choisir pour une date donnée.
  ///
  /// [dureeMinutes] est la longueur d'une consultation (30 par défaut).
  /// [heuresOccupees] contient les heures déjà prises ce jour-là : le
  /// créneau exact est retiré, et on n'affiche un créneau que s'il ne
  /// chevauche pas un créneau déjà pris (un rendez-vous de 09:00 à 09:45
  /// bloque 09:00 ET 09:30).
  static List<String> creneauxDisponibles({
    required List<Disponibilite> disponibilites,
    required String date, // "AAAA-MM-JJ", pour l'affichage
    required List<String> heuresOccupees,
    int dureeMinutes = 30,
  }) {
    final bloques = <String, int>{};
    for (final h in heuresOccupees) {
      final minutes = _minutes(h);
      if (minutes != null) bloques[h] = minutes;
    }

    final creneaux = <String>{};
    for (final plage in disponibilites.where((d) => d.actif)) {
      for (final creneau in plage.creneaux(dureeMinutes)) {
        final debut = _minutes(creneau)!;
        final fin = debut + dureeMinutes;

        // Le créneau est libre si aucune plage déjà occupée ne le recoupe.
        final chevauche = bloques.values.any(
          (debutOccupe) => debutOccupe < fin && debut < debutOccupe + dureeMinutes,
        );
        if (!chevauche) creneaux.add(creneau);
      }
    }

    final liste = creneaux.toList()..sort();
    return liste;
  }

  /// Les jours (1 = lundi … 7 = dimanche) pour lesquels le médecin a au
  /// moins une plage active. Permet d'afficher uniquement les jours
  /// ouvrables au lieu des sept.
  static List<int> joursOuverts(List<Disponibilite> disponibilites) {
    final jours = <int>{};
    for (final d in disponibilites) {
      if (d.actif) jours.add(d.jour);
    }
    return jours.toList()..sort();
  }

  static int? _minutes(String hhmm) {
    final morceaux = hhmm.split(':');
    if (morceaux.length < 2) return null;
    final h = int.tryParse(morceaux[0]);
    final m = int.tryParse(morceaux[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }
}
