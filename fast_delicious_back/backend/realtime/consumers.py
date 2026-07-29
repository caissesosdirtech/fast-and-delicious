import json

from channels.generic.websocket import AsyncJsonWebsocketConsumer


class CommandeConsumer(AsyncJsonWebsocketConsumer):
    """Un client se connecte à ws/commande/<id>/ pour suivre SA commande en direct."""

    async def connect(self):
        self.commande_id = self.scope["url_route"]["kwargs"]["commande_id"]
        self.group_name = f"commande_{self.commande_id}"
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.group_name, self.channel_name)

    # Appelé quand le backend envoie un message de type "commande.update"
    async def commande_update(self, event):
        await self.send_json(event["data"])


class RoleDashboardConsumer(AsyncJsonWebsocketConsumer):
    """Un poste caissière ou cuisine se connecte à ws/caisse/ ou ws/cuisine/
    pour recevoir en direct les nouvelles commandes de sa file.
    """

    async def connect(self):
        self.group_name = self.scope["url_route"]["kwargs"]["groupe"]  # "caisse" ou "cuisine"
        if self.group_name not in ("caisse", "cuisine"):
            await self.close()
            return
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def dashboard_update(self, event):
        await self.send_json(event["data"])
