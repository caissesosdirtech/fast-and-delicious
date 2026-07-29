import 'package:flutter/services.dart';

/// Joue un signal de notification (son système + vibration légère).
/// Contrairement au web (Web Audio API), on s'appuie ici sur les sons système
/// natifs de Flutter — aucun fichier audio ni package externe nécessaire.
class SonService {
  static Future<void> jouerNotification() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Son indisponible sur cette plateforme : on ignore silencieusement.
    }
  }
}
