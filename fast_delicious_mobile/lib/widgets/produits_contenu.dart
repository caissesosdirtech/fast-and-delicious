import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/api_client.dart';
import '../widgets/empty_state.dart';

class ProduitsContenu extends StatefulWidget {
  const ProduitsContenu({super.key});

  @override
  State<ProduitsContenu> createState() => _ProduitsContenuState();
}

class _ProduitsContenuState extends State<ProduitsContenu> {
  List<Map<String, dynamic>> _plats = [];
  List<Map<String, dynamic>> _categories = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    final resultats = await Future.wait([
      ApiClient().dio.get('menu/plats/'),
      ApiClient().dio.get('menu/categories/'),
    ]);
    if (mounted) {
      setState(() {
        _plats = List<Map<String, dynamic>>.from(resultats[0].data);
        _categories = List<Map<String, dynamic>>.from(resultats[1].data);
        _chargement = false;
      });
    }
  }

  String _nomCategorie(int id) => _categories.firstWhere((c) => c['id'] == id, orElse: () => {'nom': '—'})['nom'];

  Future<void> _ouvrirFormulaire({Map<String, dynamic>? plat}) async {
    if (_categories.isEmpty) return;
    final nomCtrl = TextEditingController(text: plat?['nom'] ?? '');
    final descCtrl = TextEditingController(text: plat?['description'] ?? '');
    final prixCtrl = TextEditingController(text: plat != null ? plat['prix'].toString() : '');
    final tempsCtrl = TextEditingController(text: (plat?['temps_preparation_min'] ?? 8).toString());
    int categorieId = plat?['categorie'] ?? _categories.first['id'];
    bool disponible = plat?['disponible'] ?? true;
    String? erreur;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: Text(plat == null ? 'Nouveau plat' : 'Modifier le plat'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nomCtrl, decoration: const InputDecoration(hintText: 'Nom du plat')),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, decoration: const InputDecoration(hintText: 'Description (optionnel)')),
                const SizedBox(height: 10),
                TextField(controller: prixCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Prix (FCFA)')),
                const SizedBox(height: 10),
                TextField(controller: tempsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Temps de préparation (min)')),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: categorieId,
                  items: _categories.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['nom']))).toList(),
                  onChanged: (v) => setModal(() => categorieId = v!),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disponible à la vente', style: TextStyle(fontSize: 13)),
                  value: disponible,
                  onChanged: (v) => setModal(() => disponible = v),
                ),
                if (erreur != null)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text(erreur!, style: const TextStyle(color: AppColors.redDim, fontSize: 12))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final prix = double.tryParse(prixCtrl.text.replaceAll(',', '.'));
                if (nomCtrl.text.trim().isEmpty || prix == null) {
                  setModal(() => erreur = 'Nom et prix valides requis.');
                  return;
                }
                final data = {
                  'nom': nomCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'prix': prix,
                  'temps_preparation_min': int.tryParse(tempsCtrl.text) ?? 8,
                  'categorie': categorieId,
                  'disponible': disponible,
                };
                if (plat == null) {
                  await ApiClient().dio.post('menu/plats/', data: data);
                } else {
                  await ApiClient().dio.patch('menu/plats/${plat['id']}/', data: data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _charger();
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _supprimer(Map<String, dynamic> plat) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer "${plat['nom']}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui')),
        ],
      ),
    );
    if (confirme != true) return;
    await ApiClient().dio.delete('menu/plats/${plat['id']}/');
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
            const Text('Produits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(onPressed: () => _ouvrirFormulaire(), icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter')),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          "ℹ️ La photo, les accompagnements et les formules composées se gèrent depuis l'admin Django (/admin/).",
          style: TextStyle(fontSize: 10.5, color: AppColors.inkSoft, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
        if (_chargement)
          const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
        else if (_plats.isEmpty)
          const EmptyState(emoji: '🍔', titre: 'Aucun plat')
        else
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return Column(children: _plats.map(_cartePlatMobile).toList());
            }
            return Container(
              decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Nom')),
                    DataColumn(label: Text('Catégorie')),
                    DataColumn(label: Text('Prix')),
                    DataColumn(label: Text('Disponible')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: _plats.map((p) {
                    return DataRow(cells: [
                      DataCell(Text(p['nom'])),
                      DataCell(Text(_nomCategorie(p['categorie']))),
                      DataCell(Text('${p['prix']} F')),
                      DataCell(Icon(p['disponible'] ? Icons.check_circle : Icons.cancel, size: 18, color: p['disponible'] ? AppColors.green : AppColors.inkSoft)),
                      DataCell(Row(children: [
                        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _ouvrirFormulaire(plat: p)),
                        IconButton(icon: const Icon(Icons.delete, size: 18, color: AppColors.red), onPressed: () => _supprimer(p)),
                      ])),
                    ]);
                  }).toList(),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _cartePlatMobile(Map<String, dynamic> p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(p['nom'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              Icon(p['disponible'] ? Icons.check_circle : Icons.cancel, size: 18, color: p['disponible'] ? AppColors.green : AppColors.inkSoft),
            ],
          ),
          const SizedBox(height: 4),
          Text(_nomCategorie(p['categorie']), style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
          Text('${p['prix']} F', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.redDim)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _ouvrirFormulaire(plat: p),
                  icon: const Icon(Icons.edit, size: 15),
                  label: const Text('Modifier', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _supprimer(p),
                icon: const Icon(Icons.delete, color: AppColors.red),
                style: IconButton.styleFrom(backgroundColor: AppColors.cream2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
