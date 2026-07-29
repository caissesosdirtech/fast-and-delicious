import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/utilisateur.dart';
import '../services/api_client.dart';

class AuthProvider extends ChangeNotifier {
  Utilisateur? utilisateur;
  bool chargement = true;

  final _api = ApiClient().dio;

  AuthProvider() {
    _chargerSession();
  }

  Future<void> _chargerSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      chargement = false;
      notifyListeners();
      return;
    }
    try {
      final reponse = await _api.get('comptes/moi/');
      utilisateur = Utilisateur.fromJson(reponse.data);
    } catch (_) {
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
    }
    chargement = false;
    notifyListeners();
  }

  Future<Utilisateur> connexion(String username, String password) async {
    final reponse = await _api.post('auth/token/', data: {
      'username': username,
      'password': password,
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', reponse.data['access']);
    await prefs.setString('refresh_token', reponse.data['refresh']);

    final profil = await _api.get('comptes/moi/');
    utilisateur = Utilisateur.fromJson(profil.data);
    notifyListeners();
    return utilisateur!;
  }

  Future<void> deconnexion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    utilisateur = null;
    notifyListeners();
  }
}
