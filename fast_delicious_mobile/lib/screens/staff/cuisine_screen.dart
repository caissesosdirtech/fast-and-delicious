import 'dart:async';
import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/api_client.dart';
import '../../services/websocket_service.dart';
import '../../services/son_service.dart';
import '../../models/commande.dart';
import '../../widgets/staff_scaffold.dart';
import '../../widgets/empty_state.dart';

class CuisineScreen extends StatefulWidget {
  const CuisineScreen({super.key});

  @override
  State<CuisineScreen> createState() => _CuisineScreenState();
}

class _CuisineScreenState extends State<CuisineScreen> {
  int _rubrique = 0;
  List<Commande> _commandes = [];
  final Map<int, bool> _enTraitement = {};
  final _ws = WebSocketService();
  Timer? _timerRafraichissement;
  Timer? _timerHorloge;

  @override
  void initState() {
    super.initState();
    _charger();
    _timerRafraichissement = Timer.periodic(const Duration(seconds: 15), (_) => _charger());
    _timerHorloge = Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));
    _ws.connecterDashboard('cuisine', (data) {
      if (!mounted) return;
      if (data['evenement'] == 'commande_validee') SonService.jouerNotification();
      _charger();
    });
  }

  @override
  void dispose() {
    _ws.fermer();
    _timerRafraichissement?.cancel();
    _timerHorloge?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    final reponse = await ApiClient().dio.get('cuisine/commandes/');
    if (!mounted) return;
    setState(() => _commandes = (reponse.data as List).map((c) => Commande.fromJson(c)).toList());
  }

  Future<void> _demarrerPreparation(int id) async {
    setState(() => _enTraitement[id] = true);
    try {
      await ApiClient().dio.patch('cuisine/commandes/$id/preparer/');
      await _charger();
    } finally {
      _enTraitement.remove(id);
    }
  }

  Future<void> _marquerPrete(int id) async {
    setState(() => _enTraitement[id] = true);
    try {
      await ApiClient().dio.patch('cuisine/commandes/$id/prete/');
      await _charger();
    } finally {
      _enTraitement.remove(id);
    }
  }

  /// Marque une commande sur place comme servie — c'est l'étape qui manquait :
  /// sans ça, le client ne voit jamais "Servie" sur son suivi.
  Future<void> _marquerServie(int id) async {
    setState(() => _enTraitement[id] = true);
    try {
      await ApiClient().dio.patch('commandes/$id/servie/');
      setState(() => _commandes.removeWhere((c) => c.id == id));
    } finally {
      _enTraitement.remove(id);
    }
  }

  int _minutesDepuis(DateTime date) => DateTime.now().difference(date).inMinutes;

  /// Temps moyen d'attente (en minutes) des commandes actuellement dans le rail —
  /// donnée informative simple calculée côté client (pas un vrai historique statistique).
  String get _tempsMoyenPreparation {
    if (_commandes.isEmpty) return '--:--';
    final total = _commandes.fold<int>(0, (acc, c) => acc + _minutesDepuis(c.dateCreation));
    final moyenne = (total / _commandes.length).round();
    return '${moyenne.toString().padLeft(2, "0")}:00';
  }

  @override
  Widget build(BuildContext context) {
    final nouvelles = _commandes.where((c) => c.statut == 'VALIDEE').toList();
    final enPreparation = _commandes.where((c) => c.statut == 'EN_PREPARATION').toList();
    final pretes = _commandes.where((c) => c.statut == 'PRETE').toList();

    return StaffScaffold(
      items: const [
        SidebarItem('🧾', 'Commandes'),
        SidebarItem('🍳', 'En préparation'),
        SidebarItem('✅', 'Prêtes'),
        SidebarItem('🕓', 'Historique'),
      ],
      indexActif: _rubrique,
      onChangerIndex: (i) => setState(() => _rubrique = i),
      contenu: RefreshIndicator(
        onRefresh: _charger,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final colonnes = <Widget>[
                    _colonne('Nouvelles commandes', nouvelles, AppColors.gold, etape: _EtapeCarte.nouvelle),
                    _colonne('En préparation', enPreparation, AppColors.red, etape: _EtapeCarte.enPreparation),
                    _colonne('Prêtes à servir', pretes, AppColors.green, etape: _EtapeCarte.prete),
                  ];
                  if (constraints.maxWidth >= 1100) {
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: colonnes.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 14), child: c))).toList(),
                      ),
                    );
                  }
                  return Column(children: colonnes.map((c) => Padding(padding: const EdgeInsets.only(bottom: 16), child: c)).toList());
                },
              ),
              const SizedBox(height: 20),
              Container(
                width: 220,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    const Text('TEMPS MOYEN D\'ATTENTE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.inkSoft, letterSpacing: 0.4)),
                    const SizedBox(height: 6),
                    Text(_tempsMoyenPreparation, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const Text('min', style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colonne(String titre, List<Commande> liste, Color couleurBadge, {required _EtapeCarte etape}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: couleurBadge, borderRadius: BorderRadius.circular(10)),
                child: Text('${liste.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (liste.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: EmptyState(emoji: '🍲', titre: 'Rien ici'))
          else
            ...liste.map((cmd) => _carteCommande(cmd, etape: etape)),
        ],
      ),
    );
  }

  Widget _carteCommande(Commande cmd, {required _EtapeCarte etape}) {
    final enTraitement = _enTraitement[cmd.id] == true;
    final attente = _minutesDepuis(etape == _EtapeCarte.prete && cmd.tempsRestantEstimeMin == 0 ? cmd.dateCreation : cmd.dateCreation);

    String labelBouton;
    Color couleurBouton;
    Color? couleurTexte;
    VoidCallback action;

    switch (etape) {
      case _EtapeCarte.nouvelle:
        labelBouton = 'Commencer';
        couleurBouton = AppColors.gold;
        couleurTexte = AppColors.ink;
        action = () => _demarrerPreparation(cmd.id);
        break;
      case _EtapeCarte.enPreparation:
        labelBouton = 'Terminer';
        couleurBouton = AppColors.green;
        couleurTexte = Colors.white;
        action = () => _marquerPrete(cmd.id);
        break;
      case _EtapeCarte.prete:
        labelBouton = 'Marquer comme servie';
        couleurBouton = AppColors.ink;
        couleurTexte = AppColors.cream;
        action = () => _marquerServie(cmd.id);
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('#${cmd.id} — ${cmd.enLivraison ? "🛵 Livraison" : (cmd.numeroTable ?? "—")}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          ...cmd.lignes.map((l) => Text('${l.quantite}x ${l.platNom}${l.details}', style: const TextStyle(fontSize: 11.5))),
          const SizedBox(height: 6),
          Text(
            etape == _EtapeCarte.prete ? 'Prête depuis : ${attente.toString().padLeft(2, "0")} min' : 'Temps écoulé : ${attente.toString().padLeft(2, "0")} min',
            style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: couleurBouton, foregroundColor: couleurTexte),
              onPressed: enTraitement ? null : action,
              child: Text(enTraitement ? '...' : labelBouton),
            ),
          ),
        ],
      ),
    );
  }
}

enum _EtapeCarte { nouvelle, enPreparation, prete }
