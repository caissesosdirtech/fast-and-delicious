/// Adresse du backend Django.
/// En développement (émulateur Android), 10.0.2.2 pointe vers le localhost de ta machine.
/// Sur un téléphone physique, remplace par l'adresse IP locale de ton PC (ex: http://192.168.1.10:8000)
/// ou par l'URL de production une fois déployé (voir GUIDE_DEPLOIEMENT.md).
class ApiConfig {
  // Adresse du backend en PRODUCTION. ⚠️ Remplace par l'URL EXACTE de ton backend
  // (Railway ou Render), sans slash final. Exemple Railway :
  //   https://fast-and-delicious-production.up.railway.app
  // Pour tester en local sur l'émulateur Android, remets : http://10.0.2.2:8000
  static const String baseUrl = "https://fast-and-delicious-production.up.railway.app";

  static String get wsBaseUrl => baseUrl.replaceFirst("http", "ws");
  static String get apiUrl => "$baseUrl/api";
}
