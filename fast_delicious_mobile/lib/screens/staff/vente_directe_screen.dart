import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme.dart';
import '../../config/photo_locale.dart';
import '../../models/plat.dart';
import '../../models/groupe_choix.dart';
import '../../providers/cart_provider.dart' show SelectionPanier;
import '../../services/api_client.dart';
import '../../services/ventes_hors_ligne.dart';

/// Vente directe (caisse au comptoir) — version mobile.
///
/// La caissière ouvre cet écran quand un client se présente à la boutique :
/// elle cherche les produits (recherche intelligente + filtre catégorie), les
/// ajoute au panier, encaisse l'argent puis valide. La commande est alors
/// enregistrée automatiquement (déjà payée et servie) via POST
/// /api/caisse/vente-directe/.
class VenteDirecteScreen extends StatefulWidget {
  const VenteDirecteScreen({super.key});

  @override
  State<VenteDirecteScreen> createState() => _VenteDirecteScreenState();
}

class _LigneVente {
  final String cle;
  final Plat plat;
  int quantite;
  final int? accompagnementId;
  final String? accompagnementNom;
  final List<SelectionPanier> selections;

  _LigneVente({
    required this.cle,
    required this.plat,
    required this.quantite,
    this.accompagnementId,
    this.accompagnementNom,
    this.selections = const [],
  });

  double get sousTotal => plat.prix * quantite;
}

class _VenteDirecteScreenState extends State<VenteDirecteScreen> {
  final _api = ApiClient().dio;

  List<Plat> _plats = [];
  List<Categorie> _categories = [];
  bool _chargement = true;
  String? _erreurChargement;

  String _recherche = '';
  int? _filtreCategorie; // null = toutes

  final Map<String, _LigneVente> _panier = {};

  int _enAttente = 0; // ventes hors ligne en attente de synchronisation
  bool _syncEnCours = false;

  @override
  void initState() {
    super.initState();
    _charger();
    _rafraichirEnAttente();
    _synchroniser(silencieux: true); // tente de vider la file au démarrage
  }

  Future<void> _rafraichirEnAttente() async {
    final n = await VentesHorsLigne.nombreEnAttente();
    if (mounted) setState(() => _enAttente = n);
  }

