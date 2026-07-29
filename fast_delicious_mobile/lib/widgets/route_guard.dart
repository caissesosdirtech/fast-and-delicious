import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';

class RouteGuard extends StatefulWidget {
  final List<String> rolesAutorises;
  final Widget child;

  const RouteGuard({super.key, required this.rolesAutorises, required this.child});

  @override
  State<RouteGuard> createState() => _RouteGuardState();
}

class _RouteGuardState extends State<RouteGuard> {
  bool _redirectionLancee = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.chargement) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (auth.utilisateur == null) {
      if (!_redirectionLancee) {
        _redirectionLancee = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/staff/login');
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!widget.rolesAutorises.contains(auth.utilisateur!.role)) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Text(
              'Accès réservé à un autre rôle (${widget.rolesAutorises.join(", ")}).',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
