// Cette classe représente une "secrétaire médicale" dans l'application.
// Comme Medecin, c'est rattaché à UN hôpital précis (hopitalId), mais
// contrairement au médecin, la secrétaire voit et gère les rendez-vous
// de TOUS les médecins de son hôpital, pas seulement les siens.
class Secretaire {
  final String id; // identifiant unique (id du document Firestore)
  final String nom; // nom de famille
  final String prenom; // prénom
  final String? photoUrl; // photo de profil, optionnelle

  final String hopitalId; // id de l'hôpital où elle travaille
  final String hopitalNom; // nom de l'hôpital, ex: "CHU de Libreville"

  Secretaire({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.hopitalId,
    required this.hopitalNom,
    this.photoUrl, // pas de "required" : nullable donc optionnel
  });

  // Getter pratique : "Mme Sarah Obame" au lieu de rassembler les
  // morceaux à chaque fois dans les écrans.
  String get nomComplet => '$prenom $nom';

  // Transforme les données Firestore (Map) en objet Secretaire Dart.
  // Clés en camelCase (hopitalId, hopitalNom, photoUrl), pour la même
  // raison que dans models/medecin.dart : c'est la convention utilisée
  // dans la collection "users" partagée par toute l'équipe.
  factory Secretaire.fromJson(Map<String, dynamic> json) {
    return Secretaire(
      id: json['id'].toString(),
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      hopitalId: json['hopitalId']?.toString() ?? '',
      hopitalNom: json['hopitalNom'] ?? '',
      photoUrl: json['photoUrl'],
    );
  }
}
