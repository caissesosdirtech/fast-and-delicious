import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/theme.dart';
import '../../providers/cart_provider.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onCommencerCommande;
  const WelcomeScreen({super.key, required this.onCommencerCommande});

  Future<void> _choisirTable(BuildContext context) async {
    final cart = context.read<CartProvider>();
    final ctrl = TextEditingController(text: cart.numeroTable);

    final valeur = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ta table / stand'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex : Stand 2, Table 12...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Confirmer')),
        ],
      ),
    );

    if (valeur != null) {
      cart.setNumeroTable(valeur.trim());
      if (valeur.trim().isNotEmpty) onCommencerCommande();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final aTable = cart.numeroTable.trim().isNotEmpty;

    return Container(
      color: AppColors.ink,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/logo-fast-delicious.jpg',
                  width: 84, height: 84, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 84, height: 84,
                    decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.lunch_dining, size: 40, color: AppColors.ink),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('FAST & DELICIOUS',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              const Text('Le goût : notre priorité',
                  style: TextStyle(color: AppColors.gold, fontSize: 13, fontStyle: FontStyle.italic)),
              const SizedBox(height: 34),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3327),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    const Text('Bienvenue !',
                        style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Scannez le QR code sur votre table pour commencer à commander',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFC9C1B0), fontSize: 12.5, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: QrImageView(
                        data: 'fastdelicious://commander',
                        version: QrVersions.auto,
                        size: 150,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      aTable ? 'Table sélectionnée : ${cart.numeroTable}' : 'Ou choisis ta table manuellement ci-dessous',
                      style: const TextStyle(color: Color(0xFFC9C1B0), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () => _choisirTable(context),
                  icon: const Icon(Icons.table_bar, size: 18),
                  label: Text(aTable ? cart.numeroTable : 'Choisir ma table', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onCommencerCommande,
                child: const Text('Passer directement au menu →', style: TextStyle(color: Color(0xFFC9C1B0))),
              ),
              const SizedBox(height: 24),
              const Divider(color: Color(0xFF3A3327)),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/staff/login'),
                icon: const Icon(Icons.badge_outlined, size: 16, color: AppColors.gold),
                label: const Text('Espace staff (caisse / cuisine / livreur / admin)',
                    style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
