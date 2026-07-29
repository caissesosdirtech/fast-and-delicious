import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../services/api_client.dart';
import '../widgets/empty_state.dart';

class ClientsContenu extends StatefulWidget {
  const ClientsContenu({super.key});

  @override
  State<ClientsContenu> createState() => _ClientsContenuState();
}

class _ClientsContenuState extends State<ClientsContenu> {
  List<Map<String, dynamic>> _clients = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    final reponse = await ApiClient().dio.get('caisse/clients/');
    if (mounted) {
      setState(() {
        _clients = List<Map<String, dynamic>>.from(reponse.data);
        _chargement = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Clients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'Regroupés par numéro de téléphone, à partir des commandes en livraison (aucune fiche client dédiée).',
          style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        if (_chargement)
          const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
        else if (_clients.isEmpty)
          const EmptyState(emoji: '👥', titre: 'Aucun client livraison pour le moment', sousTitre: 'Les clients apparaîtront ici dès leur première commande en livraison.')
        else
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return Column(children: _clients.map(_carteClientMobile).toList());
            }
            return Container(
              decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Téléphone')),
                    DataColumn(label: Text('Dernière adresse')),
                    DataColumn(label: Text('Commandes')),
                    DataColumn(label: Text('Total dépensé')),
                    DataColumn(label: Text('Dernière commande')),
                  ],
                  rows: _clients.map((c) {
                    final date = DateTime.parse(c['derniere_commande']);
                    return DataRow(cells: [
                      DataCell(Text(c['telephone'])),
                      DataCell(Text(c['derniere_adresse'] ?? '—')),
                      DataCell(Text('${c['nombre_commandes']}')),
                      DataCell(Text('${c['total_depense'].toStringAsFixed(0)} F')),
                      DataCell(Text(DateFormat('dd/MM HH:mm', 'fr_FR').format(date))),
                    ]);
                  }).toList(),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _carteClientMobile(Map<String, dynamic> c) {
    final date = DateTime.parse(c['derniere_commande']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c['telephone'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text('📍 ${c['derniere_adresse'] ?? "—"}', style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${c['nombre_commandes']} commande(s)', style: const TextStyle(fontSize: 12.5)),
              Text('${c['total_depense'].toStringAsFixed(0)} F', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.redDim)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Dernière commande : ${DateFormat('dd/MM HH:mm', 'fr_FR').format(date)}', style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}
