import 'package:flutter/foundation.dart';

/// Compteur global de nouvelles commandes reçues (non encore consultées),
/// partagé entre les écrans staff (caisse & admin).
/// - les handlers WebSocket appellent [signalerNouvelle] à chaque "nouvelle_commande" ;
/// - la cloche de StaffScaffold affiche sa valeur en badge ;
/// - un appui sur la cloche le remet à zéro.
///
/// Le dédoublonnage par `commande_id` évite de compter deux fois la même
/// commande quand plusieurs écrans écoutent le même canal (ex : l'admin qui
/// ouvre l'écran caisse — les deux sont abonnés au groupe "caisse").
class NotificationsService {
  NotificationsService._();
  static final NotificationsService instance = NotificationsService._();

  final ValueNotifier<int> compteur = ValueNotifier<int>(0);
  final Set<int> _vues = {};

  void signalerNouvelle(int? commandeId) {
    if (commandeId != null) {
      if (_vues.contains(commandeId)) return; // déjà comptée
      _vues.add(commandeId);
    }
    compteur.value = compteur.value + 1;
  }

  void reinitialiser() => compteur.value = 0;
}
