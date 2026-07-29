import 'dart:async';
import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/api_client.dart';
import '../../services/websocket_service.dart';
import '../../services/son_service.dart';
import '../../models/commande.dart';

const _statutsSonores = ['PRETE', 'EN_LIVRAISON', 'SERVIE'];

/// Une étape de la timeline verticale de suivi.
class _Etape {
  final String cle;
  final String label;
  const _Etape(this.cle, this.label);
}

const _etapesSurPlace = [
  _Etape('EN_ATTENTE', 'Commande reçue'),
  _Etape('VALIDEE', 'Validée par la caisse'),
  _Etape('EN_PREPARATION', 'En préparation'),
  _Etape('PRETE', 'Prête'),
  _Etape('SERVIE', 'Servie'),
];

const _etapesLivraison = [
  _Etape('EN_ATTENTE', 'Commande reçue'),
  _Etape('VALIDEE', 'Validée par la caisse'),
  _Etape('EN_PREPARATION', 'En préparation'),
  _Etape('PRETE', 'Prête'),
  _Etape('EN_LIVRAISON', 'En livraison'),
  _Etape('SERVIE', 'Livrée'),
];

class SuiviScreen extends StatefulWidget {
  final String commandeId;
  const SuiviScreen({super.key, required this.commandeId});

  @override
  State<SuiviScreen> createState() => _SuiviScreenState();
}

class _SuiviScreenState extends State<SuiviScreen> {
  Commande? _commande;
  String? _erreur;
  bool _annulationEnCours = false;
  final _ws = WebSocketService();
  Timer? _timerSecours;

  @override
  void initState() {
    super.initState();
    _charger();
    // Filet de sécurité : même si le WebSocket ne se connecte pas (réseau, configuration
    // Android bloquant le trafic non chiffré, etc.), on se resynchronise seul toutes les 10s.
    _timerSecours = Timer.periodic(const Duration(seconds: 10), (_) => _charger(silencieux: true));
    _ws.connecterCommande(widget.commandeId, (data) {
      if (!mounted) return;
      if (data['statut'] != null && _statutsSonores.contains(data['statut'])) {
        SonService.jouerNotification();
      }
      _charger(silencieux: true);
    });
  }

  @override
  void dispose() {
    _ws.fermer();
    _timerSecours?.cancel();
    super.dispose();
  }

  Future<void> _charger({bool silencieux = false}) async {
    try {
      final reponse = await ApiClient().dio.get('commandes/${widget.commandeId}/');
      if (!mounted) return;
      setState(() => _commande = Commande.fromJson(reponse.data));
    } catch (_) {
      if (!silencieux && mounted) setState(() => _erreur = 'Commande introuvable.');
    }
  }

  Future<void> _annuler() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la commande ?'),
        content: const Text('Es-tu sûr de vouloir annuler cette commande ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui, annuler')),
        ],
      ),
    );
    if (confirme != true) return;

    setState(() => _annulationEnCours = true);
    try {
      final reponse = await ApiClient().dio.patch('commandes/${widget.commandeId}/annuler/');
      setState(() => _commande = Commande.fromJson(reponse.data));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'annuler : la commande a peut-être déjà été prise en charge.")),
        );
      }
    } finally {
      if (mounted) setState(() => _annulationEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_erreur != null) {
      return Center(child: Text(_erreur!));
    }
    if (_commande == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final c = _commande!;
    final etapes = c.enLivraison ? _etapesLivraison : _etapesSurPlace;
    final annulee = c.statut == 'ANNULEE';
    final indexActuel = annulee ? -1 : etapes.indexWhere((e) => e.cle == c.statut);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          color: AppColors.panel,
          child: const Text('Suivi de commande', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text('Commande N°${c.id}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (c.enLivraison)
                Text('📍 ${c.adresseLivraison}', style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft))
              else if (c.numeroTable?.isNotEmpty == true)
                Text(c.numeroTable!, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
              if (c.remarque != null && c.remarque!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('📝 ${c.remarque}', style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft, fontStyle: FontStyle.italic)),
                ),
              const SizedBox(height: 20),

              if (annulee)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Row(children: [
                    Icon(Icons.cancel, color: AppColors.redDim),
                    SizedBox(width: 10),
                    Text('Commande annulée', style: TextStyle(color: AppColors.redDim, fontWeight: FontWeight.bold)),
                  ]),
                )
              else
                Column(
                  children: List.generate(etapes.length, (i) {
                    final fait = i < indexActuel || (i == indexActuel && c.statut == 'SERVIE');
                    final actuel = i == indexActuel && c.statut != 'SERVIE';
                    return _LigneEtape(
                      label: etapes[i].label,
                      fait: fait,
                      actuel: actuel,
                      dernier: i == etapes.length - 1,
                    );
                  }),
                ),

              if (!annulee && ['VALIDEE', 'EN_PREPARATION'].contains(c.statut)) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      const Text('TEMPS ESTIMÉ', style: TextStyle(color: Color(0xFFC9C1B0), fontSize: 10.5, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      Text('${c.tempsRestantEstimeMin.toString().padLeft(2, "0")}:00',
                          style: const TextStyle(color: AppColors.gold, fontSize: 30, fontWeight: FontWeight.bold)),
                      const Text('min restantes', style: TextStyle(color: Color(0xFFC9C1B0), fontSize: 11)),
                    ],
                  ),
                ),
              ],

              if (!annulee && c.statut == 'EN_ATTENTE') ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _annulationEnCours ? null : _annuler,
                    child: Text(_annulationEnCours ? 'Annulation...' : 'Annuler la commande'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LigneEtape extends StatelessWidget {
  final String label;
  final bool fait;
  final bool actuel;
  final bool dernier;

  const _LigneEtape({required this.label, required this.fait, required this.actuel, required this.dernier});

  @override
  Widget build(BuildContext context) {
    final couleur = fait ? AppColors.green : (actuel ? AppColors.gold : AppColors.line);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fait ? AppColors.green : (actuel ? AppColors.gold : Colors.transparent),
                  border: Border.all(color: couleur, width: 2),
                ),
                alignment: Alignment.center,
                child: fait
                    ? const Icon(Icons.check, size: 15, color: Colors.white)
                    : (actuel ? const Icon(Icons.circle, size: 8, color: Colors.white) : null),
              ),
              if (!dernier) Expanded(child: Container(width: 2, color: fait ? AppColors.green : AppColors.line)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22, top: 3),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: (fait || actuel) ? FontWeight.bold : FontWeight.normal,
                  color: (fait || actuel) ? AppColors.ink : AppColors.inkSoft,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
