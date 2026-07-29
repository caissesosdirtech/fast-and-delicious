import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../models/plat.dart';
import '../models/commande.dart';
import '../services/api_client.dart';

class SelectionPanier {
  final int groupeId;
  final String groupeNom;
  final int optionId;
  final String optionNom;

  SelectionPanier({
    required this.groupeId,
    required this.groupeNom,
    required this.optionId,
    required this.optionNom,
  });
}

class LignePanier {
  final String cle;
  final Plat plat;
  int quantite;
  final int? accompagnementId;
  final String? accompagnementNom;
  final List<SelectionPanier> selections;

  LignePanier({
    required this.cle,
    required this.plat,
    required this.quantite,
    this.accompagnementId,
    this.accompagnementNom,
    this.selections = const [],
  });
}

class CartProvider extends ChangeNotifier {
  final Map<String, LignePanier> _panier = {};
  final _api = ApiClient().dio;

  String numeroTable = '';
  String modeCommande = 'SUR_PLACE'; // 'SUR_PLACE' | 'LIVRAISON'
  int? lieu; // id du lieu choisi, null si un seul lieu (ou aucun) configuré
  String adresseLivraison = '';
  String telephoneClient = '';
  String modePaiement = 'ESPECES'; // 'ESPECES' | 'PI_MIX' | 'WAVE' | 'ORANGE_MONEY'
  String referencePaiement = '';
  String remarque = '';

  /// Mémorise l'ID de la dernière commande passée, pour l'onglet "Commande"
  /// de la navigation basse (affiche automatiquement son suivi).
  int? commandeActiveId;

  bool envoiEnCours = false;
  String? erreurCommande;

  List<LignePanier> get lignes => _panier.values.toList();

  int get totalArticles => lignes.fold(0, (acc, l) => acc + l.quantite);

  double get totalPrix =>
      lignes.fold(0.0, (acc, l) => acc + l.quantite * l.plat.prix);

  String _cleLigne(int platId, int? accompagnementId, List<SelectionPanier> selections) {
    final tri = [...selections]..sort((a, b) => a.groupeId.compareTo(b.groupeId));
    final selKey = tri.map((s) => '${s.groupeId}:${s.optionId}').join(',');
    return '$platId::${accompagnementId ?? "none"}::$selKey';
  }

  int quantitePourPlat(int platId) {
    return lignes
        .where((l) => l.plat.id == platId)
        .fold(0, (acc, l) => acc + l.quantite);
  }

  void modifierQuantite(
    Plat plat,
    int delta, {
    int? accompagnementId,
    String? accompagnementNom,
    List<SelectionPanier> selections = const [],
  }) {
    final cle = _cleLigne(plat.id, accompagnementId, selections);
    final existante = _panier[cle];
    final nouvelleQuantite = (existante?.quantite ?? 0) + delta;

    if (nouvelleQuantite <= 0) {
      _panier.remove(cle);
    } else {
      _panier[cle] = LignePanier(
        cle: cle,
        plat: plat,
        quantite: nouvelleQuantite,
        accompagnementId: accompagnementId,
        accompagnementNom: accompagnementNom,
        selections: selections,
      );
    }
    notifyListeners();
  }

  void viderPanier() {
    _panier.clear();
    referencePaiement = '';
    remarque = '';
    notifyListeners();
  }

  void setNumeroTable(String v) { numeroTable = v; notifyListeners(); }
  void setModeCommande(String v) { modeCommande = v; notifyListeners(); }
  void setLieu(int? v) { lieu = v; notifyListeners(); }
  void setAdresseLivraison(String v) { adresseLivraison = v; notifyListeners(); }
  void setTelephoneClient(String v) { telephoneClient = v; notifyListeners(); }
  void setModePaiement(String v) { modePaiement = v; notifyListeners(); }
  void setReferencePaiement(String v) { referencePaiement = v; notifyListeners(); }
  void setRemarque(String v) { remarque = v; notifyListeners(); }

  /// Envoie la commande à l'API. Renvoie la Commande créée si succès, sinon null
  /// (le message d'erreur est alors disponible dans `erreurCommande`).
  Future<Commande?> passerCommande() async {
    erreurCommande = null;
    notifyListeners();

    if (lignes.isEmpty) return null;

    if (modeCommande == 'LIVRAISON') {
      if (adresseLivraison.trim().isEmpty) {
        erreurCommande = "Merci d'indiquer une adresse de livraison.";
        notifyListeners();
        return null;
      }
      if (telephoneClient.trim().isEmpty) {
        erreurCommande = "Merci d'indiquer un numéro de téléphone.";
        notifyListeners();
        return null;
      }
    }

    if (modePaiement != 'ESPECES' && referencePaiement.trim().isEmpty) {
      erreurCommande = "Merci d'indiquer la référence de ta transaction Wave/Orange Money.";
      notifyListeners();
      return null;
    }

    envoiEnCours = true;
    notifyListeners();

    try {
      final data = {
        'numero_table': numeroTable,
        'remarque': remarque,
        'mode_commande': modeCommande,
        if (lieu != null) 'lieu': lieu,
        'mode_paiement': modePaiement,
        if (modePaiement != 'ESPECES') 'reference_paiement': referencePaiement,
        if (modeCommande == 'LIVRAISON') ...{
          'adresse_livraison': adresseLivraison,
          'telephone_client': telephoneClient,
        },
        'lignes': lignes.map((l) => {
          'plat_id': l.plat.id,
          'quantite': l.quantite,
          if (l.accompagnementId != null) 'accompagnement_id': l.accompagnementId,
          if (l.selections.isNotEmpty)
            'selections': l.selections
                .map((s) => {'groupe_id': s.groupeId, 'option_id': s.optionId})
                .toList(),
        }).toList(),
      };

      final reponse = await _api.post('commandes/', data: data);
      final commande = Commande.fromJson(reponse.data);
      commandeActiveId = commande.id;
      viderPanier();
      return commande;
    } on DioException catch (e) {
      erreurCommande = _extraireMessageErreur(e) ?? "La commande n'a pas pu être envoyée. Réessaie.";
      return null;
    } finally {
      envoiEnCours = false;
      notifyListeners();
    }
  }

  String? _extraireMessageErreur(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      if (data['lignes'] is List && data['lignes'].isNotEmpty) {
        final premiereLigne = data['lignes'][0];
        if (premiereLigne is Map && premiereLigne['non_field_errors'] is List) {
          return premiereLigne['non_field_errors'][0];
        }
      }
      if (data['adresse_livraison'] is List) return data['adresse_livraison'][0];
      if (data['telephone_client'] is List) return data['telephone_client'][0];
      if (data['reference_paiement'] is List) return data['reference_paiement'][0];
    }
    return null;
  }
}
