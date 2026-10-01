// Un "enum" (énumération) est une liste fermée de valeurs possibles.
// Ici, un rendez-vous ne peut avoir QUE l'un de ces 5 statuts, jamais
// autre chose. C'est plus sûr qu'utiliser un simple String
// (avec un String on pourrait écrire "cnofirme" par erreur, ça compilerait
// quand même ; avec un enum, une faute de frappe est repérée par Dart
// avant même d'exécuter le code).
enum StatutRendezVous { enAttente, confirme, refuse, annule, termine }

// Firestore stocke le statut sous forme de texte (String), ex: "en_attente".
// Cette fonction convertit ce texte en valeur de notre enum StatutRendezVous.
// On dit qu'elle "parse" (interprète) le texte.
StatutRendezVous statutFromString(String value) {
  // "switch" compare "value" à chaque "case" les uns après les autres.
  switch (value) {
    case 'en_attente':
      // "return" arrête la fonction ici et renvoie cette valeur.
      return StatutRendezVous.enAttente;
    case 'confirme':
      return StatutRendezVous.confirme;
    case 'refuse':
      return StatutRendezVous.refuse;
    case 'annule':
      return StatutRendezVous.annule;
    case 'termine':
      return StatutRendezVous.termine;
    // "default" = si aucun des cas au-dessus ne correspond (texte inconnu
    // ou inattendu venant de Firestore), on retombe sur "enAttente" par
    // sécurité plutôt que de planter l'application.
    default:
      return StatutRendezVous.enAttente;
  }
}

// Classe qui représente un rendez-vous médical (un objet = un rendez-vous).
class RendezVous {
  final String id; // identifiant unique du rendez-vous (id du doc Firestore)
  final String patientNom; // nom de famille du patient
  final String patientPrenom; // prénom du patient
  final DateTime date; // date complète du rendez-vous (jour/mois/année/heure)
  final String heure; // heure affichée telle quelle, ex: "09:00"
  final StatutRendezVous statut; // état actuel du rendez-vous (voir l'enum au-dessus)

  // "?" = optionnel/nullable : un rendez-vous n'a pas toujours de motif renseigné.
  final String? motif;

  // Champs ajoutés pour la partie secrétaire : elle gère les rendez-vous
  // de PLUSIEURS médecins d'un même hôpital, elle a donc besoin de savoir
  // à quel médecin et à quel hôpital chaque rendez-vous appartient.
  // Ils sont nullable (String?) et donc PAS "required" dans le constructeur
  // en dessous : ça évite de casser le code déjà écrit côté médecin, qui
  // crée des RendezVous sans jamais fournir ces champs.
  final String? medecinId;
  final String? medecinNom;
  final String? hopitalId;

  // Constructeur classique : tous les champs sont obligatoires sauf ceux
  // marqués "?" (motif, medecinId, medecinNom, hopitalId).
  RendezVous({
    required this.id,
    required this.patientNom,
    required this.patientPrenom,
    required this.date,
    required this.heure,
    required this.statut,
    this.motif, // pas de "required" car nullable
    this.medecinId,
    this.medecinNom,
    this.hopitalId,
  });

  // Getter pratique : au lieu d'écrire "${rdv.patientPrenom} ${rdv.patientNom}"
  // partout dans les écrans, on écrit juste "rdv.patientNomComplet".
  // Le "$" dans une chaîne de caractères insère la valeur de la variable.
  String get patientNomComplet => '$patientPrenom $patientNom';

  /// L'instant RÉEL du rendez-vous, date ET heure réunies.
  ///
  /// Firestore stocke le jour dans "date" (un Timestamp pris à minuit, issu du
  /// sélecteur de date) et l'heure à part dans "heure" ("09:30"). Un
  /// rendez-vous de 14h est donc enregistré avec date = 14/09 00:00 et
  /// heure = "14:00".
  ///
  /// Consulter `rdv.date` seul donne donc minuit, ce qui est faux de 24 h
  /// pour tout ce qui doit raisonner sur l'heure du rendez-vous : Programmer
  /// un rappel, trier par ordre chronologique, décider si c'est déjà passé.
  /// Ce getter est le seul endroit où cette recomposition doit être écrite.
  DateTime get dateHeure {
    final morceaux = heure.split(':');
    final h = morceaux.isNotEmpty ? (int.tryParse(morceaux[0]) ?? 0) : 0;
    final m = morceaux.length > 1 ? (int.tryParse(morceaux[1]) ?? 0) : 0;
    return DateTime(date.year, date.month, date.day, h, m);
  }

  /// Le patient peut-il encore annuler ou reprogrammer ce rendez-vous ?
  ///
  /// RÈGLE MÉTIER : la main reste au patient tant que la secrétaire (ou le
  /// médecin) n'a pas confirmé. Passé "confirme", l'horaire est réservé par
  /// l'hôpital : le patient ne peut plus l'annuler ni le déplacer seul, il
  /// doit passer par la secrétaire. La même règle vaut pour l'annulation et
  /// la reprogrammation — on ne peut pas laisser un patient annuler un RDV
  /// confirmé pendant qu'il pourrait encore le décaler.
  ///
  /// Un rendez-vous passé n'est plus modifiable dans tous les cas : c'est un
  /// document d'archive.
  ///
  /// Cette règle est écrite ICI, et pas dupliquée dans les écrans et les
  /// services, parce que c'est le seul endroit où les trois doivent
  /// nécessairement être d'accord.
  bool get modifiableParPatient =>
      statut == StatutRendezVous.enAttente && dateHeure.isAfter(DateTime.now());

  // Constructeur nommé qui transforme les données brutes Firestore
  // (un Map, comme un objet JSON) en vrai objet RendezVous Dart.
  factory RendezVous.fromJson(Map<String, dynamic> json) {
    return RendezVous(
      id: json['id'].toString(),

      // "??" = valeur par défaut si le champ est absent/null dans Firestore.
      patientNom: json['patient_nom'] ?? '',
      patientPrenom: json['patient_prenom'] ?? '',

      // DateTime.parse() transforme un texte au format ISO
      // (ex: "2026-09-17T09:00:00.000") en un vrai objet DateTime utilisable.
      date: DateTime.parse(json['date']),

      heure: json['heure'] ?? '',

      // On appelle la fonction définie plus haut pour convertir le texte
      // du statut ("confirme", "refuse"...) en valeur de l'enum.
      statut: statutFromString(json['statut'] ?? 'en_attente'),

      // Pas de "?? ''" : motif reste null si absent, ce qui est normal
      // puisque le champ est déclaré nullable (String?) au-dessus.
      motif: json['motif'],

      // Même logique : ces 3 champs restent null si absents du Map,
      // ce qui est normal quand c'est le médecin qui charge ses propres
      // rendez-vous (il n'a pas besoin de ces infos, il les connaît déjà).
      medecinId: json['medecin_id']?.toString(),
      medecinNom: json['medecin_nom'],
      hopitalId: json['hopital_id']?.toString(),
    );
  }
}
