import 'package:flutter/material.dart';

const List<String> motifsCourants = [
  'Référence de paiement invalide',
  'Le client a changé d\'avis',
  'Rupture de stock',
  'Erreur de saisie',
  'Autre raison',
];

/// Ouvre un dialogue demandant de choisir/saisir un motif d'annulation.
/// Renvoie le motif (String, peut être vide) si confirmé, ou null si annulé.
Future<String?> demanderMotifAnnulation(BuildContext context) async {
  String? motifChoisi;
  final ctrl = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModal) {
          return AlertDialog(
            title: const Text('Annuler cette commande'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pourquoi annules-tu cette commande ?', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
                ...motifsCourants.map((m) => RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(m, style: const TextStyle(fontSize: 13)),
                      value: m,
                      groupValue: motifChoisi,
                      onChanged: (v) => setModal(() => motifChoisi = v),
                    )),
                if (motifChoisi == 'Autre raison')
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: TextField(
                      controller: ctrl,
                      decoration: const InputDecoration(hintText: 'Précise la raison...'),
                      autofocus: true,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ne pas annuler')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  final motifFinal = motifChoisi == 'Autre raison' ? ctrl.text.trim() : (motifChoisi ?? '');
                  Navigator.pop(ctx, motifFinal);
                },
                child: const Text('Confirmer l\'annulation'),
              ),
            ],
          );
        },
      );
    },
  );
}
