import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme.dart';
import '../../services/api_client.dart';
import '../../services/websocket_service.dart';
import '../../services/son_service.dart';
import '../../services/notifications_service.dart';
import '../../models/commande.dart';
import '../../widgets/staff_scaffold.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/empty_state.dart';
import '../../utils/labels_statut.dart';
import '../../widgets/dialogue_annulation.dart';
import '../../widgets/clients_contenu.dart';
import '../../widgets/parametres_contenu.dart';
import '../../widgets/ticket_detail.dart';

class CaisseScreen extends StatefulWidget {
  const CaisseScreen({super.key});

  @override
  State<CaisseScreen> createState() => _CaisseScreenState();
}

/// Action principale d'une commande selon son statut (flux simplifié :
/// EN_ATTENTE → Valider → VALIDEE → Prête → PRETE → Terminer → SERVIE).
class _ActionPrincipale {
  final String label;
  final IconData icone;
  final Color couleur;
  final Future<void> Function(int) action;
  const _ActionPrincipale(this.label, this.icone, this.couleur, this.action);
}

class _CaisseScreenState extends State<CaisseScreen> {
  int _rubrique = 0; // 0 Tableau de bord, 1 Commandes, 2 Paiements, 3 Historique, 4 Clients, 5 Paramètres

  List<Commande> _fileAttente = [];
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>>? _paiementsRecents;
  List<Map<String, dynamic>>? _historiqueRecent;
  Commande? _selectionnee;
  bool _exportEnCours = false;
  final Map<int, bool> _enTraitement = {};
  final _ws = WebSocketService();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _charger();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _charger(silencieux: true));
    _ws.connecterDashboard('caisse', (data) {
      if (!mounted) return;
      if (data['evenement'] == 'nouvelle_commande') {
        SonService.jouerNotification();
      }
      _charger(silencieux: true); // met aussi à jour le badge (commandes en attente)
      if (_rubrique == 2) _chargerPaiementsRecents();
      if (_rubrique == 3) _chargerHistoriqueRecent();
    });
  }

  @override
  void dispose() {
    _ws.fermer();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _charger({bool silencieux = false}) async {
    final resultats = await Future.wait([
      ApiClient().dio.get('caisse/commandes/'),
      ApiClient().dio.get('admin/statistiques/'),
    ]);
    if (!mounted) return;
    setState(() {
      _fileAttente = (resultats[0].data as List).map((c) => Commande.fromJson(c)).toList();
      _stats = resultats[1].data;
      // Garde la sélection synchronisée avec les données fraîches, si elle existe encore.
      if (_selectionnee != null) {
        try {
          _selectionnee = _fileAttente.firstWhere((c) => c.id == _selectionnee!.id);
        } catch (_) {
          _selectionnee = null;
        }
      }
    });
    // Badge = nombre de commandes réellement en attente (baisse quand on les traite).
    NotificationsService.instance.definir(_fileAttente.where((c) => c.statut == 'EN_ATTENTE').length);
  }

  Future<void> _chargerPaiementsRecents() async {
    final reponse = await ApiClient().dio.get('caisse/paiements-recents/');
    if (mounted) setState(() => _paiementsRecents = List<Map<String, dynamic>>.from(reponse.data));
  }

  Future<void> _chargerHistoriqueRecent() async {
    final reponse = await ApiClient().dio.get('caisse/historique-recent/');
    if (mounted) setState(() => _historiqueRecent = List<Map<String, dynamic>>.from(reponse.data));
  }

  /// Affiche un message d'erreur lisible (code HTTP + détail serveur) quand une
  /// action échoue, au lieu de laisser le bouton bloqué sans explication.
  void _afficherErreur(Object e) {
    String msg = 'Action impossible. Vérifie ta connexion.';
    if (e is DioException) {
      final code = e.response?.statusCode;
      final data = e.response?.data;
      String detail = '';
      if (data is Map && data['detail'] != null) {
        detail = data['detail'].toString();
      } else if (data is Map && data.isNotEmpty) {
        detail = data.values.first.toString();
      } else if (e.message != null) {
        detail = e.message!;
      }
      msg = 'Erreur ${code ?? ''}${detail.isNotEmpty ? ' : $detail' : ''}'.trim();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.red, duration: const Duration(seconds: 4)),
      );
    }
  }

  /// Exécute une action PATCH sur une commande, en gérant l'état « en traitement »,
  /// le rafraîchissement et l'affichage des erreurs de façon uniforme.
  Future<void> _executerAction(int id, String chemin, {Map<String, dynamic>? corps}) async {
    setState(() => _enTraitement[id] = true);
    try {
      await ApiClient().dio.patch(chemin, data: corps);
      await _charger(silencieux: true);
    } catch (e) {
      _afficherErreur(e);
    } finally {
      if (mounted) {
        setState(() => _enTraitement.remove(id));
      } else {
        _enTraitement.remove(id);
      }
    }
  }

  Future<void> _encaisser(int id) => _executerAction(id, 'caisse/commandes/$id/encaisser/');

  Future<void> _valider(int id) => _executerAction(id, 'caisse/commandes/$id/valider/');

  Future<void> _marquerPrete(int id) => _executerAction(id, 'caisse/commandes/$id/prete/');

  Future<void> _terminer(int id) => _executerAction(id, 'caisse/commandes/$id/terminer/');

  Future<void> _annuler(int id) async {
    final motif = await demanderMotifAnnulation(context);
    if (motif == null) return; // dialogue fermé sans confirmer
    await _executerAction(id, 'commandes/$id/annuler/', corps: {'motif': motif});
  }

  void _ouvrirRecu(Commande cmd) => ouvrirTicketDetail(context, cmd.toTicketMap());

  /// Télécharge le rapport de caisse du jour (PDF ou Excel) et ouvre le partage
  /// (enregistrer dans Fichiers, envoyer par WhatsApp/mail, etc.).
  Future<void> _exporter(String format) async {
    setState(() => _exportEnCours = true);
    try {
      final res = await ApiClient().dio.get(
        'admin/caisse/export/',
        queryParameters: {'format': format, 'periode': 'jour'},
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = (res.data as List).cast<int>();
      final dossier = Directory.systemTemp.createTempSync('caisse');
      final ext = format == 'xlsx' ? 'xlsx' : 'pdf';
      final chemin = '${dossier.path}/rapport_caisse_du_jour.$ext';
      await File(chemin).writeAsBytes(bytes);
      await Share.shareXFiles([XFile(chemin)], subject: 'Rapport de caisse du jour');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Téléchargement impossible.'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exportEnCours = false);
    }
  }

  /// Renvoie l'action principale à proposer selon le statut, ou null si la
  /// commande est terminée / annulée (plus d'action de progression).
  _ActionPrincipale? _actionPrincipale(String statut) {
    switch (statut) {
      case 'EN_ATTENTE':
        return _ActionPrincipale('Valider', Icons.check, AppColors.green, _valider);
      case 'VALIDEE':
        return _ActionPrincipale('Prête', Icons.play_arrow, const Color(0xFF1D5BA8), _marquerPrete);
      case 'PRETE':
        return _ActionPrincipale('Terminer', Icons.done_all, AppColors.greenDim, _terminer);
      default:
        return null;
    }
  }

  bool _estActive(String statut) => statut != 'SERVIE' && statut != 'ANNULEE';

  @override
  Widget build(BuildContext context) {
    return StaffScaffold(
      items: const [
        SidebarItem('📊', 'Tableau de bord'),
        SidebarItem('🧾', 'Commandes'),
        SidebarItem('💳', 'Paiements'),
        SidebarItem('🕓', 'Historique'),
        SidebarItem('👥', 'Clients'),
        SidebarItem('⚙️', 'Paramètres'),
      ],
      indexActif: _rubrique,
      onChangerIndex: (i) {
        setState(() => _rubrique = i);
        if (i == 2 && _paiementsRecents == null) _chargerPaiementsRecents();
        if (i == 3 && _historiqueRecent == null) _chargerHistoriqueRecent();
      },
      onNotificationsTap: () => setState(() => _rubrique = 0),
      contenu: RefreshIndicator(
        onRefresh: () async {
          if (_rubrique == 2) return _chargerPaiementsRecents();
          if (_rubrique == 3) return _chargerHistoriqueRecent();
          return _charger();
        },
        child: (_stats == null && _rubrique != 2 && _rubrique != 3 && _rubrique != 4 && _rubrique != 5)
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildContenuRubrique(),
                ],
              ),
      ),
    );
  }

  Widget _buildContenuRubrique() {
    switch (_rubrique) {
      case 2:
        if (_paiementsRecents == null) return const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()));
        return _buildListeSimple(
          titre: '10 derniers paiements mobile money',
          commandes: _paiementsRecents!,
          vide: 'Aucun paiement mobile money pour le moment.',
        );
      case 3:
        if (_historiqueRecent == null) return const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()));
        return _buildListeSimple(
          titre: '10 dernières commandes terminées',
          commandes: _historiqueRecent!,
          vide: 'Aucune commande terminée pour le moment.',
        );
      case 4:
        return const ClientsContenu();
      case 5:
        return const ParametresContenu();
      default:
        return _buildTableauDeBord();
    }
  }

  Widget _buildTableauDeBord() {
    final s = _stats!;
    final commandesParStatut = Map<String, dynamic>.from(s['commandes_par_statut']);

    return LayoutBuilder(builder: (context, constraints) {
      final etroit = constraints.maxWidth < 600;
      final largeurKpi = etroit ? (constraints.maxWidth - 12) / 2 : null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12, runSpacing: 12,
            children: [
              SizedBox(width: largeurKpi, child: KpiCard(label: 'En attente', valeur: '${commandesParStatut['EN_ATTENTE'] ?? 0}', couleurValeur: AppColors.gold)),
              SizedBox(width: largeurKpi, child: KpiCard(label: 'Validées', valeur: '${commandesParStatut['VALIDEE'] ?? 0}')),
              SizedBox(width: largeurKpi, child: KpiCard(label: 'Prêtes', valeur: '${commandesParStatut['PRETE'] ?? 0}', couleurValeur: AppColors.green)),
              SizedBox(width: largeurKpi, child: KpiCard(label: 'Commandes du jour', valeur: '${s['nombre_commandes']}')),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line.withOpacity(0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Rapport de caisse du jour', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    if (_exportEnCours)
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exportEnCours ? null : () => _exporter('pdf'),
                        icon: const Text('📄', style: TextStyle(fontSize: 14)),
                        label: const Text('PDF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exportEnCours ? null : () => _exporter('xlsx'),
                        icon: const Text('📊', style: TextStyle(fontSize: 14)),
                        label: const Text('Excel'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Commandes en cours', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Valider → Prête → Terminer', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          const SizedBox(height: 12),

          if (_fileAttente.isEmpty)
            const EmptyState(emoji: '📥', titre: 'Aucune commande en cours')
          else if (etroit)
            Column(children: _fileAttente.map(_carteCommandeMobile).toList())
          else
            Container(
              decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('N° Commande')),
                    DataColumn(label: Text('Table')),
                    DataColumn(label: Text('Heure')),
                    DataColumn(label: Text('Montant')),
                    DataColumn(label: Text('Statut')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: _fileAttente.map((cmd) {
                    final enTraitement = _enTraitement[cmd.id] == true;
                    final ap = _actionPrincipale(cmd.statut);
                    return DataRow(
                      selected: _selectionnee?.id == cmd.id,
                      onSelectChanged: (_) => setState(() => _selectionnee = cmd),
                      cells: [
                        DataCell(Text('#${cmd.id}')),
                        DataCell(Text(cmd.enLivraison ? '🛵' : (cmd.numeroTable ?? '—'))),
                        DataCell(Text(DateFormat.Hm('fr_FR').format(cmd.dateCreation))),
                        DataCell(Text('${cmd.total.toStringAsFixed(0)} F')),
                        DataCell(_badgeStatut(cmd.statut)),
                        DataCell(Row(children: [
                          if (ap != null)
                            _iconeAction(ap.icone, ap.couleur, ap.label, enTraitement ? null : () => ap.action(cmd.id)),
                          if (ap != null) const SizedBox(width: 6),
                          if (_estActive(cmd.statut))
                            _iconeAction(Icons.close, AppColors.red, 'Annuler', enTraitement ? null : () => _annuler(cmd.id)),
                          if (_estActive(cmd.statut)) const SizedBox(width: 6),
                          if (cmd.paiementConfirme || cmd.statut == 'SERVIE')
                            _iconeAction(Icons.receipt_long, const Color(0xFF8A6D1D), 'Reçu', () => _ouvrirRecu(cmd)),
                          if (cmd.paiementConfirme || cmd.statut == 'SERVIE') const SizedBox(width: 6),
                          _iconeAction(Icons.remove_red_eye, const Color(0xFF1D5BA8), 'Voir le détail', () => setState(() => _selectionnee = cmd)),
                        ])),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),

          if (_selectionnee != null) ...[
            const SizedBox(height: 20),
            _buildDetailCommande(_selectionnee!),
          ],
        ],
      );
    });
  }

  void _ouvrirDetailModal(Commande cmd) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final enTraitement = _enTraitement[cmd.id] == true;
          final ap = _actionPrincipale(cmd.statut);

          Future<void> lancer(Future<void> Function(int) action) async {
            setModal(() {});
            await action(cmd.id);
            if (ctx.mounted) Navigator.pop(ctx);
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.3,
            maxChildSize: 0.92,
            expand: false,
            builder: (ctx, scrollController) => Container(
              decoration: const BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Détails commande #${cmd.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...cmd.lignes.map((l) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text('${l.quantite}x ${l.platNom}${l.details}', style: const TextStyle(fontSize: 13.5))),
                            Text('${l.sousTotal.toStringAsFixed(0)} F', style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft)),
                          ],
                        ),
                      )),
                  if (cmd.remarque != null && cmd.remarque!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Remarque client : ${cmd.remarque}', style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: AppColors.inkSoft)),
                    ),
                  if (cmd.modePaiement != 'ESPECES')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Réf. paiement : ${cmd.referencePaiement}', style: const TextStyle(fontSize: 12.5, color: AppColors.redDim, fontWeight: FontWeight.w600)),
                    ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${cmd.total.toStringAsFixed(0)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (cmd.paiementConfirme)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('✓ Paiement confirmé', style: TextStyle(color: AppColors.greenDim, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(height: 18),
                  if (ap != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: ap.couleur),
                        onPressed: enTraitement ? null : () => lancer(ap.action),
                        icon: Icon(ap.icone, size: 18),
                        label: Text(enTraitement ? '...' : ap.label),
                      ),
                    ),
                  if (ap != null) const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D5BA8)),
                      onPressed: (enTraitement || cmd.paiementConfirme) ? null : () => lancer(_encaisser),
                      child: Text(enTraitement ? '...' : (cmd.paiementConfirme ? '✓ Encaissé' : 'Encaisser')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _ouvrirRecu(cmd);
                      },
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('Reçu de paiement'),
                    ),
                  ),
                  if (_estActive(cmd.statut)) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                        onPressed: enTraitement ? null : () => lancer(_annuler),
                        child: Text(enTraitement ? '...' : 'Annuler la commande'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _carteCommandeMobile(Commande cmd) {
    final enTraitement = _enTraitement[cmd.id] == true;
    final selectionnee = _selectionnee?.id == cmd.id;
    final ap = _actionPrincipale(cmd.statut);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: selectionnee ? AppColors.gold : AppColors.line, width: selectionnee ? 2 : 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('#${cmd.id}  ${cmd.enLivraison ? "🛵" : (cmd.numeroTable ?? "—")}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              _badgeStatut(cmd.statut),
            ],
          ),
          const SizedBox(height: 4),
          Text(DateFormat.Hm('fr_FR').format(cmd.dateCreation), style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
          const SizedBox(height: 6),
          Text('${cmd.total.toStringAsFixed(0)} F', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.redDim)),
          const SizedBox(height: 10),
          Row(
            children: [
              if (ap != null)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: ap.couleur, padding: const EdgeInsets.symmetric(vertical: 10)),
                    onPressed: enTraitement ? null : () => ap.action(cmd.id),
                    icon: Icon(ap.icone, size: 15),
                    label: Text(enTraitement ? '...' : ap.label, style: const TextStyle(fontSize: 12)),
                  ),
                ),
              if (ap != null) const SizedBox(width: 6),
              if (_estActive(cmd.statut))
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.red, padding: const EdgeInsets.symmetric(vertical: 10)),
                    onPressed: enTraitement ? null : () => _annuler(cmd.id),
                    child: Text(enTraitement ? '...' : '✕ Annuler', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              const SizedBox(width: 6),
              if (cmd.paiementConfirme || cmd.statut == 'SERVIE')
                IconButton(
                  onPressed: () => _ouvrirRecu(cmd),
                  icon: const Icon(Icons.receipt_long, color: Color(0xFF8A6D1D)),
                  style: IconButton.styleFrom(backgroundColor: AppColors.cream2),
                  tooltip: 'Reçu',
                ),
              IconButton(
                onPressed: () => _ouvrirDetailModal(cmd),
                icon: const Icon(Icons.remove_red_eye, color: Color(0xFF1D5BA8)),
                style: IconButton.styleFrom(backgroundColor: AppColors.cream2),
                tooltip: 'Détail',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconeAction(IconData icone, Color couleur, String tooltip, VoidCallback? onPressed) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: onPressed == null ? couleur.withOpacity(0.4) : couleur,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icone, color: Colors.white, size: 16),
        ),
      ),
    );
  }

  Widget _buildDetailCommande(Commande cmd) {
    final enTraitement = _enTraitement[cmd.id] == true;
    final ap = _actionPrincipale(cmd.statut);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.line, width: 1.5), borderRadius: BorderRadius.circular(14)),
      child: LayoutBuilder(builder: (context, constraints) {
        final detail = Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Détails commande #${cmd.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              ...cmd.lignes.map((l) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${l.quantite}x ${l.platNom}${l.details}', style: const TextStyle(fontSize: 12.5)),
                        Text('${l.sousTotal.toStringAsFixed(0)} F', style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
                      ],
                    ),
                  )),
              if (cmd.remarque != null && cmd.remarque!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Remarque client : ${cmd.remarque}', style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.inkSoft)),
                ),
              if (cmd.modePaiement != 'ESPECES')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Réf. paiement : ${cmd.referencePaiement}', style: const TextStyle(fontSize: 11.5, color: AppColors.redDim, fontWeight: FontWeight.w600)),
                ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${cmd.total.toStringAsFixed(0)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              if (cmd.paiementConfirme)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('✓ Paiement confirmé', style: TextStyle(color: AppColors.greenDim, fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        );

        final boutons = Expanded(
          flex: 2,
          child: Column(
            children: [
              if (ap != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: ap.couleur),
                    onPressed: enTraitement ? null : () => ap.action(cmd.id),
                    icon: Icon(ap.icone, size: 18),
                    label: Text(enTraitement ? '...' : ap.label),
                  ),
                ),
              if (ap != null) const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D5BA8)),
                  onPressed: (enTraitement || cmd.paiementConfirme) ? null : () => _encaisser(cmd.id),
                  child: Text(enTraitement ? '...' : (cmd.paiementConfirme ? '✓ Encaissé' : 'Encaisser')),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _ouvrirRecu(cmd),
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('Reçu'),
                ),
              ),
              if (_estActive(cmd.statut)) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                    onPressed: enTraitement ? null : () => _annuler(cmd.id),
                    child: Text(enTraitement ? '...' : 'Annuler la commande'),
                  ),
                ),
              ],
            ],
          ),
        );

        if (constraints.maxWidth >= 500) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [detail, const SizedBox(width: 20), boutons]);
        }
        return Column(children: [detail, const SizedBox(height: 16), boutons]);
      }),
    );
  }

  Widget _buildListeSimple({required String titre, required List<Map<String, dynamic>> commandes, required String vide}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (commandes.isEmpty)
          EmptyState(emoji: '📭', titre: vide)
        else
          ...commandes.map((c) => InkWell(
                onTap: () => ouvrirTicketDetail(context, c),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('#${c['id']} · ${c['numero_table'] ?? "—"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              List<Map<String, dynamic>>.from(c['lignes'] ?? []).map((l) => '${l['quantite']}x ${l['plat_nom']}').join(', '),
                              style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (c['mode_paiement'] != 'ESPECES')
                              Text('${c['mode_paiement'] == "WAVE" ? "🌊 Wave" : "🟠 Orange Money"} · réf. ${c['reference_paiement']}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.redDim)),
                            if (c['statut'] == 'ANNULEE' && (c['motif_annulation'] as String?)?.isNotEmpty == true)
                              Text('Motif : ${c['motif_annulation']}', style: const TextStyle(fontSize: 11, color: AppColors.redDim, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      Row(children: [
                        _badgeStatut(c['statut']),
                        const SizedBox(width: 10),
                        Text('${c['total']} F', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ]),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Widget _badgeStatut(String statut) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: (couleurStatut[statut] ?? AppColors.gold).withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
      child: Text(labelsStatut[statut] ?? statut, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: couleurStatut[statut] ?? AppColors.gold)),
    );
  }
}
