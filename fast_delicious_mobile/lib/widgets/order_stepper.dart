import 'package:flutter/material.dart';
import '../config/theme.dart';

class EtapeStepper extends StatelessWidget {
  final String statutActuel;
  final String modeCommande;

  const EtapeStepper({super.key, required this.statutActuel, this.modeCommande = 'SUR_PLACE'});

  static const _etapesSurPlace = [
    {'cle': 'EN_ATTENTE', 'label': 'Reçue'},
    {'cle': 'VALIDEE', 'label': 'Validée'},
    {'cle': 'EN_PREPARATION', 'label': 'En cuisine'},
    {'cle': 'PRETE', 'label': 'Prête'},
  ];

  static const _etapesLivraison = [
    {'cle': 'EN_ATTENTE', 'label': 'Reçue'},
    {'cle': 'VALIDEE', 'label': 'Validée'},
    {'cle': 'EN_PREPARATION', 'label': 'En cuisine'},
    {'cle': 'PRETE', 'label': 'Prête'},
    {'cle': 'EN_LIVRAISON', 'label': 'En livraison'},
  ];

  @override
  Widget build(BuildContext context) {
    final etapes = modeCommande == 'LIVRAISON' ? _etapesLivraison : _etapesSurPlace;
    final indexActuel = etapes.indexWhere((e) => e['cle'] == statutActuel);
    final toutesFaites = statutActuel == 'SERVIE';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: List.generate(etapes.length, (i) {
          final fait = toutesFaites || i < indexActuel;
          final actuel = !toutesFaites && i == indexActuel;
          final couleur = fait ? AppColors.red : (actuel ? AppColors.gold : AppColors.line);

          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (i > 0) Expanded(child: Container(height: 2, color: fait ? AppColors.red : AppColors.line)),
                    Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: couleur,
                        boxShadow: actuel
                            ? [BoxShadow(color: AppColors.gold.withOpacity(0.3), blurRadius: 6, spreadRadius: 3)]
                            : null,
                      ),
                    ),
                    if (i < etapes.length - 1) Expanded(child: Container(height: 2, color: AppColors.line)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  etapes[i]['label']!,
                  style: const TextStyle(fontSize: 9, color: AppColors.inkSoft),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