  Future<void> _synchroniser({bool silencieux = false}) async {
    if (_syncEnCours) return;
    setState(() => _syncEnCours = true);
    int envoyees = 0;
    try {
      envoyees = await VentesHorsLigne.synchroniser(_api);
    } catch (_) {}
    await _rafraichirEnAttente();
    if (mounted) {
      setState(() => _syncEnCours = false);
      if (!silencieux) {
        final reste = _enAttente;
        final msg = envoyees > 0
            ? '$envoyees vente(s) synchronisée(s).${reste > 0 ? " $reste encore en attente." : ""}'
            : (reste > 0
                ? 'Toujours hors ligne : $reste vente(s) en attente.'
                : 'Rien à synchroniser.');
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(msg),
            backgroundColor: envoyees > 0 ? AppColors.greenDim : AppColors.inkSoft,
            behavior: SnackBarBehavior.floating,
          ));
      }
    }
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreurChargement = null;
    });
    try {
      final resultats = await Future.wait([
        _api.get('menu/plats/'),
        _api.get('menu/categories/'),
      ]);
      if (!mounted) return;
      setState(() {
        _plats = (resultats[0].data as List).map((p) => Plat.fromJson(p)).toList();
        _categories =
            (resultats[1].data as List).map((c) => Categorie.fromJson(c)).toList();
        _chargement = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreurChargement = 'Impossible de charger les produits. Vérifie la connexion.';
      });
    }
  }

  String _normaliser(String? t) {
    if (t == null) return '';
    var s = t.toLowerCase();
    const avec = 'àâäáãéèêëíìîïóòôöõúùûüçñ';
    const sans = 'aaaaaeeeeiiiiooooouuuucn';
    final sb = StringBuffer();
    for (final ch in s.split('')) {
      final i = avec.indexOf(ch);
      sb.write(i >= 0 ? sans[i] : ch);
    }
    return sb.toString();
  }

  String _nomCategorie(int id) {
    final c = _categories.where((c) => c.id == id).toList();
    return c.isNotEmpty ? c.first.nom : '';
  }

  List<Plat> get _platsFiltres {
    final req = _normaliser(_recherche).trim();
    return _plats.where((p) {
      if (!p.disponible) return false;
      if (_filtreCategorie != null && p.categorieId != _filtreCategorie) return false;
      if (req.isEmpty) return true;
      final cible = _normaliser('${p.nom} ${p.description} ${_nomCategorie(p.categorieId)}');
      return cible.contains(req);
    }).toList();
  }

  bool _necessiteConfig(Plat p) =>
      p.accompagnements.isNotEmpty || p.groupesChoix.isNotEmpty;

  String _cleLigne(int platId, int? accId, List<SelectionPanier> sels) {
    final tri = [...sels]..sort((a, b) => a.groupeId.compareTo(b.groupeId));
    final selKey = tri.map((s) => '${s.groupeId}:${s.optionId}').join(',');
    return '$platId::${accId ?? "none"}::$selKey';
  }

  void _ajouter(Plat plat, int? accId, String? accNom, List<SelectionPanier> sels) {
    final cle = _cleLigne(plat.id, accId, sels);
    setState(() {
      final existante = _panier[cle];
      if (existante != null) {
        existante.quantite += 1;
      } else {
        _panier[cle] = _LigneVente(
          cle: cle,
          plat: plat,
          quantite: 1,
          accompagnementId: accId,
          accompagnementNom: accNom,
          selections: sels,
        );
      }
    });
  }

  Future<void> _cliquerProduit(Plat plat) async {
    if (!_necessiteConfig(plat)) {
      _ajouter(plat, null, null, const []);
      _toastAjout(plat.nom);
      return;
    }
    final res = await _ouvrirConfiguration(plat);
    if (res != null) {
      _ajouter(plat, res.accompagnementId, res.accompagnementNom, res.selections);
      _toastAjout(plat.nom);
    }
  }

  void _toastAjout(String nom) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('$nom ajouté'),
        duration: const Duration(milliseconds: 900),
        backgroundColor: AppColors.greenDim,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<_ResultatConfig?> _ouvrirConfiguration(Plat plat) {
    return showModalBottomSheet<_ResultatConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ConfigurationSheet(plat: plat),
    );
  }

  int get _totalArticles => _panier.values.fold(0, (a, l) => a + l.quantite);
  double get _totalPrix => _panier.values.fold(0.0, (a, l) => a + l.sousTotal);

  void _changerQuantite(String cle, int delta, StateSetter? setSheet) {
    void maj() {
      final l = _panier[cle];
      if (l == null) return;
      l.quantite += delta;
      if (l.quantite <= 0) _panier.remove(cle);
    }

    setState(maj);
    if (setSheet != null) setSheet(() {});
  }

  void _retirer(String cle, StateSetter? setSheet) {
    setState(() => _panier.remove(cle));
    if (setSheet != null) setSheet(() {});
  }

  Future<void> _ouvrirPanier() async {
    if (_panier.isEmpty) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PanierSheet(etat: this),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('🛒 Vente directe'),
      ),
      body: Column(
        children: [
          if (_enAttente > 0) _bandeauHorsLigne(),
          Expanded(
            child: _chargement
                ? const Center(child: CircularProgressIndicator())
                : _erreurChargement != null
                    ? _etatErreur()
                    : _contenu(),
          ),
        ],
      ),
      bottomNavigationBar: _barreBas(),
    );
  }

  Widget _bandeauHorsLigne() {
    return Material(
      color: const Color(0xFFFFF3E0),
      child: InkWell(
        onTap: _syncEnCours ? null : () => _synchroniser(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.cloud_off, size: 20, color: Color(0xFFB26A00)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$_enAttente vente(s) enregistrée(s) hors ligne, en attente de synchronisation.',
                  style: const TextStyle(
                      color: Color(0xFF8A5200), fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
              if (_syncEnCours)
                const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                const Text('Synchroniser',
                    style: TextStyle(
                        color: Color(0xFFB26A00), fontWeight: FontWeight.bold, fontSize: 13.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _etatErreur() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 40, color: AppColors.inkSoft),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(_erreurChargement!, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _charger,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _contenu() {
    final plats = _platsFiltres;
    return Column(
      children: [
        // Recherche
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: TextField(
            onChanged: (v) => setState(() => _recherche = v),
            decoration: InputDecoration(
              hintText: 'Rechercher un produit...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _recherche.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _recherche = ''),
                    )
                  : null,
              isDense: true,
            ),
          ),
        ),
        // Filtre catégories (puces)
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _puceCategorie('Toutes', null),
              ..._categories.map((c) => _puceCategorie(c.nom, c.id)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Grille produits
        Expanded(
          child: plats.isEmpty
              ? Center(
                  child: Text(
                    _plats.isEmpty ? 'Aucun produit' : 'Aucun résultat',
                    style: const TextStyle(color: AppColors.inkSoft),
                  ),
                )
              : LayoutBuilder(builder: (context, c) {
                  final colonnes = c.maxWidth ~/ 170 < 2 ? 2 : (c.maxWidth ~/ 170);
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: colonnes,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: plats.length,
                    itemBuilder: (context, i) => _carteProduit(plats[i]),
                  );
                }),
        ),
      ],
    );
  }

  Widget _puceCategorie(String label, int? id) {
    final actif = _filtreCategorie == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: actif,
        onSelected: (_) => setState(() => _filtreCategorie = id),
        selectedColor: AppColors.greenDim,
        labelStyle: TextStyle(
          color: actif ? Colors.white : AppColors.ink,
          fontWeight: actif ? FontWeight.bold : FontWeight.normal,
          fontSize: 12.5,
        ),
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: actif ? AppColors.greenDim : AppColors.line),
        ),
      ),
    );
  }

  Widget _carteProduit(Plat plat) {
    final q = _panier.values
        .where((l) => l.plat.id == plat.id)
        .fold(0, (a, l) => a + l.quantite);
    return Material(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(14),
      elevation: 1.5,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _cliquerProduit(plat),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: _imagePlat(plat),
                  ),
                  if (_necessiteConfig(plat))
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.greenDim,
                        child: Icon(Icons.tune, size: 13, color: Colors.white),
                      ),
                    ),
                  if (q > 0)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('$q',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 2),
              child: Text(
                plat.nom,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13, height: 1.2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 9),
              child: Text(
                '${plat.prix.toStringAsFixed(0)} F',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.greenDim),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlat(Plat plat) {
    final asset = photoLocalePlat(plat.nom);
    final fond = Container(
      color: AppColors.cream2,
      alignment: Alignment.center,
      child: const Icon(Icons.fastfood, size: 30, color: AppColors.inkSoft),
    );
    if (asset != null) {
      return Image.asset(asset,
          fit: BoxFit.cover,
          width: double.infinity,
          alignment: Alignment.topCenter,
          errorBuilder: (_, __, ___) => fond);
    }
    final url = plat.imageUrl;
    if (url != null) {
      return Image.network(url,
          fit: BoxFit.cover,
          width: double.infinity,
          alignment: Alignment.topCenter,
          errorBuilder: (_, __, ___) => fond);
    }
    return fond;
  }

  Widget _barreBas() {
    final vide = _panier.isEmpty;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          color: AppColors.panel,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$_totalArticles article${_totalArticles > 1 ? "s" : ""}',
                      style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                  Text('${_totalPrix.toStringAsFixed(0)} F',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.greenDim)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: vide ? null : _ouvrirPanier,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.greenDim,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.point_of_sale),
              label: const Text('Encaisser',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  /// Envoi de la vente au backend.
  ///
  /// Renvoie un résultat : {status: 'ok'|'offline'|'error', id?, message?}.
  /// - 'ok'      : enregistrée sur le serveur.
  /// - 'offline' : réseau coupé → mise en file locale, sera synchronisée.
  /// - 'error'   : refus du serveur (ex. données invalides) → message affiché.
  Future<Map<String, dynamic>> envoyerVente({
    required String modePaiement,
    required String numeroTable,
    required String referencePaiement,
  }) async {
    if (_panier.isEmpty) return {'status': 'error', 'message': 'Le panier est vide.'};
    final lignes = _panier.values.map((l) {
      return {
        'plat_id': l.plat.id,
        'quantite': l.quantite,
        if (l.accompagnementId != null) 'accompagnement_id': l.accompagnementId,
        if (l.selections.isNotEmpty)
          'selections': l.selections
              .map((s) => {'groupe_id': s.groupeId, 'option_id': s.optionId})
              .toList(),
      };
    }).toList();

    final data = {
      'lignes': lignes,
      'mode_paiement': modePaiement,
      'numero_table': numeroTable.trim(),
      'reference_paiement': referencePaiement.trim(),
    };

    try {
      final reponse = await _api.post('caisse/vente-directe/', data: data);
      final id = reponse.data is Map ? reponse.data['id'] : null;
      setState(() => _panier.clear());
      return {'status': 'ok', 'id': id};
    } on DioException catch (e) {
      if (e.response == null) {
        // Pas de réponse = hors ligne : on sauvegarde la vente localement.
        await VentesHorsLigne.ajouter(data);
        await _rafraichirEnAttente();
        setState(() => _panier.clear());
        return {'status': 'offline'};
      }
      return {'status': 'error', 'message': _messageErreur(e)};
    } catch (_) {
      return {'status': 'error', 'message': "La vente n'a pas pu être enregistrée. Réessaie."};
    }
  }

  String _messageErreur(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      if (data['lignes'] is List && (data['lignes'] as List).isNotEmpty) {
        final l0 = data['lignes'][0];
        if (l0 is Map && l0['non_field_errors'] is List) {
          return l0['non_field_errors'][0].toString();
        }
      }
      if (data['detail'] != null) return data['detail'].toString();
      if (data.isNotEmpty) return data.values.first.toString();
    }
    return "La vente n'a pas pu être enregistrée. Réessaie.";
  }
}

