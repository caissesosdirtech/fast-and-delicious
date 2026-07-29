import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';

/// Se connecte à ws/commande/<id>/ ou ws/<caisse|cuisine|livraison>/,
/// équivalent des hooks useCommandeSocket / useDashboardSocket côté web.
class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool connecte = false;

  void connecterCommande(String commandeId, void Function(Map<String, dynamic>) onMessage) {
    _connecter('${ApiConfig.wsBaseUrl}/ws/commande/$commandeId/', onMessage);
  }

  void connecterDashboard(String groupe, void Function(Map<String, dynamic>) onMessage) {
    _connecter('${ApiConfig.wsBaseUrl}/ws/$groupe/', onMessage);
  }

  void _connecter(String url, void Function(Map<String, dynamic>) onMessage) {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      connecte = true;
      _subscription = _channel!.stream.listen(
        (message) {
          connecte = true;
          final data = jsonDecode(message) as Map<String, dynamic>;
          onMessage(data);
        },
        onError: (_) => connecte = false,
        onDone: () => connecte = false,
      );
    } catch (_) {
      connecte = false;
    }
  }

  void fermer() {
    _subscription?.cancel();
    _channel?.sink.close();
    connecte = false;
  }
}
