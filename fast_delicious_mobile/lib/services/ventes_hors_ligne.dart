import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// File d'attente des ventes directes réalisées HORS LIGNE.
///
/// Quand le réseau est coupé au stand, la vente est enregistrée localement
/// (dans shared_preferences, comme les tokens) au lieu d'être perdue. Dès que
/// la connexion revient, les ventes en attente sont renvoyées au serveur.
///
/// Aucune dépendance supplémentaire : on réutilise shared_preferences, déjà
/// présent dans le projet.
class VentesHorsLigne {
  static const _cle = 'ventes_hors_ligne';

  static Future<List<Map<String, dynamic>>> _lire() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cle);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _ecrire(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cle, jsonEncode(list));
  }

  /// Ajoute une vente à la file (appelé quand l'envoi échoue pour cause réseau).
  static Future<void> ajouter(Map<String, dynamic> payload) async {
    final list = await _lire();
    list.add({
      'payload': payload,
      'cree_le': DateTime.now().toIso8601String(),
    });
    await _ecrire(list);
  }

  /// Nombre de ventes en attente de synchronisation.
  static Future<int> nombreEnAttente() async => (await _lire()).length;

  /// Tente d'envoyer toutes les ventes en attente.
  ///
  /// - Succès : la vente est retirée de la file.
  /// - Erreur réseau (toujours hors ligne) : on garde la vente et on arrête
  ///   (inutile d'insister, tout le reste est conservé).
  /// - Erreur serveur (ex. produit supprimé) : la vente est conservée pour
  ///   ne jamais être perdue, et on continue avec les suivantes.
  ///
  /// Renvoie le nombre de ventes réellement synchronisées.
  static Future<int> synchroniser(Dio api) async {
    final list = await _lire();
    if (list.isEmpty) return 0;

    int envoyees = 0;
    bool reseauCoupe = false;
    final restantes = <Map<String, dynamic>>[];

    for (final item in list) {
      if (reseauCoupe) {
        restantes.add(item);
        continue;
      }
      try {
        await api.post('caisse/vente-directe/', data: item['payload']);
        envoyees++;
      } on DioException catch (e) {
        restantes.add(item);
        if (e.response == null) {
          // Pas de réponse = toujours hors ligne : on arrête là.
          reseauCoupe = true;
        }
        // Sinon (réponse d'erreur serveur) : conservée, on continue.
      } catch (_) {
        restantes.add(item);
      }
    }

    await _ecrire(restantes);
    return envoyees;
  }
}
