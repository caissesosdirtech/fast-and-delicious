import 'package:flutter/foundation.dart';

/// Badge de notifications des écrans staff : il reflète le nombre de commandes
/// réellement **en attente** (EN_ATTENTE).
/// - les écrans caisse/admin appellent [definir] après chaque chargement ;
/// - le badge baisse donc automatiquement quand les commandes sont traitées
///   (plus besoin de taper sur la cloche pour le vider) ;
/// - un son est joué séparément à l'arrivée d'une nouvelle commande.
class NotificationsService {
  NotificationsService._();
  static final NotificationsService instance = NotificationsService._();

  final ValueNotifier<int> compteur = ValueNotifier<int>(0);

  /// Met le badge au nombre exact de commandes en attente.
  void definir(int nb) {
    final valeur = nb < 0 ? 0 : nb;
    if (compteur.value != valeur) compteur.value = valeur;
  }

  void reinitialiser() => compteur.value = 0;
}