/* ====================================================================== */
/* Résultat de la configuration d'un plat                                 */
/* ====================================================================== */
class _ResultatConfig {
  final int? accompagnementId;
  final String? accompagnementNom;
  final List<SelectionPanier> selections;
  _ResultatConfig(this.accompagnementId, this.accompagnementNom, this.selections);
}

/* ====================================================================== */
/* Feuille de configuration (accompagnement + groupes de choix)           */
/* ====================================================================== */
class _ConfigurationSheet extends StatefulWidget {
  final Plat plat;
  const _ConfigurationSheet({required this.plat});

  @override
  State<_ConfigurationSheet> createState() => _ConfigurationSheetState();
}

class _ConfigurationSheetState extends State<_ConfigurationSheet> {
  int? _accompagnementId;
  final Map<int, int> _choixParGroupe = {}; // groupeId -> optionId
  String? _erreur;

  @override
  void initState() {
    super.initState();
    final p = widget.plat;
    if (p.accompagnementObligatoire && p.accompagnements.isNotEmpty) {
      _accompagnementId = p.accompagnements.first.id;
    }
    for (final g in p.groupesChoix) {
      if (g.obligatoire && g.options.isNotEmpty) {
        _choixParGroupe[g.id] = g.options.first.id;
      }
    }
  }

