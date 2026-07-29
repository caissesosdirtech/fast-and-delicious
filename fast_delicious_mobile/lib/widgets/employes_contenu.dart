import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../config/theme.dart';
import '../services/api_client.dart';
import '../widgets/empty_state.dart';

const _rolesDisponibles = ['caissiere', 'cuisine', 'livreur', 'admin'];
const _labelsRole = {
  'caissiere': 'Caissière', 'cuisine': 'Cuisinier', 'livreur': 'Livreur', 'admin': 'Admin',
};

class EmployesContenu extends StatefulWidget {
  const EmployesContenu({super.key});

  @override
  State<EmployesContenu> createState() => _EmployesContenuState();
}

class _EmployesContenuState extends State<EmployesContenu> {
  List<Map<String, dynamic>> _employes = [];
  List<Map<String, dynamic>> _lieux = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    final resultats = await Future.wait([
      ApiClient().dio.get('comptes/employes/'),
      ApiClient().dio.get('menu/lieux/'),
    ]);
    if (mounted) {
      setState(() {
        _employes = List<Map<String, dynamic>>.from(resultats[0].data);
        _lieux = List<Map<String, dynamic>>.from(resultats[1].data);
        _chargement = false;
      });
    }
  }

  Future<void> _ouvrirFormulaire({Map<String, dynamic>? employe}) async {
    final usernameCtrl = TextEditingController(text: employe?['username'] ?? '');
    final passwordCtrl = TextEditingController();
    String role = employe?['role'] ?? 'caissiere';
    bool actif = employe?['is_active'] ?? true;
    int? lieuId = employe?['lieu'];
    String? erreur;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          title: Text(employe == null ? 'Nouvel employé' : 'Modifier ${employe['username']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: usernameCtrl, decoration: const InputDecoration(hintText: 'Identifiant')),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(hintText: employe == null ? 'Mot de passe' : 'Nouveau mot de passe (optionnel)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: role,
                  items: _rolesDisponibles.map((r) => DropdownMenuItem(value: r, child: Text(_labelsRole[r]!))).toList(),
                  onChanged: (v) => setModal(() => role = v!),
                ),
                if (_lieux.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Lieu affecté (laisser vide = voit tout)', style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int?>(
                    value: lieuId,
                    hint: const Text('Aucun (voit tout)', style: TextStyle(fontSize: 13)),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Aucun (voit tout)')),
                      ..._lieux.map((l) => DropdownMenuItem<int?>(value: l['id'] as int, child: Text('📍 ${l['nom']}'))),
                    ],
                    onChanged: (v) => setModal(() => lieuId = v),
                  ),
                ],
                if (employe != null) ...[
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Compte actif', style: TextStyle(fontSize: 13)),
                    value: actif,
                    onChanged: (v) => setModal(() => actif = v),
                  ),
                ],
                if (erreur != null)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(erreur!, style: const TextStyle(color: AppColors.redDim, fontSize: 12))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final data = {
                    'username': usernameCtrl.text.trim(),
                    'role': role,
                    'is_active': actif,
                    'lieu': lieuId,
                    if (passwordCtrl.text.isNotEmpty) 'password': passwordCtrl.text,
                  };
                  if (employe == null) {
                    await ApiClient().dio.post('comptes/employes/', data: data);
                  } else {
                    await ApiClient().dio.patch('comptes/employes/${employe['id']}/', data: data);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _charger();
                } on DioException catch (e) {
                  setModal(() => erreur = e.response?.data.toString() ?? 'Erreur');
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _supprimer(Map<String, dynamic> employe) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer ${employe['username']} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui, supprimer')),
        ],
      ),
    );
    if (confirme != true) return;
    await ApiClient().dio.delete('comptes/employes/${employe['id']}/');
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
            const Text('Employés', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(onPressed: () => _ouvrirFormulaire(), icon: const Icon(Icons.add, size: 16), label: const Text('Ajouter')),
          ],
        ),
        const SizedBox(height: 16),
        if (_chargement)
          const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
        else if (_employes.isEmpty)
          const EmptyState(emoji: '👤', titre: 'Aucun employé pour le moment')
        else
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return Column(children: _employes.map(_carteEmployeMobile).toList());
            }
            return Container(
              decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Identifiant')),
                    DataColumn(label: Text('Rôle')),
                    DataColumn(label: Text('Lieu')),
                    DataColumn(label: Text('Statut')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: _employes.map((e) {
                    return DataRow(cells: [
                      DataCell(Text(e['username'])),
                      DataCell(Text(_labelsRole[e['role']] ?? e['role'])),
                      DataCell(Text(e['lieu_nom'] ?? '— (tous)')),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (e['is_active'] ? AppColors.green : AppColors.inkSoft).withOpacity(0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(e['is_active'] ? 'Actif' : 'Inactif', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: e['is_active'] ? AppColors.greenDim : AppColors.inkSoft)),
                      )),
                      DataCell(Row(children: [
                        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _ouvrirFormulaire(employe: e)),
                        IconButton(icon: const Icon(Icons.delete, size: 18, color: AppColors.red), onPressed: () => _supprimer(e)),
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

  Widget _carteEmployeMobile(Map<String, dynamic> e) {
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
              Text(e['username'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (e['is_active'] ? AppColors.green : AppColors.inkSoft).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(e['is_active'] ? 'Actif' : 'Inactif', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: e['is_active'] ? AppColors.greenDim : AppColors.inkSoft)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_labelsRole[e['role']] ?? e['role'], style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
          Text('📍 ${e['lieu_nom'] ?? '— (tous)'}', style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _ouvrirFormulaire(employe: e),
                  icon: const Icon(Icons.edit, size: 15),
                  label: const Text('Modifier', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _supprimer(e),
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
