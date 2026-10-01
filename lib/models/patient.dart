// Cette classe représente un "patient" dans l'application.
// C'est un simple conteneur de données (un "modèle"), utilisé par deux
// espaces : celui de la secrétaire (qui enregistre les patients à
// l'accueil) et celui du patient lui-même (auto-inscription).
class Patient {
  final String id; // identifiant unique du patient (id du document Firestore)
  final String nom; // nom de famille du patient
  final String prenom; // prénom du patient

  // DateTime? : la date de naissance est nullable, car elle peut ne pas
  // être connue immédiatement lors d'un premier enregistrement rapide.
  final DateTime? dateNaissance;

  final String telephone; // numéro de téléphone du patient
  final String? groupeSanguin; // optionnel, ex: "O+", peut être inconnu

  // Hôpital du GUICHET qui a ouvert le dossier.
  //
  // Un patient n'appartient plus à un hôpital : il choisit son
  // établissement au moment de réserver, et c'est donc le RENDEZ-VOUS qui
  // porte l'hôpital (cf. RendezVous.hopitalId), pas le patient.
  //
  // Ce champ ne sert plus qu'à un seul cas : le dossier saisi à l'accueil
  // par une secrétaire, qu'elle doit pouvoir retrouver dans sa liste.
  // Nullable : un patient auto-inscrit ne passe par aucun guichet — la
  // secrétaire qui le reçoit le retrouve grâce à ses rendez-vous.
  final String? hopitalId;

  // Ce champ relie le document "patients" au compte Firebase Auth du
  // patient (users/{uid}). Il est la clé de tout l'espace Patient : c'est
  // par lui qu'on retrouve le dossier du patient connecté sans connaître
  // son id de document beforehand.
  // Nullable : les patients saisis par la secrétaire n'ont pas de compte.
  final String? userId;

  // L'email sert à l'écran "Profil". On le déduit de Firebase Auth, mais
  // on le copie aussi dans le document "patients" pour que la secrétaire le
  // voie dans sa liste.
  final String email;

  // Constructeur : tous les champs sont obligatoires sauf ceux qui ne sont
  // pas marqués "required" (dateNaissance, groupeSanguin, userId et
  // hopitalId), qui restent optionnels.
  Patient({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.email,
    this.dateNaissance,
    this.groupeSanguin,
    this.userId,
    this.hopitalId,
  });

  // Getter pratique, comme pour Medecin.nomComplet : évite de répéter
  // "${patient.prenom} ${patient.nom}" partout dans les écrans.
  String get nomComplet => '$prenom $nom';

  // Getter d'initiale, utilisé par PatientCard et l'écran Profil pour
  // afficher une lettre à la place d'une photo.
  String get initiale =>
      prenom.isNotEmpty ? prenom[0].toUpperCase() : (nom.isNotEmpty ? nom[0].toUpperCase() : '?');

  // Constructeur nommé qui transforme les données brutes Firestore
  // (un Map, comme un objet JSON) en vrai objet Patient Dart.
  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'].toString(),
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      telephone: json['telephone'] ?? '',
      email: json['email'] ?? '',

      // "." + "??" : on garde null quand le champ est absent, au lieu de
      // le convertir en chaîne vide. C'est ce qui distingue un dossier
      // ouvert au guichet d'une auto-inscription.
      hopitalId: json['hopital_id']?.toString(),
      userId: json['user_id']?.toString(),

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
