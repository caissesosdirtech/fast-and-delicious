import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../services/api_client.dart';

/// Demande un paiement en ligne (Wave / Orange Money) pour une commande,
/// affiche le QR code à présenter au client, et détecte automatiquement
/// quand la commande est payée (confirmée par le webhook du fournisseur).
///
/// Renvoie `true` via Navigator.pop si le paiement a été confirmé.
class PaiementEnLigneScreen extends StatefulWidget {
  final int commandeId;
  final double total;

  const PaiementEnLigneScreen({
    super.key,
    required this.commandeId,
    required this.total,
  });

  @override
  State<PaiementEnLigneScreen> createState() => _PaiementEnLigneScreenState();
}

enum _Etape { choix, chargement, qr, paye, erreur }

class _PaiementEnLigneScreenState extends State<PaiementEnLigneScreen> {
  final _api = ApiClient().dio;

  _Etape _etape = _Etape.choix;
  String _provider = '';
  String _paymentUrl = '';
  String _erreur = '';
  Timer? _sondage;

  @override
  void dispose() {
    _sondage?.cancel();
    super.dispose();
  }

  Future<void> _demander(String provider) async {
    setState(() {
      _provider = provider;
      _etape = _Etape.chargement;
      _erreur = '';
    });
    try {
      final r = await _api.post(
        'caisse/commandes/${widget.commandeId}/paiement/',
        data: {'provider': provider},
      );
      final url = (r.data is Map ? r.data['payment_url'] : null) as String?;
      if (url == null || url.isEmpty) {
        throw Exception("Le fournisseur n'a pas renvoyé de lien de paiement.");
      }
      setState(() {
        _paymentUrl = url;
        _etape = _Etape.qr;
      });
      _lancerSondage();
    } on DioException catch (e) {
      final detail = (e.response?.data is Map ? e.response?.data['detail'] : null)
          ?.toString();
      setState(() {
        _erreur = detail ?? "Impossible de créer la demande de paiement.";
        _etape = _Etape.erreur;
      });
    } catch (e) {
      setState(() {
        _erreur = e.toString();
        _etape = _Etape.erreur;
      });
    }
  }

  void _lancerSondage() {
    _sondage?.cancel();
    _sondage = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final r = await _api.get('commandes/${widget.commandeId}/');
        if (r.data is Map && r.data['paiement_confirme'] == true) {
          _sondage?.cancel();
          if (mounted) setState(() => _etape = _Etape.paye);
        }
      } catch (_) {
        // on réessaiera au prochain tour
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Paiement en ligne'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, _etape == _Etape.paye),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Commande #${widget.commandeId} · ${widget.total.toStringAsFixed(0)} F',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(child: Center(child: _contenu())),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contenu() {
    switch (_etape) {
      case _Etape.choix:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choisissez le moyen de paiement du client :',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkSoft, fontSize: 15)),
            const SizedBox(height: 20),
            _boutonProvider('WAVE', '🌊  Wave', const Color(0xFF1DA1E8)),
            const SizedBox(height: 12),
            _boutonProvider('ORANGE_MONEY', '🟠  Orange Money', const Color(0xFFFF7900)),
          ],
        );

      case _Etape.chargement:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Création de la demande de paiement…'),
          ],
        );

      case _Etape.qr:
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Le client scanne ce QR code avec ${_provider == "WAVE" ? "Wave" : "Orange Money"} :',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 15),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16)],
                ),
                child: QrImageView(
                  data: _paymentUrl,
                  version: QrVersions.auto,
                  size: 240,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(_paymentUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Ouvrir le lien de paiement'),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                        width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('En attente du paiement du client…',
                        style: TextStyle(color: Color(0xFFB26A00), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        );

      case _Etape.paye:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.green, size: 64),
            const SizedBox(height: 12),
            const Text('Paiement reçu !',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('La commande est maintenant marquée comme payée.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkSoft)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.greenDim,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Terminer'),
            ),
          ],
        );

      case _Etape.erreur:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 54),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(_erreur, textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.red)),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.greenDim,
                foregroundColor: Colors.white,
              ),
              onPressed: () => setState(() => _etape = _Etape.choix),
              child: const Text('Réessayer'),
            ),
          ],
        );
    }
  }

  Widget _boutonProvider(String value, String label, Color couleur) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: couleur, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () => _demander(value),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.ink)),
            const Icon(Icons.arrow_forward, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}
