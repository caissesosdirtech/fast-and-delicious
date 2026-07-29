import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/api_client.dart';
import '../widgets/empty_state.dart';

class LieuxContenu extends StatefulWidget {
  const LieuxContenu({super.key});

  @override
  State<LieuxContenu> createState() => _LieuxContenuState();
}

class _LieuxContenuState extends State<LieuxContenu> {
  List<Map<String, dynamic>> _lieux = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    final reponse = await ApiClient().dio.get('menu/lieux/');
    if (mounted) {
      setState(() {
        _lieux = List<Map<String, dynamic>>.from(reponse.data);
        _chargement = false;
      });
    }
  }

  Future<void> _ajouter() async {
    final ctrl = TextEditingController();
    final nom = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau lieu / événement'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Ex : Kermesse Paroisse A')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Ajouter')),
        ],
      ),
    );
    if (nom == null || nom.trim().isEmpty) return;
    await ApiClient().dio.post('menu/lieux/', data: {'nom': nom.trim()});
    _charger();
  }

  Future<void> _supprimer(Map<String, dynamic> lieu) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer "${lieu['nom']}" ?'),
        content: const Text('Le personnel affecté à ce lieu devra être réaffecté.', style: TextStyle(fontSize: 12.5, color: AppColors.redDim)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui, supprimer')),
        ],
      ),
    );
    if (confirme != true) return;
    await ApiClient().dio.delete('menu/lieux/${lieu['id']}/');
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
            const Text('Lieux / Événements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(onPressed: _ajouter, icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter')),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          "Utile si l'équipe organise deux kermesses en même temps, dans deux endroits différents : "
          "crée un lieu par site, puis affecte chaque membre du staff à son lieu (page Employés). "
          "Chaque caissier/cuisinier ne verra alors que les commandes de son propre lieu. "
          "Si un seul lieu existe (ou aucun), rien ne change dans le fonctionnement habituel.",
          style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        if (_chargement)
          const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
        else if (_lieux.isEmpty)
          const EmptyState(emoji: '📍', titre: 'Aucun lieu configuré', sousTitre: 'Un seul événement en cours — fonctionnement normal par défaut.')
        else
          Wrap(
            spacing: 10, runSpacing: 10,
            children: _lieux.map((l) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('📍 ${l['nom']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _supprimer(l),
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
