class Hopital {
  final String id;
  final String nom;
  final String adresse;
  final String telephone;
  final String email;

  Hopital({
    required this.id,
    required this.nom,
    required this.adresse,
    required this.telephone,
    required this.email,
  });

  factory Hopital.fromMap(Map<String, dynamic> map, String documentId) {
    return Hopital(
      id: documentId,
      nom: map['nom'] ?? '',
      adresse: map['adresse'] ?? '',
      telephone: map['telephone'] ?? '',
      email: map['email'] ?? map['mail'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'adresse': adresse,
      'telephone': telephone,
      'email': email,
    };
  }
}