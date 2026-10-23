class SelectionChoixLue {
  final String groupeNom;
  final String optionNom;

  SelectionChoixLue({required this.groupeNom, required this.optionNom});

  factory SelectionChoixLue.fromJson(Map<String, dynamic> json) {
    return SelectionChoixLue(
      groupeNom: json['groupe_nom'] ?? '',
      optionNom: json['option_nom'] ?? '',
    );
  }
}

class LigneCommande {
  final int id;
  final int platId;
  final String platNom;
  final int quantite;
  final double prixUnitaire;
  final double sousTotal;
  final String? accompagnementNom;
  final List<SelectionChoixLue> selections;

  LigneCommande({
    required this.id,
    required this.platId,
    required this.platNom,
    required this.quantite,
    required this.prixUnitaire,
    required this.sousTotal,
    required this.accompagnementNom,
    required this.selections,
  });

  /// Texte descriptif complet de la ligne (accompagnement / sélections de formule),
  /// équivalent de utils/ligne.js côté web.
  String get details {
    final morceaux = <String>[];
    if (accompagnementNom != null && accompagnementNom!.isNotEmpty) {
      morceaux.add('+ $accompagnementNom');
    }
    if (selections.isNotEmpty) {
      morceaux.add(selections.map((s) => '${s.groupeNom} : ${s.optionNom}').join(', '));
    }
    return morceaux.isEmpty ? '' : ' (${morceaux.join(' — ')})';
  }

  factory LigneCommande.fromJson(Map<String, dynamic> json) {
    return LigneCommande(
      id: json['id'],
      platId: json['plat'],
      platNom: json['plat_nom'] ?? '',
      quantite: json['quantite'] ?? 1,
      prixUnitaire: double.parse((json['prix_unitaire'] ?? 0).toString()),
      sousTotal: double.parse((json['sous_total'] ?? 0).toString()),
      accompagnementNom: json['accompagnement_nom'],
      selections: (json['selections'] as List? ?? [])
          .map((s) => SelectionChoixLue.fromJson(s))
          .toList(),
    );
  }
}

class Commande {
  final int id;
  final String? numeroTable;
  final String statut;
  final String? remarque;
  final String? motifAnnulation;
  final String modeCommande;
  final String? adresseLivraison;
  final String? telephoneClient;
  final String modePaiement;
  final String? referencePaiement;
  final bool paiementConfirme;
  final DateTime dateCreation;
  final List<LigneCommande> lignes;
  final double total;
  final int tempsRestantEstimeMin;

  Commande({
    required this.id,
    required this.numeroTable,
    required this.statut,
    required this.remarque,
    required this.motifAnnulation,
    required this.modeCommande,
    required this.adresseLivraison,
    required this.telephoneClient,
    required this.modePaiement,
    required this.referencePaiement,
    required this.paiementConfirme,
    required this.dateCreation,
    required this.lignes,
    required this.total,
    required this.tempsRestantEstimeMin,
  });

  bool get enLivraison => modeCommande == 'LIVRAISON';
  bool get aTable => !enLivraison && numeroTable != null && numeroTable!.trim().isNotEmpty;

  /// Convertit la commande en Map compatible avec ouvrirTicketDetail (reçu).
  Map<String, dynamic> toTicketMap() => {
        'id': id,
        'statut': statut,
        'numero_table': numeroTable,
        'mode_commande': modeCommande,
        'adresse_livraison': adresseLivraison,
        'telephone_client': telephoneClient,
        'mode_paiement': modePaiement,
        'reference_paiement': referencePaiement,
        'remarque': remarque,
        'motif_annulation': motifAnnulation,
        'date_creation': dateCreation.toIso8601String(),
        'total': total,
        'lignes': lignes
            .map((l) => {
                  'quantite': l.quantite,
                  'plat_nom': l.platNom,
                  'sous_total': l.sousTotal,
                })
            .toList(),
      };

  factory Commande.fromJson(Map<String, dynamic> json) {
    return Commande(
      id: json['id'],
      numeroTable: json['numero_table'],
      statut: json['statut'],
      remarque: json['remarque'],
      motifAnnulation: json['motif_annulation'],
      modeCommande: json['mode_commande'] ?? 'SUR_PLACE',
      adresseLivraison: json['adresse_livraison'],
      telephoneClient: json['telephone_client'],
      modePaiement: json['mode_paiement'] ?? 'ESPECES',
      referencePaiement: json['reference_paiement'],
      paiementConfirme: json['paiement_confirme'] ?? false,
      dateCreation: DateTime.parse(json['date_creation']),
      lignes: (json['lignes'] as List? ?? [])
          .map((l) => LigneCommande.fromJson(l))
          .toList(),
      total: double.parse((json['total'] ?? 0).toString()),
      tempsRestantEstimeMin: json['temps_restant_estime_min'] ?? 0,
    );
  }
}
