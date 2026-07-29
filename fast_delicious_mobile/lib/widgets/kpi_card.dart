import 'package:flutter/material.dart';
import '../config/theme.dart';

class KpiCard extends StatelessWidget {
  final String label;
  final String valeur;
  final Color? couleurValeur;

  const KpiCard({super.key, required this.label, required this.valeur, this.couleurValeur});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(valeur, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: couleurValeur ?? AppColors.ink)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft), maxLines: 2),
        ],
      ),
    );
  }
}
