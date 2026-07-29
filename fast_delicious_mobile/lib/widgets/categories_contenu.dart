import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/api_client.dart';
import '../widgets/empty_state.dart';

class CategoriesContenu extends StatefulWidget {
  const CategoriesContenu({super.key});

  @override
  State<CategoriesContenu> createState() => _CategoriesContenuState();
}

class _CategoriesContenuState extends State<CategoriesContenu> {
  List<Map<String, dynamic>> _categories = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    final reponse = await ApiClient().dio.get('menu/categories/');
    if (mounted) {
      setState(() {
        _categories = List<Map<String, dynamic>>.from(reponse.data);
        _chargement = false;
      });
    }
  }

  Future<void> _ouvrirFormulaire({Map<String, dynamic>? categorie}) async {
    final nomCtrl = TextEditingController(text: categorie?['nom'] ?? '');
    final ordreCtrl = TextEditingController(text: (categorie?['ordre'] ?? 0).toString());

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(categorie == null ? 'Nouvelle catégorie' : 'Modifier la catégorie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomCtrl, decoration: const InputDecoration(hintText: 'Nom (ex : Desserts)')),
            const SizedBox(height: 10),
            TextField(controller: ordreCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "Ordre d'affichage")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final data = {'nom': nomCtrl.text.trim(), 'ordre': int.tryParse(ordreCtrl.text) ?? 0};
              if (categorie == null) {
                await ApiClient().dio.post('menu/categories/', data: data);
              } else {
                await ApiClient().dio.patch('menu/categories/${categorie['id']}/', data: data);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _charger();
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _supprimer(Map<String, dynamic> categorie) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer "${categorie['nom']}" ?'),
        content: const Text('Les plats de cette catégorie seront aussi supprimés.', style: TextStyle(fontSize: 12.5, color: AppColors.redDim)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui, supprimer')),
        ],
      ),
    );
    if (confirme != true) return;
    await ApiClient().dio.delete('menu/categories/${categorie['id']}/');
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Catégories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(onPressed: () => _ouvrirFormulaire(), icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter')),
          ],
        ),
        const SizedBox(height: 16),
        if (_chargement)
          const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
        else if (_categories.isEmpty)
          const EmptyState(emoji: '🏷️', titre: 'Aucune catégorie')
        else
          ..._categories.map((c) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['nom'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('${(c['plats'] as List).length} plat(s) · ordre ${c['ordre']}', style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _ouvrirFormulaire(categorie: c)),
                    IconButton(icon: const Icon(Icons.delete, size: 18, color: AppColors.red), onPressed: () => _supprimer(c)),
                  ],
                ),
              )),
      ],
    );
  }
}
