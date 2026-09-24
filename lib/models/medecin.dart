// Cette classe représente un "médecin" dans l'application.
// C'est un simple conteneur de données (on appelle ça un "modèle")
// qui décrit la forme d'un médecin en Dart, indépendamment de Firestore.
class Medecin {
  // "final" veut dire que la valeur ne peut plus changer une fois l'objet créé.
  // Un Medecin ne se "modifie" pas : si une info change, on recrée un nouvel objet.

  final String id; // identifiant unique du médecin (l'id du document Firestore)
  final String nom; // nom de famille, ex: "Obame"
  final String prenom; // prénom, ex: "Sarah"
  final String specialite; // spécialité médicale, ex: "Cardiologie"

  // Le "?" après String veut dire que ce champ est NULLABLE :
  // il peut valoir null (le médecin n'a pas forcément de photo).
  final String? photoUrl; // lien vers la photo de profil (optionnel)

  final String hopitalId; // id de l'hôpital où travaille le médecin
  final String hopitalNom; // nom de l'hôpital, ex: "CHU de Libreville"

  // Ceci est le CONSTRUCTEUR : la fonction qu'on appelle pour créer
  // un nouvel objet Medecin, ex: Medecin(id: '1', nom: 'Obame', ...).
  Medecin({
    // "required" = ce paramètre est obligatoire, Dart refusera de compiler
    // si on oublie de le fournir à la création.
    required this.id,
    required this.nom,
    required this.prenom,
    required this.specialite,
    required this.hopitalId,
    required this.hopitalNom,
    // Pas de "required" ici car photoUrl est nullable (donc optionnel).
    this.photoUrl,
  });

  // Ceci est un GETTER : une propriété calculée à la volée, pas stockée.
  // Chaque fois qu'on écrit "medecin.nomComplet" quelque part dans le code,
  // Dart exécute cette ligne et retourne le résultat, ex: "Dr Sarah Obame".
  String get nomComplet => 'Dr $prenom $nom';

  // Transforme les données Firestore (Map) en objet Medecin Dart.
  //
  // IMPORTANT : on lit ici des clés en camelCase (hopitalId, hopitalNom,
  // photoUrl), car c'est la convention utilisée par le reste de l'équipe
  // dans la collection "users" (voir medecin_dashboard.dart de
  // l'Étudiant 3, qui écrit data['hopitalId']). On s'aligne dessus pour
  // que les données se chargent correctement.
  factory Medecin.fromJson(Map<String, dynamic> json) {
    // On retourne un Medecin "normal", construit avec les valeurs
    // extraites du Map "json".
    return Medecin(
      // json['id'] peut être un String ou un int selon la source ;
      // .toString() force la conversion en texte pour être sûr.
      id: json['id'].toString(),

      // "??" est l'opérateur de valeur par défaut :
      // si json['nom'] est null, on utilise '' (chaîne vide) à la place.
      // Ça évite un crash si le champ manque dans Firestore.
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      specialite: json['specialite'] ?? '',

      // "?." + "??" : si hopitalId est absent, on met '' plutôt que de
      // planter ou de stocker le texte "null" par erreur.
      hopitalId: json['hopitalId']?.toString() ?? '',
      hopitalNom: json['hopitalNom'] ?? '',

      // Pas de "?? ''" ici : si photoUrl est absent, photoUrl reste null,
      // ce qui est normal puisque le champ est déjà nullable (String?).
      photoUrl: json['photoUrl'],
    );
  }
}
