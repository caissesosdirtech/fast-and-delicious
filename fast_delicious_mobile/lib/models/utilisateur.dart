class Utilisateur {
  final int id;
  final String username;
  final String role;
  final String? lieuNom;

  Utilisateur({required this.id, required this.username, required this.role, this.lieuNom});

  factory Utilisateur.fromJson(Map<String, dynamic> json) {
    return Utilisateur(
      id: json['id'],
      username: json['username'],
      role: json['role'],
      lieuNom: json['lieu_nom'],
    );
  }

  bool get estAdmin => role == 'admin';
  bool get estCaissiere => role == 'caissiere';
  bool get estCuisine => role == 'cuisine';
  bool get estLivreur => role == 'livreur';
}
