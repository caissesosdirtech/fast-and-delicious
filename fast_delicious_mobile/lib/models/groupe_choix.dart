class OptionAccompagnement {
  final int id;
  final String nom;

  OptionAccompagnement({required this.id, required this.nom});

  factory OptionAccompagnement.fromJson(Map<String, dynamic> json) {
    return OptionAccompagnement(id: json['id'], nom: json['nom']);
  }
}

class OptionChoix {
  final int id;
  final String nom;

  OptionChoix({required this.id, required this.nom});

  factory OptionChoix.fromJson(Map<String, dynamic> json) {
    return OptionChoix(id: json['id'], nom: json['nom']);
  }
}

class GroupeChoix {
  final int id;
  final String nom;
  final bool obligatoire;
  final int ordre;
  final List<OptionChoix> options;

  GroupeChoix({
    required this.id,
    required this.nom,
    required this.obligatoire,
    required this.ordre,
    required this.options,
  });

  factory GroupeChoix.fromJson(Map<String, dynamic> json) {
    return GroupeChoix(
      id: json['id'],
      nom: json['nom'],
      obligatoire: json['obligatoire'] ?? false,
      ordre: json['ordre'] ?? 0,
      options: (json['options'] as List? ?? [])
          .map((o) => OptionChoix.fromJson(o))
          .toList(),
    );
  }
}
