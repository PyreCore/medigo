// Modèle d'une spécialité médicale (ex: "Cardiologie", "Pédiatrie").
// Les spécialités sont gérées par l'admin d'hôpital : chaque document de
// la collection Firestore "specialites" représente une spécialité et
// porte un champ "hopitalId" qui la rattache à un hôpital.
class Specialite {
  final String id; // identifiant unique (id du document Firestore)
  final String nom; // ex: "Cardiologie"
  final String description; // texte libre, ex: "Maladies du cœur et des vaisseaux"
  final String hopitalId; // hôpital auquel la spécialité est rattachée

  Specialite({
    required this.id,
    required this.nom,
    required this.description,
    required this.hopitalId,
  });

  factory Specialite.fromJson(Map<String, dynamic> json) {
    return Specialite(
      id: json['id'].toString(),
      nom: json['nom'] ?? '',
      description: json['description'] ?? '',
      // "?." + "??" : si hopitalId est absent, on met '' plutôt que de
      // planter ou de stocker le texte "null" par erreur.
      hopitalId: json['hopitalId']?.toString() ?? '',
    );
  }
}
