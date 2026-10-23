import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _motDePasseVisible = false;
  bool _enCours = false;
  String? _erreur;

  Future<void> _seConnecter() async {
    setState(() { _enCours = true; _erreur = null; });
    try {
      final auth = context.read<AuthProvider>();
      final profil = await auth.connexion(_usernameCtrl.text.trim(), _passwordCtrl.text);
      if (!mounted) return;

      // On remplace toute la pile de navigation : l'écran staff devient la racine,
      // pour que « retour » ne renvoie pas sur la page client (ce qui donnait
      // l'impression d'une déconnexion). La déconnexion reste explicite (bouton).
      if (profil.estAdmin) {
        Navigator.pushNamedAndRemoveUntil(context, '/admin', (r) => false);
      } else if (profil.estCaissiere) {
        Navigator.pushNamedAndRemoveUntil(context, '/caisse', (r) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
      }
    } on DioException {
      setState(() => _erreur = 'Identifiant ou mot de passe incorrect.');
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 64, height: 64,
                        margin: const EdgeInsets.only(bottom: 18),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.restaurant, color: AppColors.gold, size: 28),
                      ),
                      const Text('Espace staff',
                          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: AppColors.ink)),
                      const SizedBox(height: 6),
                      const Text(
                        "Espace réservé à l'équipe (caisse & admin).",
                        style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                      ),
                      const SizedBox(height: 22),
                      const Text('IDENTIFIANT',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.inkSoft, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      TextField(controller: _usernameCtrl, textInputAction: TextInputAction.next),
                      const SizedBox(height: 14),
                      const Text('MOT DE PASSE',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.inkSoft, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: !_motDePasseVisible,
                        onSubmitted: (_) => _seConnecter(),
                        decoration: InputDecoration(
                          suffixIcon: IconButton(
                            icon: Icon(_motDePasseVisible ? Icons.visibility_off : Icons.visibility, size: 20),
                            onPressed: () => setState(() => _motDePasseVisible = !_motDePasseVisible),
                          ),
                        ),
                      ),
                      if (_erreur != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFFBE4E0), borderRadius: BorderRadius.circular(8)),
                          child: Row(children: [
                            const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.redDim),
                            const SizedBox(width: 6),
                            Expanded(child: Text(_erreur!, style: const TextStyle(color: AppColors.redDim, fontSize: 12.5))),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                        onPressed: _enCours ? null : _seConnecter,
                        child: Text(_enCours ? 'Connexion...' : 'Se connecter'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
