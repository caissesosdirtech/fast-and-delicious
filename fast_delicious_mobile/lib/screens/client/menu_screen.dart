import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/photo_locale.dart';
import '../../services/api_client.dart';
import '../../models/plat.dart';
import '../../providers/cart_provider.dart';

const Map<String, String> _iconesCategorie = {
  'fast food': '🌯', 'snack': '🌯',
  'crêpe': '🥞', 'crepe': '🥞',
  'grillade': '🔥',
  'boisson': '🥤',
};

String _iconePourCategorie(String nom) {
  final nomBas = nom.toLowerCase();
  for (final cle in _iconesCategorie.keys) {
    if (nomBas.contains(cle)) return _iconesCategorie[cle]!;
  }
  return '🍽️';
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  List<Categorie> _categories = [];
  bool _chargement = true;
  String? _erreur;
  String _recherche = '';
  bool _rechercheOuverte = false;
  int? _categorieActiveId; // null = "Toutes"
  List<Map<String, dynamic>> _lieux = [];

  @override
  void initState() {
    super.initState();
    _chargerMenu();
    ApiClient().dio.get('menu/lieux/').then((r) {
      if (mounted) setState(() => _lieux = List<Map<String, dynamic>>.from(r.data));
    });
  }

  Future<void> _chargerMenu() async {
    try {
      final reponse = await ApiClient().dio.get('menu/categories/');
      setState(() {
        _categories = (reponse.data as List).map((c) => Categorie.fromJson(c)).toList();
        _chargement = false;
      });
    } catch (_) {
      setState(() {
        _erreur = 'Impossible de charger le menu. Vérifiez que le serveur est lancé.';
        _chargement = false;
      });
    }
  }

  List<Plat> get _formules =>
      _categories.expand((c) => c.plats.where((p) => p.estFormule)).toList();

  List<Plat> get _platsAffiches {
    final tousLesPlats = _categories.expand((c) => c.plats.where((p) => !p.estFormule));
    var filtres = _categorieActiveId == null
        ? tousLesPlats
        : tousLesPlats.where((p) => p.categorieId == _categorieActiveId);
    if (_recherche.trim().isNotEmpty) {
      final q = _recherche.trim().toLowerCase();
      filtres = filtres.where((p) => p.nom.toLowerCase().contains(q));
    }
    return filtres.toList();
  }

  Future<void> _ajouterSimple(Plat plat) async {
    context.read<CartProvider>().modifierQuantite(plat, 1);
  }

  Future<void> _ouvrirConfigurationPlat(Plat plat) async {
    final cart = context.read<CartProvider>();
    int? accompagnementChoisi;
    final Map<int, int?> groupesChoisis = {};
    String? erreur;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plat.nom, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),

                  if (plat.estFormule)
                    ...plat.groupesChoix.map((g) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${g.nom}${g.obligatoire ? " *" : ""}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.inkSoft)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<int>(
                                isExpanded: true,
                                value: groupesChoisis[g.id],
                                hint: const Text('Choisir...'),
                                items: g.options.map((o) => DropdownMenuItem(value: o.id, child: Text(o.nom))).toList(),
                                onChanged: (v) => setModal(() => groupesChoisis[g.id] = v),
                              ),
                            ],
                          ),
                        ))
                  else if (plat.aAccompagnementSimple)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Accompagnement${plat.accompagnementObligatoire ? " *" : ""}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.inkSoft)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: accompagnementChoisi,
                            hint: Text(plat.accompagnementObligatoire ? 'Choisir...' : 'Sans accompagnement'),
                            items: plat.accompagnements.map((a) => DropdownMenuItem(value: a.id, child: Text(a.nom))).toList(),
                            onChanged: (v) => setModal(() => accompagnementChoisi = v),
                          ),
                        ],
                      ),
                    ),

                  if (erreur != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(erreur!, style: const TextStyle(color: AppColors.redDim, fontSize: 12)),
                    ),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (plat.estFormule) {
                          final manquants = plat.groupesChoix.where((g) => g.obligatoire && groupesChoisis[g.id] == null).toList();
                          if (manquants.isNotEmpty) {
                            setModal(() => erreur = 'Merci de choisir : ${manquants.map((g) => g.nom).join(", ")}.');
                            return;
                          }
                          final selections = plat.groupesChoix.where((g) => groupesChoisis[g.id] != null).map((g) {
                            final option = g.options.firstWhere((o) => o.id == groupesChoisis[g.id]);
                            return SelectionPanier(groupeId: g.id, groupeNom: g.nom, optionId: option.id, optionNom: option.nom);
                          }).toList();
                          cart.modifierQuantite(plat, 1, selections: selections);
                        } else {
                          if (plat.accompagnementObligatoire && accompagnementChoisi == null) {
                            setModal(() => erreur = "Choisis un accompagnement d'abord.");
                            return;
                          }
                          final accompagnement = accompagnementChoisi != null
                              ? plat.accompagnements.firstWhere((a) => a.id == accompagnementChoisi)
                              : null;
                          cart.modifierQuantite(plat, 1, accompagnementId: accompagnement?.id, accompagnementNom: accompagnement?.nom);
                        }
                        Navigator.pop(ctx);
                      },
                      child: const Text('+ Ajouter au panier'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _ajouterAuPanier(Plat plat) {
    if (plat.estFormule || plat.aAccompagnementSimple) {
      _ouvrirConfigurationPlat(plat);
    } else {
      _ajouterSimple(plat);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) return const Center(child: CircularProgressIndicator());
    if (_erreur != null && _categories.isEmpty) return Center(child: Text(_erreur!));

    final cart = context.watch<CartProvider>();

    return Column(
      children: [
        // En-tête
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          color: AppColors.panel,
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.menu, color: AppColors.ink),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Menu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                  IconButton(
                    icon: Icon(_rechercheOuverte ? Icons.close : Icons.search),
                    onPressed: () => setState(() {
                      _rechercheOuverte = !_rechercheOuverte;
                      if (!_rechercheOuverte) _recherche = '';
                    }),
                  ),
                ],
              ),
              if (_lieux.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.08),
                      border: Border.all(color: AppColors.gold, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: cart.lieu,
                        isExpanded: true,
                        hint: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('📍 Choisis ton stand / événement...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                        items: _lieux.map((l) => DropdownMenuItem<int?>(
                              value: l['id'] as int,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text('📍 ${l['nom']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            )).toList(),
                        onChanged: (v) => cart.setLieu(v),
                      ),
                    ),
                  ),
                ),
              if (_rechercheOuverte)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    autofocus: true,
                    decoration: const InputDecoration(hintText: 'Rechercher un plat...'),
                    onChanged: (v) => setState(() => _recherche = v),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _chipCategorie('Toutes', null),
                    ..._categories.map((c) => _chipCategorie(c.nom, c.id)),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _chargerMenu,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 20),
              children: [
                if (_formules.isNotEmpty && _recherche.trim().isEmpty && _categorieActiveId == null)
                  ..._formules.map(_buildFormuleCard),
                ..._platsAffiches.map((p) => _buildLigne(p, cart)),
                if (_platsAffiches.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: Text('Aucun plat trouvé.', style: TextStyle(color: AppColors.inkSoft))),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chipCategorie(String label, int? id) {
    final actif = _categorieActiveId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _categorieActiveId = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: actif ? AppColors.ink : AppColors.cream2,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: actif ? Colors.white : AppColors.inkSoft)),
        ),
      ),
    );
  }

  Widget _buildFormuleCard(Plat plat) {
    final cart = context.watch<CartProvider>();
    final quantite = cart.quantitePourPlat(plat.id);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.gold, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: const LinearGradient(colors: [AppColors.gold, AppColors.red])),
            alignment: Alignment.center,
            child: plat.imageUrl != null
                ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(plat.imageUrl!, width: 60, height: 60, fit: BoxFit.cover))
                : (photoLocalePlat(plat.nom) != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset(photoLocalePlat(plat.nom)!, width: 60, height: 60, fit: BoxFit.cover))
                    : const Text('🍱', style: TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✨ Repas complet', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.greenDim)),
                Text(plat.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${plat.prix.toStringAsFixed(0)} FCFA', style: const TextStyle(color: AppColors.redDim, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          _boutonAjout(plat, quantite),
        ],
      ),
    );
  }

  Widget _buildLigne(Plat plat, CartProvider cart) {
    final quantite = cart.quantitePourPlat(plat.id);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line, width: 1))),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: const LinearGradient(colors: [AppColors.gold, AppColors.red])),
            alignment: Alignment.center,
            child: plat.imageUrl != null
                ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(plat.imageUrl!, width: 56, height: 56, fit: BoxFit.cover))
                : (photoLocalePlat(plat.nom) != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset(photoLocalePlat(plat.nom)!, width: 56, height: 56, fit: BoxFit.cover))
                    : Text(_iconePourCategorie(_categories.firstWhere((c) => c.id == plat.categorieId, orElse: () => _categories.first).nom),
                        style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plat.nom, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('${plat.prix.toStringAsFixed(0)} FCFA', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
              ],
            ),
          ),
          _boutonAjout(plat, quantite),
        ],
      ),
    );
  }

  Widget _boutonAjout(Plat plat, int quantite) {
    if (quantite == 0) {
      return GestureDetector(
        onTap: () => _ajouterAuPanier(plat),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.add, color: AppColors.ink, size: 18),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$quantite', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _ajouterAuPanier(plat),
            child: const Icon(Icons.add, color: AppColors.gold, size: 15),
          ),
        ],
      ),
    );
  }
}
