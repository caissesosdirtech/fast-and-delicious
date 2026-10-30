"""
Intégration des paiements en ligne : Wave & Orange Money.

Objectif : permettre au client de payer par Wave ou Orange Money, et confirmer
AUTOMATIQUEMENT la commande (paiement_confirme = True) grâce à un webhook, sans
que la caissière ait à saisir une référence à la main.

⚠️ IMPORTANT — à lire avant la mise en production :
  - Ce code suit la documentation publique de Wave Checkout et d'Orange Money
    Web Payment, mais il n'a PAS pu être testé contre les vraies API.
  - Tu dois : renseigner les clés (variables d'environnement Railway),
    enregistrer les URL de webhook dans tes tableaux de bord Wave/Orange,
    puis tester en bac à sable avant d'encaisser de vrais clients.
  - Les endpoints/champs exacts d'Orange Money varient selon le compte marchand :
    vérifie-les dans ton espace Orange Developer et ajuste `OrangeMoneyClient`.

Aucune dépendance lourde : on utilise `requests` (ajouté à requirements.txt).
"""

import hashlib
import hmac

import requests
from django.conf import settings


class PaiementNonConfigure(Exception):
    """Levée quand les clés du fournisseur ne sont pas renseignées."""


class ErreurPaiement(Exception):
    """Erreur lors d'un échange avec l'API du fournisseur."""


# ============================================================
# WAVE  (https://docs.wave.com — Checkout API)
# ============================================================
class WaveClient:
    @staticmethod
    def est_configure():
        return bool(settings.WAVE_API_KEY)

    @staticmethod
    def creer_session(commande, montant):
        """Crée une session de paiement Wave et renvoie l'URL/QR à présenter au client."""
        if not WaveClient.est_configure():
            raise PaiementNonConfigure("Clé API Wave manquante (WAVE_API_KEY).")

        url = f"{settings.WAVE_API_BASE}/v1/checkout/sessions"
        corps = {
            "amount": str(int(montant)),
            "currency": "XOF",
            "success_url": f"{settings.PAIEMENT_RETOUR_URL}/paiement/succes",
            "error_url": f"{settings.PAIEMENT_RETOUR_URL}/paiement/echec",
            # Permet de retrouver la commande dans le webhook.
            "client_reference": str(commande.id),
        }
        try:
            r = requests.post(
                url,
                json=corps,
                headers={
                    "Authorization": f"Bearer {settings.WAVE_API_KEY}",
                    "Content-Type": "application/json",
                },
                timeout=20,
            )
            r.raise_for_status()
            data = r.json()
        except requests.RequestException as e:
            raise ErreurPaiement(f"Wave : {e}") from e

        return {
            "provider": "WAVE",
            "session_id": data.get("id", ""),
            "payment_url": data.get("wave_launch_url") or data.get("payment_url", ""),
        }

    @staticmethod
    def verifier_signature(corps_brut: bytes, entete_signature: str) -> bool:
        """Vérifie l'entête `Wave-Signature` (schéma t=timestamp,v1=hmac)."""
        secret = settings.WAVE_WEBHOOK_SECRET
        if not secret:
            # Pas de secret configuré : on ne peut pas vérifier → on refuse par sécurité.
            return False
        try:
            parties = dict(p.split("=", 1) for p in entete_signature.split(","))
            timestamp = parties.get("t", "")
            signature = parties.get("v1", "")
        except Exception:
            return False
        charge = f"{timestamp}.".encode() + corps_brut
        attendu = hmac.new(secret.encode(), charge, hashlib.sha256).hexdigest()
        return hmac.compare_digest(attendu, signature)


# ============================================================
# ORANGE MONEY  (Orange Developer — Web Payment)
# ============================================================
class OrangeMoneyClient:
    @staticmethod
    def est_configure():
        return bool(
            settings.ORANGE_CLIENT_ID
            and settings.ORANGE_CLIENT_SECRET
            and settings.ORANGE_MERCHANT_KEY
        )

    @staticmethod
    def _jeton_acces():
        """Récupère un jeton OAuth2 (client_credentials)."""
        url = f"{settings.ORANGE_API_BASE}/oauth/v3/token"
        try:
            r = requests.post(
                url,
                data={"grant_type": "client_credentials"},
                auth=(settings.ORANGE_CLIENT_ID, settings.ORANGE_CLIENT_SECRET),
                headers={"Accept": "application/json"},
                timeout=20,
            )
            r.raise_for_status()
            return r.json()["access_token"]
        except requests.RequestException as e:
            raise ErreurPaiement(f"Orange (jeton) : {e}") from e

    @staticmethod
    def creer_paiement(commande, montant):
        """Crée une transaction Web Payment Orange et renvoie l'URL de paiement."""
        if not OrangeMoneyClient.est_configure():
            raise PaiementNonConfigure(
                "Identifiants Orange Money manquants (ORANGE_CLIENT_ID / SECRET / MERCHANT_KEY)."
            )

        jeton = OrangeMoneyClient._jeton_acces()
        pays = settings.ORANGE_PAYS
        url = f"{settings.ORANGE_API_BASE}/orange-money-webpay/{pays}/v1/webpayment"
        corps = {
            "merchant_key": settings.ORANGE_MERCHANT_KEY,
            "currency": settings.ORANGE_DEVISE,
            "order_id": str(commande.id),
            "amount": int(montant),
            "return_url": f"{settings.PAIEMENT_RETOUR_URL}/paiement/succes",
            "cancel_url": f"{settings.PAIEMENT_RETOUR_URL}/paiement/echec",
            "notif_url": f"{settings.PAIEMENT_RETOUR_URL.rstrip('/')}",  # voir note ci-dessous
            "lang": "fr",
            "reference": f"Commande #{commande.id}",
        }
        # NOTE : notif_url doit pointer vers TON backend, pas le frontend.
        # Renseigne plutôt l'URL publique du backend via la variable
        # d'environnement BACKEND_URL si tu l'ajoutes ; ici on laisse l'URL
        # de base et tu l'ajustes selon ton déploiement.
        try:
            r = requests.post(
                url,
                json=corps,
                headers={
                    "Authorization": f"Bearer {jeton}",
                    "Content-Type": "application/json",
                },
                timeout=20,
            )
            r.raise_for_status()
            data = r.json()
        except requests.RequestException as e:
            raise ErreurPaiement(f"Orange (paiement) : {e}") from e

        return {
            "provider": "ORANGE_MONEY",
            "session_id": data.get("pay_token", ""),
            "payment_url": data.get("payment_url", ""),
        }

    @staticmethod
    def verifier_statut(order_id, montant, pay_token):
        """Interroge Orange pour confirmer le statut réel d'une transaction.

        Plus sûr que de faire confiance à la notification brute.
        Renvoie True si le paiement est réussi.
        """
        jeton = OrangeMoneyClient._jeton_acces()
        pays = settings.ORANGE_PAYS
        url = f"{settings.ORANGE_API_BASE}/orange-money-webpay/{pays}/v1/transactionstatus"
        try:
            r = requests.post(
                url,
                json={"order_id": str(order_id), "amount": int(montant), "pay_token": pay_token},
                headers={
                    "Authorization": f"Bearer {jeton}",
                    "Content-Type": "application/json",
                },
                timeout=20,
            )
            r.raise_for_status()
            statut = (r.json().get("status") or "").upper()
        except requests.RequestException as e:
            raise ErreurPaiement(f"Orange (statut) : {e}") from e
        return statut in ("SUCCESS", "SUCCESSFUL", "COMPLETED")
