/// Coordonnées de paiement affichées au client.
/// ⚠️ Les images QR (assets/qr-wave.jpg, assets/qr-orange-money.jpg, assets/qr-pimix-yas.jpeg)
/// doivent être ajoutées dans le dossier assets/ et déclarées dans pubspec.yaml.
class PaiementConfig {
  static const String codeMarchandOrangeMoney = "603097";
  static const String nomBeneficiaire = "JOJ Dakar 2026";

  static const Map<String, String> qrParMode = {
    "PI_MIX": "assets/qr-pimix-yas.jpeg",
    "WAVE": "assets/qr-wave.jpg",
    "ORANGE_MONEY": "assets/qr-orange-money.jpg",
  };

  /// Liens de paiement direct décodés depuis les QR (Wave et Orange Money encodent une vraie
  /// URL cliquable). Essentiel sur mobile : le client ne peut pas scanner un QR affiché sur
  /// l'écran du téléphone qu'il tient déjà en main pour passer sa commande.
  /// ⚠️ Le QR PI Mix/YAS encode un format technique brut (EMV-QR), pas une URL — pas de lien
  /// direct possible pour celui-là, il doit être scanné à la caméra (par un autre appareil).
  static const Map<String, String> lienPaiementParMode = {
    "WAVE": "https://pay.wave.com/m/M_sn_QutSVZ1hiP9Y/c/sn/?src=p",
    "ORANGE_MONEY": "https://qrcode.orange.sn/dmiIlk4DTQ_5lMw6aphL",
  };
}