  void _valider() {
    final p = widget.plat;
    if (p.accompagnementObligatoire && _accompagnementId == null) {
      setState(() => _erreur = 'Veuillez choisir un accompagnement.');
      return;
    }
    for (final g in p.groupesChoix) {
      if (g.obligatoire && _choixParGroupe[g.id] == null) {
        setState(() => _erreur = 'Veuillez choisir une option pour « ${g.nom} ».');
        return;
      }
    }

    String? accNom;
    if (_accompagnementId != null) {
      final a = p.accompagnements.where((a) => a.id == _accompagnementId).toList();
      if (a.isNotEmpty) accNom = a.first.nom;
    }

    final selections = <SelectionPanier>[];
    for (final g in p.groupesChoix) {
      final optId = _choixParGroupe[g.id];
      if (optId != null) {
        final opt = g.options.where((o) => o.id == optId).toList();
        selections.add(SelectionPanier(
          groupeId: g.id,
          groupeNom: g.nom,
          optionId: optId,
          optionNom: opt.isNotEmpty ? opt.first.nom : '',
        ));
      }
    }

    Navigator.pop(context, _ResultatConfig(_accompagnementId, accNom, selections));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plat;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(p.nom, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('${p.prix.toStringAsFixed(0)} F',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.greenDim)),
            const SizedBox(height: 10),

            if (p.accompagnements.isNotEmpty) ...[
              _titreGroupe(
                  'Accompagnement${p.accompagnementObligatoire ? " *" : " (facultatif)"}'),
              if (!p.accompagnementObligatoire)
                _radioTuile<int?>(
                  label: 'Sans accompagnement',
                  value: null,
                  groupe: _accompagnementId,
                  onChanged: (v) => setState(() => _accompagnementId = v),
                ),
              ...p.accompagnements.map((a) => _radioTuile<int?>(
                    label: a.nom,
                    value: a.id,
                    groupe: _accompagnementId,
                    onChanged: (v) => setState(() => _accompagnementId = v),
                  )),
            ],

            ...p.groupesChoix.map((g) => _buildGroupe(g)),

            if (_erreur != null) ...[
              const SizedBox(height: 8),
              Text(_erreur!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
            ],

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _valider,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.greenDim,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Ajouter au panier',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupe(GroupeChoix g) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titreGroupe('${g.nom}${g.obligatoire ? " *" : " (facultatif)"}'),
        if (!g.obligatoire)
          _radioTuile<int?>(
            label: 'Aucun',
            value: null,
            groupe: _choixParGroupe[g.id],
            onChanged: (v) => setState(() {
              if (v == null) {
                _choixParGroupe.remove(g.id);
              } else {
                _choixParGroupe[g.id] = v;
              }
            }),
          ),
        ...g.options.map((o) => _radioTuile<int?>(
              label: o.nom,
              value: o.id,
              groupe: _choixParGroupe[g.id],
              onChanged: (v) => setState(() {
                if (v == null) {
                  _choixParGroupe.remove(g.id);
                } else {
                  _choixParGroupe[g.id] = v;
                }
              }),
            )),
      ],
    );
  }

  Widget _titreGroupe(String t) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(t.toUpperCase(),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.inkSoft,
                letterSpacing: 0.3)),
      );

  Widget _radioTuile<T>({
    required String label,
    required T value,
    required T groupe,
    required ValueChanged<T> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Radio<T>(
              value: value,
              groupValue: groupe,
              onChanged: (v) => onChanged(v as T),
              activeColor: AppColors.greenDim,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          ],
        ),
      ),
    );
  }
}

