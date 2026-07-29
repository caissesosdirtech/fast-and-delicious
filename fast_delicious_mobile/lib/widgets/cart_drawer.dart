import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../config/paiement_config.dart';
import '../providers/cart_provider.dart';
import '../models/commande.dart';

/// Ouvre le tiroir panier en bas de l'écran. Renvoie la Commande créée si
/// le client a confirmé avec succès, sinon null.
Future<Commande?> ouvrirPanier(BuildContext context) {
  return showModalBottomSheet<Commande?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CartDrawerContent(),
  );
}

class _CartDrawerContent extends StatelessWidget {
  const _CartDrawerContent();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Votre panier', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<CartProvider>(
                  builder: (context, cart, _) {
                    if (cart.lignes.isEmpty) {
                      return const Center(
                        child: Text('Votre panier est vide pour le moment.',
                            style: TextStyle(color: AppColors.inkSoft)),
                      );
                    }
                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      children: [
                        ...cart.lignes.map((ligne) => _LignePanierTile(ligne: ligne)),
                        if (cart.erreurCommande != null) _ErreurBox(message: cart.erreurCommande!),
                        const _SectionPaiement(),
                      ],
                    );
                  },
                ),
              ),
              Consumer<CartProvider>(
                builder: (context, cart, _) {
                  if (cart.lignes.isEmpty) return const SizedBox.shrink();
                  return Container(
                    padding: EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.of(context).padding.bottom + 18),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.line)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              '${cart.totalPrix.toStringAsFixed(0)} FCFA',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.gold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                            onPressed: cart.envoiEnCours
                                ? null
                                : () async {
                                    final commande = await cart.passerCommande();
                                    if (commande != null && context.mounted) {
                                      Navigator.of(context).pop(commande);
                                    }
                                  },
                            child: Text(cart.envoiEnCours ? 'Envoi...' : 'Confirmer la commande →'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LignePanierTile extends StatelessWidget {
  final LignePanier ligne;
  const _LignePanierTile({required this.ligne});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ligne.plat.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                if (ligne.accompagnementNom != null)
                  Text('+ ${ligne.accompagnementNom}',
                      style: const TextStyle(fontSize: 11, color: AppColors.greenDim, fontWeight: FontWeight.w600)),
                if (ligne.selections.isNotEmpty)
                  Text(
                    ligne.selections.map((s) => '${s.groupeNom} : ${s.optionNom}').join(' · '),
                    style: const TextStyle(fontSize: 10.5, color: AppColors.greenDim),
                  ),
                Text('${ligne.plat.prix.toStringAsFixed(0)} F',
                    style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
              ],
            ),
          ),
          _QtyStepper(
            quantite: ligne.quantite,
            onMoins: () => cart.modifierQuantite(
              ligne.plat, -1,
              accompagnementId: ligne.accompagnementId,
              selections: ligne.selections,
            ),
            onPlus: () => cart.modifierQuantite(
              ligne.plat, 1,
              accompagnementId: ligne.accompagnementId,
              accompagnementNom: ligne.accompagnementNom,
              selections: ligne.selections,
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int quantite;
  final VoidCallback onMoins;
  final VoidCallback onPlus;
  const _QtyStepper({required this.quantite, required this.onMoins, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: AppColors.cream2, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(onPressed: onMoins, icon: const Icon(Icons.remove, size: 16), constraints: const BoxConstraints(), padding: const EdgeInsets.all(6)),
          Text('$quantite', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(onPressed: onPlus, icon: const Icon(Icons.add, size: 16), constraints: const BoxConstraints(), padding: const EdgeInsets.all(6)),
        ],
      ),
    );
  }
}

class _ErreurBox extends StatelessWidget {
  final String message;
  const _ErreurBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFFBE4E0), borderRadius: BorderRadius.circular(8)),
      child: Text(message, style: const TextStyle(color: AppColors.redDim, fontSize: 12.5, fontWeight: FontWeight.w600)),
    );
  }
}

class _SectionPaiement extends StatelessWidget {
  const _SectionPaiement();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MODE DE PAIEMENT',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.inkSoft, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              _ModePaiementBtn(label: '💵 Espèces', valeur: 'ESPECES'),
              const SizedBox(width: 6),
              _ModePaiementBtn(label: '🔷 QR', valeur: 'PI_MIX'),
              const SizedBox(width: 6),
              _ModePaiementBtn(label: '🌊 Wave', valeur: 'WAVE'),
              const SizedBox(width: 6),
              _ModePaiementBtn(label: '🟠 OM', valeur: 'ORANGE_MONEY'),
            ],
          ),
          if (cart.modePaiement != 'ESPECES') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.cream2, borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  if (cart.modePaiement == 'PI_MIX')
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
                      decoration: BoxDecoration(color: AppColors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                      child: const Text(
                        '✨ Recommandé : scanne avec n\'importe quelle app (Wave, Orange Money, ta banque...)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.greenDim),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Image.asset(
                    PaiementConfig.qrParMode[cart.modePaiement]!,
                    height: 180,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 180,
                      child: Center(child: Text('QR non trouvé — vérifie assets/', style: TextStyle(color: AppColors.inkSoft))),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Montant à envoyer : ${cart.totalPrix.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.redDim)),
                  if (cart.modePaiement == 'ORANGE_MONEY') ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Code marchand : ${PaiementConfig.codeMarchandOrangeMoney}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: () => Clipboard.setData(
                              const ClipboardData(text: PaiementConfig.codeMarchandOrangeMoney)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(hintText: 'Référence de la transaction *'),
                    onChanged: cart.setReferencePaiement,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'La caissière vérifiera la réception avant de valider ta commande.',
                    style: TextStyle(fontSize: 10.5, color: AppColors.inkSoft),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModePaiementBtn extends StatelessWidget {
  final String label;
  final String valeur;
  const _ModePaiementBtn({required this.label, required this.valeur});

  @override
  Widget build(BuildContext context) {
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
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: actif ? AppColors.cream : AppColors.inkSoft),
          ),
        ),
      ),
    );
  }
}
