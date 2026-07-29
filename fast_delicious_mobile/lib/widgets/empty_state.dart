import 'package:flutter/material.dart';
import '../config/theme.dart';

class EmptyState extends StatelessWidget {
  final String emoji;
  final String titre;
  final String? sousTitre;

  const EmptyState({super.key, required this.emoji, required this.titre, this.sousTitre});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 52, height: 52,
            decoration: const BoxDecoration(color: AppColors.cream2, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(height: 10),
          Text(titre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.ink)),
          if (sousTitre != null) ...[
            const SizedBox(height: 4),
            Text(
              sousTitre!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
            ),
          ],
        ],
      ),
    );
  }
}
