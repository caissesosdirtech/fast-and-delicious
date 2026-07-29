import 'package:flutter/material.dart';
import '../config/theme.dart';

class PageHero extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final bool? live;

  const PageHero({super.key, required this.icon, required this.title, required this.subtitle, this.live});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 16),
      color: AppColors.panel,
      child: Column(
        children: [
          Container(
            width: 44, height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(12)),
            child: Text(icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: AppColors.ink), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft), textAlign: TextAlign.center),
          if (live != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: (live! ? AppColors.green : AppColors.inkSoft).withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(color: live! ? AppColors.green : AppColors.inkSoft, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    live! ? 'En direct' : 'Connexion...',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: live! ? AppColors.greenDim : AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
