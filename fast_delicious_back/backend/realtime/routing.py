from django.urls import re_path

from . import consumers

websocket_urlpatterns = [
    re_path(r"^ws/commande/(?P<commande_id>\d+)/$", consumers.CommandeConsumer.as_asgi()),
    re_path(r"^ws/(?P<groupe>caisse|cuisine)/$", consumers.RoleDashboardConsumer.as_asgi()),
]
