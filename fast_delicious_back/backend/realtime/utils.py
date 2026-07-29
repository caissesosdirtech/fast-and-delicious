"""Fonctions utilitaires pour pousser des mises à jour temps réel depuis les vues DRF
(qui sont synchrones), vers les groupes Channels (asynchrones), via async_to_sync.
"""

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer


def _envoyer(groupe: str, type_message: str, data: dict):
    channel_layer = get_channel_layer()
    if channel_layer is None:
        return  # pas de channel layer configuré (ex : tests) -> on ignore silencieusement
    async_to_sync(channel_layer.group_send)(groupe, {"type": type_message, "data": data})


def notifier_client(commande):
    """Notifie le client qui suit sa commande (écran de suivi)."""
    _envoyer(
        f"commande_{commande.id}",
        "commande.update",
        {
            "commande_id": commande.id,
            "statut": commande.statut,
            "temps_restant_estime_min": commande.temps_restant_estime_min,
        },
    )


def notifier_caisse(commande, evenement="nouvelle_commande"):
    _envoyer(
        "caisse",
        "dashboard.update",
        {"evenement": evenement, "commande_id": commande.id, "statut": commande.statut},
    )


def notifier_cuisine(commande, evenement="commande_validee"):
    _envoyer(
        "cuisine",
        "dashboard.update",
        {"evenement": evenement, "commande_id": commande.id, "statut": commande.statut},
    )
