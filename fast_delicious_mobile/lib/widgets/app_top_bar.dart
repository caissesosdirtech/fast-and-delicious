import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import 'cart_drawer.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cart = context.watch<CartProvider>();

    return AppBar(
      titleSpacing: 16,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/logo-fast-delicious.jpg', height: 38, width: 38, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.restaurant, color: AppColors.red)),
          ),
        ],
      ),
      actions: [
        if (auth.utilisateur == null)
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Text('🛍️', style: TextStyle(fontSize: 18)),
                onPressed: () => ouvrirPanier(context),
              ),
              if (cart.totalArticles > 0)
                Positioned(
                  right: 4, top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(9)),
                    child: Text('${cart.totalArticles}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        if (auth.utilisateur != null) ...[
          if (auth.utilisateur!.estAdmin)
            TextButton(onPressed: () => Navigator.pushNamed(context, '/admin'), child: const Text('📊 Admin')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('${auth.utilisateur!.username}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 18),
            onPressed: () async {
              await auth.deconnexion();
              if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
            },
          ),
        ] else
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/staff/login'),
            child: const Text('Espace staff'),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}
