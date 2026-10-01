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

  /// Deux Hopital sont le même s'ils portent le même id de document.
  ///
  /// Sans cet opérateur, Dart compare les objets par IDENTITÉ, et chaque
  /// relecture de Firestore crée de nouveaux Hopital. Un DropdownButton
  /// garde alors en mémoire l'ancien exemplaire et ne retrouve plus aucun item
  /// correspondant : il lève l'assertion "There should be exactly one item
  /// with [DropdownButton]'s value" et l'écran devient rouge.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Hopital && runtimeType == other.runtimeType && id == other.id);

  @override
  int get hashCode => id.hashCode;
}