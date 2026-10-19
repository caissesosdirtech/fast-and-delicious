/**
 * Coordonnées de paiement mobile money affichées au client.
 * Les images QR sont dans /public (qr-pimix-yas.jpeg, qr-wave.jpg, qr-orange-money.jpg).
 */
export const CODE_MARCHAND_ORANGE_MONEY = "603097";

export const QR_PAR_MODE = {
  PI_MIX: "/qr-pimix-yas.jpeg",
  WAVE: "/qr-wave.jpg",
  ORANGE_MONEY: "/qr-orange-money.jpg",
};

/**
 * Liens de paiement direct, décodés depuis les QR (Wave et Orange Money encodent tous les deux
 * une vraie URL cliquable). Utile quand le client passe commande depuis son propre téléphone :
 * il ne peut pas scanner un QR affiché sur l'écran qu'il tient déjà en main, donc on lui propose
 * d'ouvrir directement l'app à la place.
 * ⚠️ Le QR PI Mix/YAS, lui, encode un format technique brut (norme EMV-QR interopérable),
 * pas une URL — il n'existe pas de lien direct équivalent, il doit être scanné à la caméra.
 */
export const LIEN_PAIEMENT_PAR_MODE = {
  WAVE: "https://pay.wave.com/m/M_sn_QutSVZ1hiP9Y/c/sn/?src=p",
  ORANGE_MONEY: "https://qrcode.orange.sn/dmiIlk4DTQ_5lMw6aphL",
};
