import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import 'welcome_screen.dart';
import 'menu_screen.dart';
import 'panier_screen.dart';
import 'suivi_screen.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _ongletActif = 0;

  void _allerA(int index) => setState(() => _ongletActif = index);

  void _ouvrirEspaceStaff(BuildContext context, AuthProvider auth) {
    // Toujours repasser par l'écran de connexion, même si une session reste active sur
    // l'appareil (ex : le téléphone est resté connecté en admin et un client s'en sert
    // pour commander) — on ne veut jamais donner accès à l'espace staff sans re-vérifier
    // l'identité de la personne qui tape sur ce bouton.
    Navigator.pushNamed(context, '/staff/login');
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<AuthProvider>();

    final pages = [
      WelcomeScreen(onCommencerCommande: () => _allerA(1)),
      const MenuScreen(),
      PanierScreen(onCommandeConfirmee: (commande) => _allerA(3)),
      cart.commandeActiveId != null
          ? SuiviScreen(key: ValueKey(cart.commandeActiveId), commandeId: cart.commandeActiveId.toString())
          : _AucuneCommande(onVoirMenu: () => _allerA(1)),
    ];

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: _ongletActif == 0
          ? null
          : AppBar(
              title: const Text('Menu', style: TextStyle(fontWeight: FontWeight.bold)),
              actions: [const SizedBox(width: 8)],
            ),
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          image: DecorationImage(
            image: AssetImage('assets/fond-app.png'),
            fit: BoxFit.cover,
            opacity: 0.10,
          ),
        ),
        child: SafeArea(top: _ongletActif == 0, bottom: false, child: IndexedStack(index: _ongletActif, children: pages)),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _ongletActif,
        onDestinationSelected: (index) {
          if (index == 4) {
            _ouvrirEspaceStaff(context, auth);
          } else {
            _allerA(index);
          }
        },
        backgroundColor: AppColors.panel,
        indicatorColor: AppColors.gold.withOpacity(0.25),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
          const NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: 'Menu'),
          NavigationDestination(
            icon: Badge(
              label: Text('${cart.totalArticles}'),
              isLabelVisible: cart.totalArticles > 0,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            selectedIcon: const Icon(Icons.shopping_bag),
            label: 'Panier',
          ),
          const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Commande'),
          const NavigationDestination(icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge), label: 'Espace staff'),
        ],
      ),
    );
  }
}

class _AucuneCommande extends StatelessWidget {
  final VoidCallback onVoirMenu;
  const _AucuneCommande({required this.onVoirMenu});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📭', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text('Aucune commande en cours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
            const Text('Passe une commande depuis le menu pour voir son suivi ici.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onVoirMenu, child: const Text('Voir le menu')),
          ],
        ),
      ),
    );
  }
}
