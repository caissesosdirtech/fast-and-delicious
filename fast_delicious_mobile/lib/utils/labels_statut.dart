import 'package:flutter/material.dart';
import '../config/theme.dart';

const Map<String, String> labelsStatut = {
  'EN_ATTENTE': 'En attente',
  'VALIDEE': 'Validée',
  'EN_PREPARATION': 'En préparation',
  'PRETE': 'Prête',
  'EN_LIVRAISON': 'En livraison',
  'SERVIE': 'Servie',
  'ANNULEE': 'Annulée',
};

const Map<String, Color> couleurStatut = {
  'EN_ATTENTE': AppColors.gold,
  'VALIDEE': AppColors.gold,
  'EN_PREPARATION': AppColors.gold,
  'PRETE': AppColors.green,
  'EN_LIVRAISON': AppColors.green,
  'SERVIE': AppColors.inkSoft,
  'ANNULEE': AppColors.red,
};
