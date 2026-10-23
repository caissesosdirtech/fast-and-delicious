import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Carte de statistique (KPI) : pastille de couleur + libellé en capitales,
/// grand chiffre en bas, ombre douce. Style commun aux dashboards caisse & admin.
class KpiCard extends StatelessWidget {
  final String label;
  final String valeur;
  final Color? couleurValeur;
  final String? icone;

  const KpiCard({super.key, required this.label, required this.valeur, this.couleurValeur, this.icone});

  @override
  Widget build(BuildContext context) {
    final accent = couleurValeur ?? AppColors.ink;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line.withOpacity(0.6), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(fontSize: 10, color: AppColors.inkSoft, fontWeight: FontWeight.bold, letterSpacing: 0.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icone != null) Text(icone!, style: const TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          Text(valeur, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: accent, height: 1.0)),
        ],
      ),
    );
  }
}
