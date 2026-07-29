import 'dart:async';
import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/api_client.dart';
import '../../services/websocket_service.dart';
import '../../services/son_service.dart';
import '../../models/commande.dart';
import '../../widgets/page_hero.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/app_top_bar.dart';

class LivraisonScreen extends StatefulWidget {
  const LivraisonScreen({super.key});

  @override
  State<LivraisonScreen> createState() => _LivraisonScreenState();
}

class _LivraisonScreenState extends State<LivraisonScreen> {
  List<Commande> _commandes = [];
  final Map<int, bool> _enTraitement = {};
  final _ws = WebSocketService();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _charger();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _charger());
    _ws.connecterDashboard('livraison', (data) {
      if (!mounted) return;
      if (data['evenement'] == 'commande_prete') SonService.jouerNotification();
      _charger();
    });
  }

  @override
  void dispose() {
    _ws.fermer();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    final reponse = await ApiClient().dio.get('livraison/commandes/');
    if (!mounted) return;
    setState(() => _commandes = (reponse.data as List).map((c) => Commande.fromJson(c)).toList());
  }

  Future<void> _prendreEnCharge(int id) async {
    setState(() => _enTraitement[id] = true);
    try {
      await ApiClient().dio.patch('livraison/commandes/$id/prendre/');
      await _charger();
    } finally {
      _enTraitement.remove(id);
    }
  }

  Future<void> _marquerLivree(int id) async {
    setState(() => _enTraitement[id] = true);
    try {
      await ApiClient().dio.patch('livraison/commandes/$id/livree/');
      setState(() => _commandes.removeWhere((c) => c.id == id));
    } finally {
      _enTraitement.remove(id);
    }
  }

  int _minutesDepuis(DateTime date) => DateTime.now().difference(date).inMinutes;

  @override
  Widget build(BuildContext context) {
    final aLivrer = _commandes.where((c) => c.statut == 'PRETE').toList();
    final enCours = _commandes.where((c) => c.statut == 'EN_LIVRAISON').toList();

    return Scaffold(
      appBar: const AppTopBar(),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          children: [
            PageHero(
              icon: '🛵',
              title: 'Livraisons',
              subtitle: 'Commandes prêtes à livrer, et celles déjà en route.',
              live: _ws.connecte,
            ),
            if (_commandes.isEmpty)
              const EmptyState(
                emoji: '📦',
                titre: 'Aucune livraison pour le moment',
                sousTitre: 'Les commandes prêtes en mode livraison apparaîtront ici.',
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (enCours.isNotEmpty) ...[
                      const Text('En cours de livraison', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 10),
                      ...enCours.map((c) => _buildCarte(c, enCours: true)),
                      const SizedBox(height: 18),
                    ],
                    if (aLivrer.isNotEmpty) ...[
                      const Text('Prêtes à livrer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 10),
                      ...aLivrer.map((c) => _buildCarte(c, enCours: false)),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarte(Commande cmd, {required bool enCours}) {
    final enTraitement = _enTraitement[cmd.id] == true;
    final attente = _minutesDepuis(cmd.dateCreation);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: enCours ? AppColors.green : (attente >= 10 ? AppColors.red : AppColors.line), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('#${cmd.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(enCours ? 'En route' : '⏱ prête depuis $attente min',
                  style: TextStyle(fontSize: 10.5, color: enCours ? AppColors.greenDim : AppColors.inkSoft, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text('📍 ${cmd.adresseLivraison}', style: const TextStyle(fontSize: 12.5)),
          Text('📞 ${cmd.telephoneClient}', style: const TextStyle(fontSize: 12.5)),
          const SizedBox(height: 8),
          Text(
            cmd.lignes.map((l) => '${l.quantite}x ${l.platNom}${l.details}').join(' · '),
            style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 8),
          Text('${cmd.total.toStringAsFixed(0)} F', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.redDim)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: enCours
                ? ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
                    onPressed: enTraitement ? null : () => _marquerLivree(cmd.id),
                    child: Text(enTraitement ? '...' : '✓ Marquer livrée'),
                  )
                : ElevatedButton(
                    onPressed: enTraitement ? null : () => _prendreEnCharge(cmd.id),
                    child: Text(enTraitement ? '...' : '🛵 Je prends cette livraison'),
                  ),
          ),
        ],
      ),
    );
  }
}
