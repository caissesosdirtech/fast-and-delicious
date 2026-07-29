import 'groupe_choix.dart';
import '../config/api_config.dart';

class Plat {
  final int id;
  final String nom;
  final String description;
  final double prix;
  final int tempsPreparationMin;
  final bool disponible;
  final String? image;
  final int categorieId;
  final List<OptionAccompagnement> accompagnements;
  final bool accompagnementObligatoire;
  final List<GroupeChoix> groupesChoix;

  Plat({
    required this.id,
    required this.nom,
    required this.description,
    required this.prix,
    required this.tempsPreparationMin,
    required this.disponible,
    required this.image,
    required this.categorieId,
    required this.accompagnements,
    required this.accompagnementObligatoire,
    required this.groupesChoix,
  });

  bool get estFormule => groupesChoix.isNotEmpty;
  bool get aAccompagnementSimple => !estFormule && accompagnements.isNotEmpty;

  /// L'API renvoie parfois une URL d'image relative (en dev sans contexte de requête) :
  /// on la complète avec l'hôte du backend si besoin.
  String? get imageUrl {
    if (image == null || image!.isEmpty) return null;
    if (image!.startsWith('http')) return image;
    return '${ApiConfig.baseUrl}$image';
  }

  factory Plat.fromJson(Map<String, dynamic> json) {
    return Plat(
      id: json['id'],
      nom: json['nom'],
      description: json['description'] ?? '',
      prix: double.parse(json['prix'].toString()),
      tempsPreparationMin: json['temps_preparation_min'] ?? 0,
      disponible: json['disponible'] ?? true,
      image: json['image'],
      categorieId: json['categorie'],
      accompagnements: (json['accompagnements'] as List? ?? [])
          .map((a) => OptionAccompagnement.fromJson(a))
          .toList(),
      accompagnementObligatoire: json['accompagnement_obligatoire'] ?? false,
      groupesChoix: (json['groupes_choix'] as List? ?? [])
          .map((g) => GroupeChoix.fromJson(g))
          .toList(),
    );
  }
}

class Categorie {
  final int id;
  final String nom;
  final int ordre;
  final List<Plat> plats;

  Categorie({
    required this.id,
    required this.nom,
    required this.ordre,
    required this.plats,
  });

  factory Categorie.fromJson(Map<String, dynamic> json) {
    return Categorie(
      id: json['id'],
      nom: json['nom'],
      ordre: json['ordre'] ?? 0,
      plats: (json['plats'] as List? ?? []).map((p) => Plat.fromJson(p)).toList(),
    );
  }
}
