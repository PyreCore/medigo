// Cette classe représente un "patient" dans l'application.
// C'est un simple conteneur de données (un "modèle"), utilisé notamment
// quand la secrétaire enregistre un nouveau patient à l'accueil.
class Patient {
  final String id; // identifiant unique du patient (id du document Firestore)
  final String nom; // nom de famille du patient
  final String prenom; // prénom du patient

  // DateTime? : la date de naissance est nullable, car elle peut ne pas
  // être connue immédiatement lors d'un premier enregistrement rapide.
  final DateTime? dateNaissance;

  final String telephone; // numéro de téléphone du patient
  final String? groupeSanguin; // optionnel, ex: "O+", peut être inconnu

  final String hopitalId; // hôpital où ce patient a été enregistré

  // Constructeur : tous les champs sont obligatoires sauf ceux marqués "?"
  // (dateNaissance et groupeSanguin), qui restent optionnels.
  Patient({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.hopitalId,
    this.dateNaissance,
    this.groupeSanguin,
  });

  // Getter pratique, comme pour Medecin.nomComplet : évite de répéter
  // "${patient.prenom} ${patient.nom}" partout dans les écrans.
  String get nomComplet => '$prenom $nom';

  // Constructeur nommé qui transforme les données brutes Firestore
  // (un Map, comme un objet JSON) en vrai objet Patient Dart.
  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'].toString(),
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      telephone: json['telephone'] ?? '',
      hopitalId: json['hopital_id'].toString(),

      // On ne convertit la date que si elle existe (le champ peut être
      // absent si la secrétaire n'a pas encore renseigné cette info).
      // "json['date_naissance'] != null ? ... : null" est un opérateur
      // ternaire : "si condition, alors valeur1, sinon valeur2".
      dateNaissance: json['date_naissance'] != null
          ? DateTime.parse(json['date_naissance'])
          : null,

      groupeSanguin: json['groupe_sanguin'],
    );
  }
}
