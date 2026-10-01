/// Modèle d'une plage de disponibilité déclarée par un médecin.
///
/// SCHÉMA FIRESTORE (collection "disponibilites", un document par plage) :
///
///   medecinId   String   id du document du médecin dans "users" (obligatoire)
///   jour        int      1 = lundi … 7 = dimanche (obligatoire)
///   heureDebut  String   "08:00" (obligatoire)
///   heureFin    String   "16:00" (obligatoire)
///   actif       bool     false = plage désactivée sans être supprimée
///
/// On ne stocke PAS de dates dans ce document : une disponibilité décrit une
/// RÉPÉTITION hebdomadaire ("le mardi, de 8h à 16h"), pas un créneau daté.
/// Les rendez-vous, eux, sont datés et vivent dans "rendez_vous". Ce découplage
/// évite de dupliquer 52 documents par médecin et par an.
class Disponibilite {
  final String id; // id du document Firestore
  final String medecinId;
  final int jour; // 1 (lundi) à 7 (dimanche)
  final String heureDebut; // "08:00"
  final String heureFin; // "16:00"
  final bool actif;

  Disponibilite({
    required this.id,
    required this.medecinId,
    required this.jour,
    required this.heureDebut,
    required this.heureFin,
    this.actif = true,
  });

  /// Noms des jours, indexés à partir de 0 pour l'affichage.
  /// On les stocke en dur plutôt que d'utiliser intl : l'application n'a pas
  /// d'autre besoin de formatage de date localisé, et cela évite d'ajouter une
  /// dépendance pour sept chaînes.
  static const nomsJours = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  /// Abréviations pour l'interface quand la place manque.
  static const nomsJoursCourts = [
    'Lun',
    'Mar',
    'Mer',
    'Jeu',
    'Ven',
    'Sam',
    'Dim',
  ];

  static String nomJour(int jour) {
    if (jour < 1 || jour > 7) return '';
    return nomsJours[jour - 1];
  }

  static String nomJourCourt(int jour) {
    if (jour < 1 || jour > 7) return '';
    return nomsJoursCourts[jour - 1];
  }

  /// Index du jour de la semaine pour une date donnée, dans la même
  /// convention 1 = lundi … 7 = dimanche.
  ///
  /// Dart expose DateTime.weekday avec DÉJÀ cette convention (1 = lundi,
  /// 7 = dimanche) : il n'y a donc rien à convertir. Ajouter "+1" décalait
  /// la recherche d'une disponibilité d'un jour entier.
  static int jourDeLaSemaine(DateTime date) => date.weekday;

  /// Vrai si cette plage couvre l'heure "HH:mm" demandée.
  ///
  /// La comparaison se fait sur les minutes depuis minuit plutôt que sur des
  /// chaînes : "08:00" < "09:00" est vrai en alphabétique, mais "10:00" <
  /// "9:00" est FAUX alors que 10h est bien après 9h.
  static bool couvre(String heureDebut, String heureFin, String heure) {
    final d = _minutes(heureDebut);
    final f = _minutes(heureFin);
    final h = _minutes(heure);
    return h >= d && h < f;
  }

  /// Convertit "HH:mm" en minutes depuis minuit. Renvoie 0 si le format est
  /// inattendu, ce qui fait échouer la comparaison plutôt que de planter
  /// l'écran chez un patient.
  static int _minutes(String hhmm) {
    final morceaux = hhmm.split(':');
    if (morceaux.length < 2) return 0;
    final h = int.tryParse(morceaux[0]);
    final m = int.tryParse(morceaux[1]);
    if (h == null || m == null) return 0;
    return h * 60 + m;
  }

  /// Découpe une plage en créneaux de [dureeMinutes], bornes comprises.
  ///
  /// Exemple : 08:00-16:00 par 30 min → 08:00, 08:30, 09:00 … 15:30.
  /// Le dernier créneau est celui qui COMMENCE avant la fin de la plage, donc
  /// 16:00 n'apparaît pas (le rendez-vous déborderait).
  List<String> creneaux(int dureeMinutes) {
    if (dureeMinutes <= 0) return const [];
    final debut = _minutes(heureDebut);
    final fin = _minutes(heureFin);
    final creneaux = <String>[];
    for (int m = debut; m + dureeMinutes <= fin; m += dureeMinutes) {
      creneaux.add(_versHeure(m));
    }
    return creneaux;
  }

  static String _versHeure(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Affiche la plage de façon compacte : "08:00 - 16:00".
  String get libelle => '$heureDebut - $heureFin';

  factory Disponibilite.fromJson(Map<String, dynamic> json) {
    return Disponibilite(
      id: json['id'].toString(),
      medecinId: json['medecinId']?.toString() ?? '',
      // "??" : un document sans "jour" vaudrait 0 sinon, et nomJour(0)
      // renverrait une chaîne vide en cascade.
      jour: json['jour'] is int ? json['jour'] as int : 0,
      heureDebut: json['heureDebut'] ?? '00:00',
      heureFin: json['heureFin'] ?? '00:00',
      actif: json['actif'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medecinId': medecinId,
      'jour': jour,
      'heureDebut': heureDebut,
      'heureFin': heureFin,
      'actif': actif,
    };
  }
}
