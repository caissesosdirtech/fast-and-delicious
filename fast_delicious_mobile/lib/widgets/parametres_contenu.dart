import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';

class ParametresContenu extends StatefulWidget {
  const ParametresContenu({super.key});

  @override
  State<ParametresContenu> createState() => _ParametresContenuState();
}

class _ParametresContenuState extends State<ParametresContenu> {
  final _ancienCtrl = TextEditingController();
  final _nouveauCtrl = TextEditingController();
  final _confirmationCtrl = TextEditingController();
  bool _enCours = false;
  String? _erreur;
  String? _succes;

  Future<void> _changerMotDePasse() async {
    setState(() { _erreur = null; _succes = null; });

    if (_nouveauCtrl.text != _confirmationCtrl.text) {
      setState(() => _erreur = 'La confirmation ne correspond pas au nouveau mot de passe.');
      return;
    }
    if (_nouveauCtrl.text.length < 6) {
      setState(() => _erreur = 'Le nouveau mot de passe doit faire au moins 6 caractères.');
      return;
    }

    setState(() => _enCours = true);
    try {
      await ApiClient().dio.post('comptes/changer-mot-de-passe/', data: {
        'ancien_mot_de_passe': _ancienCtrl.text,
        'nouveau_mot_de_passe': _nouveauCtrl.text,
      });
      setState(() => _succes = 'Mot de passe mis à jour avec succès.');
      _ancienCtrl.clear();
      _nouveauCtrl.clear();
      _confirmationCtrl.clear();
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() => _erreur = (data is Map && data['ancien_mot_de_passe'] != null)
          ? data['ancien_mot_de_passe'][0]
          : "Une erreur est survenue.");
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Paramètres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('MON COMPTE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.inkSoft, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Text(auth.utilisateur?.username ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('Rôle : ${auth.utilisateur?.role ?? ''}', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CHANGER MON MOT DE PASSE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.inkSoft, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              TextField(controller: _ancienCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'Mot de passe actuel')),
              const SizedBox(height: 10),
              TextField(controller: _nouveauCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'Nouveau mot de passe')),
              const SizedBox(height: 10),
              TextField(controller: _confirmationCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'Confirmer le nouveau mot de passe')),
              if (_erreur != null) ...[
                const SizedBox(height: 10),
                Text(_erreur!, style: const TextStyle(color: AppColors.redDim, fontSize: 12.5)),
              ],
              if (_succes != null) ...[
                const SizedBox(height: 10),
                Text(_succes!, style: const TextStyle(color: AppColors.greenDim, fontSize: 12.5, fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _enCours ? null : _changerMotDePasse,
                  child: Text(_enCours ? 'Mise à jour...' : 'Mettre à jour'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
