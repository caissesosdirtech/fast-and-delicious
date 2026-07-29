import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../utils/labels_statut.dart';

/// Construit une version texte simple du ticket, prête à être partagée
/// (WhatsApp, SMS, e-mail...) — plus léger qu'un vrai PDF, et sans dépendance
/// Android capricieuse.
String _texteTicket(Map<String, dynamic> commande) {
  final lignes = List<Map<String, dynamic>>.from(commande['lignes'] ?? []);
  final date = DateTime.tryParse(commande['date_creation'] ?? '') ?? DateTime.now();
  final modePaiement = commande['mode_paiement'] as String? ?? 'ESPECES';

  final buffer = StringBuffer();
  buffer.writeln('🍔 FAST & DELICIOUS');
  buffer.writeln('Ticket #${commande['id']}');
  buffer.writeln(
    commande['mode_commande'] == 'LIVRAISON' ? '🛵 Livraison' : (commande['numero_table']?.toString() ?? 'Retrait sur place'),
  );
  buffer.writeln(DateFormat('dd/MM/yyyy HH:mm').format(date));
  if (commande['mode_commande'] == 'LIVRAISON') {
    buffer.writeln('📍 ${commande['adresse_livraison']}');
    buffer.writeln('📞 ${commande['telephone_client']}');
  }
  buffer.writeln('------------------------------');
  for (final l in lignes) {
    buffer.writeln('${l['quantite']}x ${l['plat_nom']} — ${l['sous_total']} F');
  }
  buffer.writeln('------------------------------');
  if ((commande['remarque'] as String?)?.isNotEmpty == true) {
    buffer.writeln('Remarque : ${commande['remarque']}');
  }
  if (modePaiement != 'ESPECES') {
    buffer.writeln('Paiement : $modePaiement — réf. ${commande['reference_paiement']}');
  }
  buffer.writeln('TOTAL : ${commande['total']} FCFA');
  buffer.writeln();
  buffer.writeln('Merci et bon appétit !');
  return buffer.toString();
}

Future<void> _partagerTicket(Map<String, dynamic> commande) async {
  await Share.share(_texteTicket(commande), subject: 'Ticket #${commande['id']} — Fast & Delicious');
}

/// Affiche le détail complet d'une commande (lecture seule), accessible à l'admin
/// et à la caissière depuis n'importe quelle liste (historique, paiements, commandes récentes...).
/// Le bouton de partage n'apparaît que pour la caissière, une fois la commande servie —
/// il partage un résumé texte du ticket (WhatsApp, SMS, e-mail...). Pas d'impression physique
/// directe depuis le mobile (contrairement au web), mais ça permet de garder/transmettre une trace.
void ouvrirTicketDetail(BuildContext context, Map<String, dynamic> commande) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        final lignes = List<Map<String, dynamic>>.from(commande['lignes'] ?? []);
        final modePaiement = commande['mode_paiement'] as String? ?? 'ESPECES';
        final statut = commande['statut'] as String? ?? '';
        final date = DateTime.tryParse(commande['date_creation'] ?? '') ?? DateTime.now();
        final auth = ctx.watch<AuthProvider>();
        final peutPartager = auth.utilisateur?.role == 'caissiere' && statut == 'SERVIE';

        return Container(
          decoration: const BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Ticket #${commande['id']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              Text(
                (commande['mode_commande'] == 'LIVRAISON' ? '🛵 Livraison' : (commande['numero_table']?.toString().isNotEmpty == true ? 'Table ${commande['numero_table']}' : 'Retrait sur place'))
                    + ' — ' + DateFormat('dd/MM HH:mm', 'fr_FR').format(date),
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
              if (commande['mode_commande'] == 'LIVRAISON')
                Text('📍 ${commande['adresse_livraison']} · 📞 ${commande['telephone_client']}', style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              const Divider(height: 24),
              ...lignes.map((l) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('${l['quantite']}x ${l['plat_nom']}', style: const TextStyle(fontSize: 13))),
                        Text('${l['sous_total']} F', style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                      ],
                    ),
                  )),
              if ((commande['remarque'] as String?)?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Remarque client : ${commande['remarque']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.inkSoft)),
                ),
              if (modePaiement != 'ESPECES')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${modePaiement == "WAVE" ? "🌊 Wave" : modePaiement == "ORANGE_MONEY" ? "🟠 Orange Money" : "🔷 QR"} · réf. ${commande['reference_paiement']}',
                    style: const TextStyle(fontSize: 12, color: AppColors.redDim, fontWeight: FontWeight.w600),
                  ),
                ),
              if (statut == 'ANNULEE' && (commande['motif_annulation'] as String?)?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Motif d\'annulation : ${commande['motif_annulation']}', style: const TextStyle(fontSize: 12, color: AppColors.redDim, fontStyle: FontStyle.italic)),
                ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${commande['total']} FCFA', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: (couleurStatut[statut] ?? AppColors.gold).withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  labelsStatut[statut] ?? statut,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, color: couleurStatut[statut] ?? AppColors.gold),
                ),
              ),
              if (peutPartager) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _partagerTicket(commande),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Partager le ticket'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}
