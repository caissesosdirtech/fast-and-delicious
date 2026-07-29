/// Adresse du backend Django.
/// En développement (émulateur Android), 10.0.2.2 pointe vers le localhost de ta machine.
/// Sur un téléphone physique, remplace par l'adresse IP locale de ton PC (ex: http://192.168.1.10:8000)
/// ou par l'URL de production une fois déployé (voir GUIDE_DEPLOIEMENT.md).
class ApiConfig {
  static const String baseUrl = "http://10.0.2.2:8000";

  static String get wsBaseUrl => baseUrl.replaceFirst("http", "ws");
  static String get apiUrl => "$baseUrl/api";
}
