import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../config/paiement_config.dart';
import '../../providers/cart_provider.dart';
import '../../models/commande.dart';

class PanierScreen extends StatelessWidget {
  final void Function(Commande) onCommandeConfirmee;
  const PanierScreen({super.key, required this.onCommandeConfirmee});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          color: AppColors.panel,
          child: const Row(
            children: [
              Text('Panier', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: cart.lignes.isEmpty
              ? const Center(child: Text('Ton panier est vide.', style: TextStyle(color: AppColors.inkSoft)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...cart.lignes.map((l) => _LigneTile(ligne: l)),
                    const SizedBox(height: 14),

                    const Text('MODE DE RETRAIT',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.inkSoft, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _ModeRetraitBtn(valeur: 'SUR_PLACE', label: '🏠 Sur place')),
                        const SizedBox(width: 8),
                        Expanded(child: _ModeRetraitBtn(valeur: 'LIVRAISON', label: '🛵 Livraison')),
                      ],
                    ),

                    if (cart.modeCommande == 'SUR_PLACE') ...[
                      const SizedBox(height: 14),
                      const Text('N° TABLE / STAND',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.inkSoft, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: TextEditingController(text: cart.numeroTable)
                          ..selection = TextSelection.collapsed(offset: cart.numeroTable.length),
                        decoration: const InputDecoration(hintText: 'Ex : Stand 2, Table 12...'),
                        onChanged: cart.setNumeroTable,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: cart.numeroTable.trim().isNotEmpty ? AppColors.green.withOpacity(0.12) : AppColors.gold.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          cart.numeroTable.trim().isNotEmpty
                              ? '✅ Ta commande sera livrée à ${cart.numeroTable}'
                              : "⚠️ Indique ta table pour qu'on te livre, sinon tu devras venir la chercher toi-même.",
                          style: TextStyle(fontSize: 11, color: cart.numeroTable.trim().isNotEmpty ? AppColors.greenDim : const Color(0xFF93691F)),
                        ),
                      ),
                    ],

                    if (cart.modeCommande == 'LIVRAISON') ...[
                      const SizedBox(height: 14),
                      const Text('ADRESSE DE LIVRAISON *',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.inkSoft, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      TextField(
                        decoration: const InputDecoration(hintText: 'Ex : Villa 12, Cité Keur Gorgui...'),
                        onChanged: cart.setAdresseLivraison,
                      ),
                      const SizedBox(height: 10),
                      const Text('NUMÉRO DE TÉLÉPHONE *',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.inkSoft, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      TextField(
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(hintText: 'Ex : 77 123 45 67'),
                        onChanged: cart.setTelephoneClient,
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Text('REMARQUE (OPTIONNEL)',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.inkSoft, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    TextField(
                      maxLines: 2,
                      decoration: const InputDecoration(hintText: 'Sans oignon, sauce à part...'),
                      onChanged: cart.setRemarque,
                    ),
                    const SizedBox(height: 16),
                    const _SectionPaiementPanier(),
                    if (cart.erreurCommande != null)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFFBE4E0), borderRadius: BorderRadius.circular(8)),
                        child: Text(cart.erreurCommande!, style: const TextStyle(color: AppColors.redDim, fontSize: 12.5)),
                      ),
                  ],
                ),
        ),
        if (cart.lignes.isNotEmpty)
          Container(
            padding: EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.of(context).padding.bottom + 14),
            decoration: const BoxDecoration(color: AppColors.panel, border: Border(top: BorderSide(color: AppColors.line))),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${cart.totalPrix.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.redDim)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.ink, padding: const EdgeInsets.symmetric(vertical: 15)),
                    onPressed: cart.envoiEnCours
                        ? null
                        : () async {
                            final commande = await cart.passerCommande();
                            if (commande != null) onCommandeConfirmee(commande);
                          },
                    child: Text(cart.envoiEnCours ? 'Envoi...' : 'Valider la commande', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LigneTile extends StatelessWidget {
  final LignePanier ligne;
  const _LigneTile({required this.ligne});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ligne.plat.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                if (ligne.accompagnementNom != null)
                  Text('+ ${ligne.accompagnementNom}', style: const TextStyle(fontSize: 11, color: AppColors.greenDim)),
                if (ligne.selections.isNotEmpty)
                  Text(ligne.selections.map((s) => s.optionNom).join(', '), style: const TextStyle(fontSize: 10.5, color: AppColors.greenDim)),
                Text('${(ligne.plat.prix * ligne.quantite).toStringAsFixed(0)} FCFA',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(color: AppColors.cream2, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => cart.modifierQuantite(ligne.plat, -1, accompagnementId: ligne.accompagnementId, selections: ligne.selections),
                  icon: const Icon(Icons.remove, size: 16), constraints: const BoxConstraints(), padding: const EdgeInsets.all(8),
                ),
                Text('${ligne.quantite}', style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => cart.modifierQuantite(ligne.plat, 1, accompagnementId: ligne.accompagnementId, accompagnementNom: ligne.accompagnementNom, selections: ligne.selections),
                  icon: const Icon(Icons.add, size: 16), constraints: const BoxConstraints(), padding: const EdgeInsets.all(8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeRetraitBtn extends StatelessWidget {
  final String valeur;
  final String label;
  const _ModeRetraitBtn({required this.valeur, required this.label});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final actif = cart.modeCommande == valeur;
    return GestureDetector(
      onTap: () => cart.setModeCommande(valeur),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: actif ? AppColors.ink : AppColors.panel,
          border: Border.all(color: actif ? AppColors.ink : AppColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: actif ? AppColors.cream : AppColors.inkSoft)),
      ),
    );
  }
}

class _SectionPaiementPanier extends StatelessWidget {
  const _SectionPaiementPanier();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MODE DE PAIEMENT',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.inkSoft, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Row(
          children: [
            _btn(context, 'ESPECES', '💵 Espèces'),
            const SizedBox(width: 6),
            _btn(context, 'PI_MIX', '🔷 QR'),
            const SizedBox(width: 6),
            _btn(context, 'WAVE', '🌊 Wave'),
            const SizedBox(width: 6),
            _btn(context, 'ORANGE_MONEY', '🟠 OM'),
          ],
        ),
        if (cart.modePaiement != 'ESPECES') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.cream2, borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                if (cart.modePaiement == 'WAVE' || cart.modePaiement == 'ORANGE_MONEY') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cart.modePaiement == 'WAVE' ? const Color(0xFF1DA1E8) : const Color(0xFFFF7900),
                      ),
                      onPressed: () => launchUrl(
                        Uri.parse(PaiementConfig.lienPaiementParMode[cart.modePaiement]!),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text('Ouvrir directement dans l\'app ${cart.modePaiement == "WAVE" ? "Wave" : "Orange Money"}'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('— ou scanne le QR ci-dessous —', style: TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
                  const SizedBox(height: 8),
                ],
                Image.asset(PaiementConfig.qrParMode[cart.modePaiement]!, height: 160,
                    errorBuilder: (_, __, ___) => const SizedBox(height: 160, child: Center(child: Text('QR non trouvé')))),
                if (cart.modePaiement == 'PI_MIX') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(8)),
                    child: const Text(
                      '📷 Ce QR doit être scanné à la caméra — si tu commandes depuis ce même téléphone, '
                      'demande à quelqu\'un d\'autre de le scanner, ou choisis Wave/Orange Money pour ouvrir l\'app directement.',
                      style: TextStyle(fontSize: 10.5, color: AppColors.inkSoft),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text('${cart.totalPrix.toStringAsFixed(0)} FCFA à envoyer', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.redDim)),
                if (cart.modePaiement == 'ORANGE_MONEY') ...[
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('Code : ${PaiementConfig.codeMarchandOrangeMoney}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.copy, size: 15), onPressed: () => Clipboard.setData(const ClipboardData(text: PaiementConfig.codeMarchandOrangeMoney))),
                  ]),
                ],
                const SizedBox(height: 8),
                TextField(decoration: const InputDecoration(hintText: 'Référence de transaction *'), onChanged: cart.setReferencePaiement),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _btn(BuildContext context, String valeur, String label) {
    final cart = context.watch<CartProvider>();
    final actif = cart.modePaiement == valeur;
    return Expanded(
      child: GestureDetector(
        onTap: () => cart.setModePaiement(valeur),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: actif ? AppColors.ink : AppColors.panel,
            border: Border.all(color: actif ? AppColors.ink : AppColors.line, width: 1.5),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: actif ? AppColors.cream : AppColors.inkSoft)),
        ),
      ),
    );
  }
}
