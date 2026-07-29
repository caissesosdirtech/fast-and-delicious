import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../config/theme.dart';
import '../../services/api_client.dart';
import '../../services/websocket_service.dart';
import '../../services/son_service.dart';
import '../../widgets/staff_scaffold.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/empty_state.dart';
import '../../utils/labels_statut.dart';
import '../../widgets/produits_contenu.dart';
import '../../widgets/categories_contenu.dart';
import '../../widgets/tables_contenu.dart';
import '../../widgets/employes_contenu.dart';
import '../../widgets/lieux_contenu.dart';
import '../../widgets/parametres_contenu.dart';
import '../../widgets/ticket_detail.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _rubrique = 0;
  int _ongletDashboardMobile = 0; // 0 Aperçu, 1 Ventes, 2 Commandes, 3 Activité
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _lieux = [];
  int? _lieuFiltre; // null = tous les lieux
  DateTime? _dateFiltre; // null = aujourd'hui
  Timer? _timer;
  final _wsCaisse = WebSocketService();
  final _wsCuisine = WebSocketService();
  final _wsLivraison = WebSocketService();
  final List<String> _activiteTempsReel = [];

  @override
  void initState() {
    super.initState();
    _charger();
    ApiClient().dio.get('menu/lieux/').then((r) {
      if (mounted) setState(() => _lieux = List<Map<String, dynamic>>.from(r.data));
    });
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_dateFiltre == null) _charger(silencieux: true);
    });

    void surEvenement(String origine, Map<String, dynamic> data) {
      if (!mounted || _dateFiltre != null) return; // événements ignorés hors de "aujourd'hui"
      SonService.jouerNotification();
      final evenement = data['evenement'] ?? '';
      final idCmd = data['commande_id'];
      setState(() {
        _activiteTempsReel.insert(0, '$evenement — Commande #$idCmd ($origine)');
        if (_activiteTempsReel.length > 8) _activiteTempsReel.removeLast();
      });
      _charger(silencieux: true);
    }

    _wsCaisse.connecterDashboard('caisse', (d) => surEvenement('caisse', d));
    _wsCuisine.connecterDashboard('cuisine', (d) => surEvenement('cuisine', d));
    _wsLivraison.connecterDashboard('livraison', (d) => surEvenement('livraison', d));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wsCaisse.fermer();
    _wsCuisine.fermer();
    _wsLivraison.fermer();
    super.dispose();
  }

  Future<void> _charger({bool silencieux = false}) async {
    final reponse = await ApiClient().dio.get('admin/statistiques/', queryParameters: {
      if (_lieuFiltre != null) 'lieu': _lieuFiltre,
      if (_dateFiltre != null) 'date': DateFormat('yyyy-MM-dd').format(_dateFiltre!),
    });
    if (mounted) setState(() => _stats = reponse.data);
  }

  Future<void> _choisirDate() async {
    final choisie = await showDatePicker(
      context: context,
      initialDate: _dateFiltre ?? DateTime.now(),
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now(),
    );
    if (choisie == null) return;
    final aujourdhui = DateTime.now();
    final estAujourdhui = choisie.year == aujourdhui.year && choisie.month == aujourdhui.month && choisie.day == aujourdhui.day;
    setState(() => _dateFiltre = estAujourdhui ? null : choisie);
    _charger();
  }

  String _fmt(dynamic v) => NumberFormat('#,###', 'fr_FR').format(double.parse(v.toString())).replaceAll(',', ' ');

  @override
  Widget build(BuildContext context) {
    return StaffScaffold(
      items: const [
        SidebarItem('📊', 'Dashboard'),
        SidebarItem('🍔', 'Produits'),
        SidebarItem('🏷️', 'Catégories'),
        SidebarItem('🍽️', 'Tables'),
        SidebarItem('📍', 'Lieux'),
        SidebarItem('👤', 'Employés'),
        SidebarItem('🧾', 'Commandes'),
        SidebarItem('📈', 'Statistiques'),
        SidebarItem('⚙️', 'Paramètres'),
      ],
      indexActif: _rubrique,
      onChangerIndex: (i) => setState(() => _rubrique = i),
      contenu: RefreshIndicator(
        onRefresh: _charger,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _contenuRubrique(),
        ),
      ),
    );
  }

  Widget _contenuRubrique() {
    switch (_rubrique) {
      case 1: return const ProduitsContenu();
      case 2: return const CategoriesContenu();
      case 3: return const TablesContenu();
      case 4: return const LieuxContenu();
      case 5: return const EmployesContenu();
      case 8: return const ParametresContenu();
      default: return _buildDashboard(); // 0 Dashboard, 6 Commandes, 7 Statistiques
    }
  }

  Widget _buildDashboard() {
    if (_stats == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }
    final s = _stats!;
    final date = DateTime.parse(s['date']);
    final commandesParStatut = Map<String, dynamic>.from(s['commandes_par_statut']);
    final topPlats = List<Map<String, dynamic>>.from(s['top_plats']).take(5).toList();
    final commandesRecentes = List<Map<String, dynamic>>.from(s['commandes_recentes']);
    final ventes7Jours = List<Map<String, dynamic>>.from(s['ventes_7_jours']);

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 700) {
        return _buildDashboardMobile(s, date, commandesParStatut, topPlats, commandesRecentes, ventes7Jours, constraints.maxWidth);
      }
      return _buildDashboardLarge(s, date, commandesParStatut, topPlats, commandesRecentes, ventes7Jours);
    });
  }

  Widget _enTeteDashboard(Map<String, dynamic> s, DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bienvenue, Admin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Aperçu de votre activité — ${DateFormat.yMMMMd('fr_FR').format(date)}',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            IconButton(onPressed: _choisirDate, icon: const Icon(Icons.calendar_month)),
            IconButton(onPressed: () => _charger(), icon: const Icon(Icons.refresh)),
          ],
        ),
        if (s['est_aujourdhui'] == false) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.cream2, borderRadius: BorderRadius.circular(9)),
            child: Row(
              children: [
                const Text('🕓 ', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Text('Historique du ${DateFormat.yMMMMd('fr_FR').format(date)}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _dateFiltre = null);
                    _charger();
                  },
                  child: const Text('↩ Aujourd\'hui', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.redDim)),
                ),
              ],
            ),
          ),
        ],
        if (_lieux.length > 1) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(9)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: _lieuFiltre,
                isDense: true,
                icon: const Icon(Icons.expand_more, size: 18),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('📍 Tous les lieux', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)))),
                  ..._lieux.map((l) => DropdownMenuItem<int?>(
                        value: l['id'] as int,
                        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('📍 ${l['nom']}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold))),
                      )),
                ],
                onChanged: (v) {
                  setState(() => _lieuFiltre = v);
                  _charger();
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Version mobile : organisée en onglets (Aperçu / Ventes / Commandes / Activité) plutôt
  /// qu'un long défilement — chaque section tient sur l'écran, plus facile à parcourir.
  Widget _buildDashboardMobile(
    Map<String, dynamic> s, DateTime date, Map<String, dynamic> commandesParStatut,
    List<Map<String, dynamic>> topPlats, List<Map<String, dynamic>> commandesRecentes, List<Map<String, dynamic>> ventes7Jours,
    double largeurDisponible,
  ) {
    const onglets = [
      ('📊', 'Aperçu'), ('📈', 'Ventes'), ('🧾', 'Commandes'), ('📡', 'Activité'),
    ];
    final largeurKpi = (largeurDisponible - 12) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _enTeteDashboard(s, date),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(onglets.length, (i) {
              final actif = _ongletDashboardMobile == i;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _ongletDashboardMobile = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: actif ? AppColors.ink : AppColors.panel,
                      border: Border.all(color: actif ? AppColors.ink : AppColors.line, width: 1.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${onglets[i].$1} ${onglets[i].$2}',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: actif ? Colors.white : AppColors.inkSoft),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 18),

        if (_ongletDashboardMobile == 0) ...[
          Wrap(
            spacing: 12, runSpacing: 12,
            children: [
              SizedBox(width: largeurKpi, child: KpiCard(label: 'Commandes du jour', valeur: '${s['nombre_commandes']}')),
              SizedBox(width: largeurKpi, child: KpiCard(label: "Chiffre d'affaires", valeur: '${_fmt(s['chiffre_affaires'])} F', couleurValeur: AppColors.green)),
              SizedBox(width: largeurKpi, child: KpiCard(label: 'En attente', valeur: '${commandesParStatut['EN_ATTENTE'] ?? 0}', couleurValeur: AppColors.gold)),
              SizedBox(width: largeurKpi, child: KpiCard(label: 'En préparation', valeur: '${commandesParStatut['EN_PREPARATION'] ?? 0}')),
            ],
          ),
          const SizedBox(height: 16),
          _panel(titre: 'Répartition des commandes', enfant: _repartitionStatuts(commandesParStatut)),
        ],

        if (_ongletDashboardMobile == 1) ...[
          _panel(titre: 'Ventes des 7 derniers jours', enfant: _graphiqueVentes(ventes7Jours)),
          const SizedBox(height: 14),
          _panel(titre: 'Top 5 des produits', enfant: _graphiquePie(topPlats)),
        ],

        if (_ongletDashboardMobile == 2)
          _panel(titre: 'Commandes récentes', enfant: _tableCommandesRecentes(commandesRecentes)),

        if (_ongletDashboardMobile == 3)
          _panel(titre: 'Activité en temps réel', enfant: _activite()),
      ],
    );
  }

  Widget _repartitionStatuts(Map<String, dynamic> commandesParStatut) {
    final total = commandesParStatut.values.fold<int>(0, (acc, v) => acc + (v as int));
    if (total == 0) return const EmptyState(emoji: '📭', titre: 'Aucune commande aujourd\'hui');

    return Column(
      children: commandesParStatut.entries.map((e) {
        final ratio = (e.value as int) / total;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              SizedBox(width: 100, child: Text(labelsStatut[e.key] ?? e.key, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio, minHeight: 8,
                    backgroundColor: AppColors.cream2,
                    valueColor: AlwaysStoppedAnimation(couleurStatut[e.key] ?? AppColors.gold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 26, child: Text('${e.value}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Version large (tablette/desktop) : tout sur un seul écran, graphiques et tableaux côte à côte.
  Widget _buildDashboardLarge(
    Map<String, dynamic> s, DateTime date, Map<String, dynamic> commandesParStatut,
    List<Map<String, dynamic>> topPlats, List<Map<String, dynamic>> commandesRecentes, List<Map<String, dynamic>> ventes7Jours,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _enTeteDashboard(s, date),
        const SizedBox(height: 20),

        // KPI
        Wrap(
          spacing: 12, runSpacing: 12,
          children: [
            SizedBox(width: 170, child: KpiCard(label: 'Commandes du jour', valeur: '${s['nombre_commandes']}')),
            SizedBox(width: 170, child: KpiCard(label: "Chiffre d'affaires", valeur: '${_fmt(s['chiffre_affaires'])} F', couleurValeur: AppColors.green)),
            SizedBox(width: 170, child: KpiCard(label: 'En attente', valeur: '${commandesParStatut['EN_ATTENTE'] ?? 0}', couleurValeur: AppColors.gold)),
            SizedBox(width: 170, child: KpiCard(label: 'En préparation', valeur: '${commandesParStatut['EN_PREPARATION'] ?? 0}')),
          ],
        ),
        const SizedBox(height: 24),

        LayoutBuilder(builder: (context, constraints) {
          final large = constraints.maxWidth >= 820;
          final graphiques = [
            Expanded(flex: 3, child: _panel(titre: 'Ventes des 7 derniers jours', enfant: _graphiqueVentes(ventes7Jours))),
            const SizedBox(width: 14, height: 14),
            Expanded(flex: 2, child: _panel(titre: 'Top 5 des produits', enfant: _graphiquePie(topPlats))),
          ];
          if (large) return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: graphiques));
          return Column(children: [graphiques[0], const SizedBox(height: 14), graphiques[2]]);
        }),
        const SizedBox(height: 14),

        LayoutBuilder(builder: (context, constraints) {
          final large = constraints.maxWidth >= 820;
          final blocs = [
            Expanded(flex: 3, child: _panel(titre: 'Commandes récentes', enfant: _tableCommandesRecentes(commandesRecentes))),
            const SizedBox(width: 14, height: 14),
            Expanded(flex: 2, child: _panel(titre: 'Activité en temps réel', enfant: _activite())),
          ];
          if (large) return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: blocs));
          return Column(children: [blocs[0], const SizedBox(height: 14), blocs[2]]);
        }),
      ],
    );
  }

  Widget _panel({required String titre, required Widget enfant}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 14),
          enfant,
        ],
      ),
    );
  }

  Widget _graphiqueVentes(List<Map<String, dynamic>> ventes) {
    final jours = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    final spots = List.generate(ventes.length, (i) {
      final total = double.tryParse(ventes[i]['total'].toString()) ?? 0;
      return FlSpot(i.toDouble(), total);
    });
    final maxY = (spots.map((s) => s.y).fold<double>(0, (a, b) => a > b ? a : b)) * 1.2 + 1;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= ventes.length) return const SizedBox.shrink();
                  final date = DateTime.parse(ventes[i]['date']);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(jours[(date.weekday - 1) % 7], style: const TextStyle(fontSize: 10, color: AppColors.inkSoft)),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.red,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: AppColors.red.withOpacity(0.08)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _graphiquePie(List<Map<String, dynamic>> topPlats) {
    if (topPlats.isEmpty) return const EmptyState(emoji: '🍽️', titre: 'Pas encore de ventes');

    final couleurs = [AppColors.red, AppColors.gold, AppColors.green, const Color(0xFF6D28D9), const Color(0xFF1D5BA8)];
    final total = topPlats.fold<int>(0, (acc, p) => acc + (p['quantite'] as int));

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: List.generate(topPlats.length, (i) {
                final q = topPlats[i]['quantite'] as int;
                final pourcentage = total == 0 ? 0 : (q / total * 100);
                return PieChartSectionData(
                  value: q.toDouble(),
                  color: couleurs[i % couleurs.length],
                  title: '${pourcentage.toStringAsFixed(0)}%',
                  radius: 45,
                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(topPlats.length, (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(width: 9, height: 9, decoration: BoxDecoration(color: couleurs[i % couleurs.length], shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(topPlats[i]['nom'], style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis)),
                  Text('${topPlats[i]['quantite']}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                ],
              ),
            )),
      ],
    );
  }

  Widget _tableCommandesRecentes(List<Map<String, dynamic>> commandes) {
    if (commandes.isEmpty) return const EmptyState(emoji: '🧾', titre: 'Aucune commande pour le moment');

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 600) {
        return Column(children: commandes.map(_carteCommandeRecenteMobile).toList());
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 18,
          columns: const [
            DataColumn(label: Text('N°')),
            DataColumn(label: Text('Table')),
            DataColumn(label: Text('Articles')),
            DataColumn(label: Text('Heure')),
            DataColumn(label: Text('Montant')),
            DataColumn(label: Text('Paiement')),
            DataColumn(label: Text('Référence')),
            DataColumn(label: Text('Statut')),
          ],
          rows: commandes.map((c) {
            final modePaiement = c['mode_paiement'] as String;
            final date = DateTime.parse(c['date_creation']);
            final lignes = List<Map<String, dynamic>>.from(c['lignes'] ?? []);
            final resumeArticles = lignes.map((l) => '${l['quantite']}x ${l['plat_nom']}').join(', ');
            return DataRow(
              onSelectChanged: (_) => ouvrirTicketDetail(context, c),
              cells: [
                DataCell(Text('#${c['id']}')),
                DataCell(Text(c['numero_table'] ?? '—')),
                DataCell(SizedBox(width: 180, child: Text(resumeArticles, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis))),
                DataCell(Text(DateFormat.Hm('fr_FR').format(date))),
                DataCell(Text('${_fmt(c['total'])} F')),
                DataCell(Text(
                  modePaiement == 'ESPECES' ? '💵 Espèces' : (modePaiement == 'WAVE' ? '🌊 Wave' : (modePaiement == 'ORANGE_MONEY' ? '🟠 Orange Money' : '🔷 QR')),
                  style: const TextStyle(fontSize: 11.5),
                )),
                DataCell(Text(modePaiement == 'ESPECES' ? '—' : (c['reference_paiement'] ?? ''), style: const TextStyle(fontSize: 11.5, color: AppColors.redDim))),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: (couleurStatut[c['statut']] ?? AppColors.gold).withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
                  child: Text(labelsStatut[c['statut']] ?? c['statut'], style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: couleurStatut[c['statut']] ?? AppColors.gold)),
                )),
              ],
            );
          }).toList(),
        ),
      );
    });
  }

  Widget _carteCommandeRecenteMobile(Map<String, dynamic> c) {
    final modePaiement = c['mode_paiement'] as String;
    final date = DateTime.parse(c['date_creation']);
    final lignes = List<Map<String, dynamic>>.from(c['lignes'] ?? []);
    final resumeArticles = lignes.map((l) => '${l['quantite']}x ${l['plat_nom']}').join(', ');

    return InkWell(
      onTap: () => ouvrirTicketDetail(context, c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('#${c['id']}  ${c['numero_table'] ?? "—"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: (couleurStatut[c['statut']] ?? AppColors.gold).withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
                  child: Text(labelsStatut[c['statut']] ?? c['statut'], style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: couleurStatut[c['statut']] ?? AppColors.gold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(resumeArticles, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat.Hm('fr_FR').format(date), style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                Text('${_fmt(c['total'])} F', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            if (modePaiement != 'ESPECES')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${modePaiement == "WAVE" ? "🌊 Wave" : modePaiement == "ORANGE_MONEY" ? "🟠 Orange Money" : "🔷 QR"} · réf. ${c['reference_paiement']}',
                  style: const TextStyle(fontSize: 11, color: AppColors.redDim),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _activite() {
    if (_activiteTempsReel.isEmpty) {
      return const EmptyState(emoji: '📡', titre: 'En attente d\'activité', sousTitre: 'Les événements en direct apparaîtront ici.');
    }
    return Column(
      children: _activiteTempsReel.map((e) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: AppColors.cream2, borderRadius: BorderRadius.circular(8)),
            child: Text(e, style: const TextStyle(fontSize: 11.5)),
          )).toList(),
    );
  }
}
