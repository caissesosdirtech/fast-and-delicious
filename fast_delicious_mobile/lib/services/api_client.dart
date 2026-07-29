import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// Client HTTP centralisé, équivalent de src/api/client.js côté web :
/// injecte automatiquement le token JWT, et le rafraîchit une fois en cas de 401.
class ApiClient {
  static final ApiClient _instance = ApiClient._interne();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._interne() {
    dio = Dio(BaseOptions(
      baseUrl: '${ApiConfig.apiUrl}/',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (DioException error, handler) async {
        final requete = error.requestOptions;
        final dejaTente = requete.extra['_retry'] == true;

        if (error.response?.statusCode == 401 && !dejaTente) {
          final prefs = await SharedPreferences.getInstance();
          final refresh = prefs.getString('refresh_token');

          if (refresh != null) {
            try {
              final reponse = await Dio().post(
                '${ApiConfig.apiUrl}/auth/token/refresh/',
                data: {'refresh': refresh},
              );
              final nouvelAccess = reponse.data['access'];
              await prefs.setString('access_token', nouvelAccess);

              requete.headers['Authorization'] = 'Bearer $nouvelAccess';
              requete.extra['_retry'] = true;

              final resultat = await dio.fetch(requete);
              return handler.resolve(resultat);
            } catch (_) {
              await prefs.remove('access_token');
              await prefs.remove('refresh_token');
            }
          }
        }
        handler.next(error);
      },
    ));
  }
}
