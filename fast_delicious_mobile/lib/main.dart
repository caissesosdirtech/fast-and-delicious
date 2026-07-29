import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'screens/client/client_shell.dart';
import 'screens/client/suivi_screen.dart';
import 'screens/staff/login_screen.dart';
import 'screens/staff/caisse_screen.dart';
import 'screens/staff/cuisine_screen.dart';
import 'screens/staff/livraison_screen.dart';
import 'screens/staff/admin_screen.dart';
import 'widgets/route_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  runApp(const FastDeliciousApp());
}

class FastDeliciousApp extends StatelessWidget {
  const FastDeliciousApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        title: 'Fast & Delicious',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        initialRoute: '/',
        onGenerateRoute: (settings) {
          if (settings.name == '/') {
            return MaterialPageRoute(builder: (_) => const ClientShell());
          }
          if (settings.name == '/staff/login') {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
          if (settings.name!.startsWith('/suivi/')) {
            final id = settings.name!.replaceFirst('/suivi/', '');
            return MaterialPageRoute(
              builder: (_) => Scaffold(appBar: AppBar(title: const Text('Suivi de commande')), body: SuiviScreen(commandeId: id)),
            );
          }
          if (settings.name == '/caisse') {
            return MaterialPageRoute(
              builder: (_) => const RouteGuard(rolesAutorises: ['caissiere', 'admin'], child: CaisseScreen()),
            );
          }
          if (settings.name == '/cuisine') {
            return MaterialPageRoute(
              builder: (_) => const RouteGuard(rolesAutorises: ['cuisine', 'admin'], child: CuisineScreen()),
            );
          }
          if (settings.name == '/livraison') {
            return MaterialPageRoute(
              builder: (_) => const RouteGuard(rolesAutorises: ['livreur', 'admin'], child: LivraisonScreen()),
            );
          }
          if (settings.name == '/admin') {
            return MaterialPageRoute(
              builder: (_) => const RouteGuard(rolesAutorises: ['admin'], child: AdminScreen()),
            );
          }
          return MaterialPageRoute(builder: (_) => const ClientShell());
        },
      ),
    );
  }
}
