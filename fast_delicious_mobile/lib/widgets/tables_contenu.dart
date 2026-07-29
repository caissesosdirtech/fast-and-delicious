import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/api_client.dart';
import '../widgets/empty_state.dart';

class TablesContenu extends StatefulWidget {
  const TablesContenu({super.key});

  @override
  State<TablesContenu> createState() => _TablesContenuState();
}

class _TablesContenuState extends State<TablesContenu> {
  List<Map<String, dynamic>> _tables = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    final reponse = await ApiClient().dio.get('menu/tables/');
    if (mounted) {
      setState(() {
        _tables = List<Map<String, dynamic>>.from(reponse.data);
        _chargement = false;
      });
    }
  }

  Future<void> _ajouter() async {
    final ctrl = TextEditingController();
    final nom = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle table / stand'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Ex : Stand 5, Table 12...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Ajouter')),
        ],
      ),
    );
    if (nom == null || nom.trim().isEmpty) return;
    await ApiClient().dio.post('menu/tables/', data: {'nom': nom.trim()});
    _charger();
  }

  Future<void> _supprimer(Map<String, dynamic> table) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer "${table['nom']}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui')),
        ],
      ),
    );
    if (confirme != true) return;
    await ApiClient().dio.delete('menu/tables/${table['id']}/');
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
            const Text('Tables / Stands', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(onPressed: _ajouter, icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter')),
          ],
        ),
        const SizedBox(height: 16),
        if (_chargement)
          const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
        else if (_tables.isEmpty)
          const EmptyState(emoji: '🍽️', titre: 'Aucune table enregistrée')
        else
          Wrap(
            spacing: 10, runSpacing: 10,
            children: _tables.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t['nom'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _supprimer(t),
                    child: const Icon(Icons.close, size: 16, color: AppColors.redDim),
                  ),
                ],
              ),
            )).toList(),
          ),
      ],
    );
  }
}