/* ====================================================================== */
/* Feuille panier : lignes, paiement, encaissement                        */
/* ====================================================================== */
class _PanierSheet extends StatefulWidget {
  final _VenteDirecteScreenState etat;
  const _PanierSheet({required this.etat});

  @override
  State<_PanierSheet> createState() => _PanierSheetState();
}

class _PanierSheetState extends State<_PanierSheet> {
  String _modePaiement = 'ESPECES';
  final _refCtrl = TextEditingController();
  final _tableCtrl = TextEditingController();
  final _recuCtrl = TextEditingController(); // espèces : montant donné par le client
  bool _envoi = false;
  String? _erreur;

  _VenteDirecteScreenState get etat => widget.etat;

  @override
  void dispose() {
    _refCtrl.dispose();
    _tableCtrl.dispose();
    _recuCtrl.dispose();
    super.dispose();
  }

  Future<void> _encaisser(StateSetter setSheet) async {
    // On capture le ticket AVANT l'envoi (le panier sera vidé ensuite).
    final recu = _construireRecu();

    setSheet(() {
      _erreur = null;
      _envoi = true;
    });
    final res = await etat.envoyerVente(
      modePaiement: _modePaiement,
      numeroTable: _tableCtrl.text,
      referencePaiement: _refCtrl.text,
    );
    if (!mounted) return;
    final status = res['status'];
    if (status == 'ok' || status == 'offline') {
      Navigator.pop(context); // ferme la feuille panier
      _afficherSucces(res['id']?.toString(), recu, horsLigne: status == 'offline');
      // Connexion rétablie : on en profite pour vider la file hors ligne.
      if (status == 'ok' && etat._enAttente > 0) etat._synchroniser(silencieux: true);
    } else {
      setSheet(() {
        _erreur = res['message']?.toString() ?? "La vente n'a pas pu être enregistrée.";
        _envoi = false;
      });
    }
  }

  /// Construit le ticket à partir du panier et des infos de paiement.
  Map<String, dynamic> _construireRecu() {
    final total = etat._totalPrix;
    final recu = int.tryParse(_recuCtrl.text);
    return {
      'date': DateTime.now(),
      'numero': _tableCtrl.text.trim(),
      'mode': _modePaiement,
      'reference': _refCtrl.text.trim(),
      'lignes': etat._panier.values
          .map((l) => {
                'nom': l.plat.nom,
                'quantite': l.quantite,
                'sousTotal': l.sousTotal,
                'options': [
                  if (l.accompagnementNom != null) l.accompagnementNom!,
                  ...l.selections.map((s) => s.optionNom),
                ],
              })
          .toList(),
      'total': total,
      'montantRecu': _modePaiement == 'ESPECES' && recu != null ? recu : null,
      'rendu': _modePaiement == 'ESPECES' && recu != null ? recu - total : null,
    };
  }

  void _afficherSucces(String? id, Map<String, dynamic> recu, {bool horsLigne = false}) {
    final total = (recu['total'] as num?)?.toStringAsFixed(0) ?? '';
    final rendu = recu['rendu'] as num?;
    showDialog(
      context: etat.context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(horsLigne ? Icons.cloud_done : Icons.check_circle,
                color: horsLigne ? const Color(0xFFB26A00) : AppColors.green, size: 54),
            const SizedBox(height: 10),
            Text(horsLigne ? 'Vente enregistrée hors ligne' : 'Vente enregistrée',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              horsLigne
                  ? 'Pas de réseau : la vente sera synchronisée automatiquement dès le retour de la connexion.'
                  : (id != null
                      ? 'Commande #$id encaissée et servie.'
                      : 'Commande encaissée et servie.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text('$total F',
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.greenDim)),
            if (rendu != null && rendu >= 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Rendu : ${rendu.toStringAsFixed(0)} F',
                    style: const TextStyle(fontSize: 15, color: AppColors.ink)),
              ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => _partagerRecu(id, recu),
                icon: const Icon(Icons.print_outlined, size: 20),
                label: const Text('Imprimer / Partager'),
                style: TextButton.styleFrom(foregroundColor: AppColors.greenDim),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.greenDim,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Nouvelle vente'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Partage le reçu en texte (le menu Android/iOS permet d'imprimer,
  /// d'envoyer à une imprimante Bluetooth ou par WhatsApp/SMS).
  void _partagerRecu(String? id, Map<String, dynamic> recu) {
    final libelle = {
      'ESPECES': 'Espèces',
      'WAVE': 'Wave',
      'ORANGE_MONEY': 'Orange Money',
      'PI_MIX': 'QR (PI Mix / YAS)',
    };
    final d = recu['date'] as DateTime? ?? DateTime.now();
    final b = StringBuffer();
    b.writeln('MENU CONCESSION 5');
    b.writeln('JOJ Dakar 2026');
    b.writeln('Reçu${id != null ? " #$id" : ""}');
    b.writeln(DateFormat('dd/MM/yyyy HH:mm').format(d) +
        ((recu['numero'] as String?)?.isNotEmpty == true ? ' · ${recu['numero']}' : ''));
    b.writeln('------------------------------');
    for (final l in (recu['lignes'] as List)) {
      b.writeln('${l['quantite']} x ${l['nom']} — ${(l['sousTotal'] as num).toStringAsFixed(0)} F');
      final opts = (l['options'] as List).where((o) => o != null && '$o'.isNotEmpty).toList();
      if (opts.isNotEmpty) b.writeln('   ${opts.join(" · ")}');
    }
    b.writeln('------------------------------');
    b.writeln('TOTAL : ${(recu['total'] as num).toStringAsFixed(0)} F');
    b.writeln('Paiement : ${libelle[recu['mode']] ?? recu['mode']}');
    if (recu['montantRecu'] != null) {
      b.writeln('Reçu : ${(recu['montantRecu'] as num).toStringAsFixed(0)} F');
      final r = recu['rendu'] as num;
      b.writeln('Rendu : ${(r >= 0 ? r : 0).toStringAsFixed(0)} F');
    }
    if (recu['mode'] != 'ESPECES' && (recu['reference'] as String?)?.isNotEmpty == true) {
      b.writeln('Réf. : ${recu['reference']}');
    }
    b.writeln('Merci et à bientôt !');
    b.writeln('menu-concession5.com');
    Share.share(b.toString(), subject: 'Reçu${id != null ? " #$id" : ""}');
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return StatefulBuilder(
      builder: (context, setSheet) {
        final lignes = etat._panier.values.toList();
        final total = etat._totalPrix;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scroll) {
              return Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Panier',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Expanded(
                    child: lignes.isEmpty
                        ? const Center(child: Text('Panier vide'))
                        : ListView(
                            controller: scroll,
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                            children: [
                              ...lignes.map((l) => _ligneTuile(l, setSheet)),
                            ],
                          ),
                  ),
                  _pied(total, setSheet),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _ligneTuile(_LigneVente l, StateSetter setSheet) {
    final sousTitres = <String>[];
    if (l.accompagnementNom != null) sousTitres.add('+ ${l.accompagnementNom}');
    if (l.selections.isNotEmpty) {
      sousTitres.add(l.selections.map((s) => s.optionNom).join(' · '));
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.plat.nom,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (sousTitres.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(sousTitres.join(' · '),
                        style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('${l.sousTotal.toStringAsFixed(0)} F',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.greenDim)),
                ),
              ],
            ),
          ),
          _stepper(l, setSheet),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: AppColors.red,
            onPressed: () => etat._retirer(l.cle, setSheet),
          ),
        ],
      ),
    );
  }

  Widget _stepper(_LigneVente l, StateSetter setSheet) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _boutonStepper(Icons.remove, () => etat._changerQuantite(l.cle, -1, setSheet)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('${l.quantite}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          _boutonStepper(Icons.add, () => etat._changerQuantite(l.cle, 1, setSheet)),
        ],
      ),
    );
  }

  Widget _boutonStepper(IconData icone, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icone, size: 18, color: AppColors.greenDim),
      ),
    );
  }

  Widget _pied(double total, StateSetter setSheet) {
    const modes = [
      ['ESPECES', '💵 Espèces'],
      ['WAVE', '🌊 Wave'],
      ['ORANGE_MONEY', '🟠 Orange Money'],
    ];
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.cream2,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modes de paiement
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: modes.map((m) {
              final actif = _modePaiement == m[0];
              return ChoiceChip(
                label: Text(m[1]),
                selected: actif,
                onSelected: (_) => setSheet(() => _modePaiement = m[0]),
                selectedColor: AppColors.greenDim,
                labelStyle: TextStyle(
                  color: actif ? Colors.white : AppColors.ink,
                  fontWeight: actif ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12.5,
                ),
                backgroundColor: AppColors.panel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: actif ? AppColors.greenDim : AppColors.line),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          if (_modePaiement == 'ESPECES') ...[
            TextField(
              controller: _recuCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setSheet(() {}),
              decoration: const InputDecoration(
                hintText: 'Montant reçu du client (facultatif)',
                isDense: true,
              ),
            ),
            Builder(builder: (_) {
              final recu = int.tryParse(_recuCtrl.text);
              if (recu == null) return const SizedBox(height: 10);
              final rendu = recu - total;
              final ok = rendu >= 0;
              return Container(
                margin: const EdgeInsets.only(top: 8, bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: ok ? const Color(0xFFE9F7EF) : const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ok ? const Color(0xFFBFE6CF) : const Color(0xFFF3C2C2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(ok ? 'Rendu à faire : ' : 'Il manque : ',
                        style: TextStyle(
                            color: ok ? AppColors.greenDim : AppColors.red, fontSize: 14)),
                    Text('${(ok ? rendu : -rendu).toStringAsFixed(0)} F',
                        style: TextStyle(
                            color: ok ? AppColors.greenDim : AppColors.red,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              );
            }),
          ],
          if (_modePaiement != 'ESPECES')
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _refCtrl,
                decoration: const InputDecoration(
                  hintText: 'Référence de paiement (facultatif)',
                  isDense: true,
                ),
              ),
            ),
          TextField(
            controller: _tableCtrl,
            maxLength: 10,
            decoration: const InputDecoration(
              hintText: 'Table / repère (facultatif)',
              isDense: true,
              counterText: '',
            ),
          ),
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_erreur!,
                  style: const TextStyle(color: AppColors.red, fontSize: 13)),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                    Text('${total.toStringAsFixed(0)} F',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.greenDim)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _envoi ? null : () => _encaisser(setSheet),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.greenDim,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _envoi
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check),
                label: Text(_envoi ? 'Enregistrement...' : 'Valider',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
