from rest_framework import viewsets, permissions

from .models import Categorie, Plat
from .serializers import CategorieSerializer, PlatSerializer


class CategorieViewSet(viewsets.ReadOnlyModelViewSet):
    """GET /api/menu/categories/ — menu public, avec les plats imbriqués."""

    queryset = Categorie.objects.prefetch_related("plats")
    serializer_class = CategorieSerializer
    permission_classes = [permissions.AllowAny]


class PlatViewSet(viewsets.ModelViewSet):
    """CRUD sur les plats. Lecture publique, écriture réservée au staff (admin cuisine)."""

    queryset = Plat.objects.filter(disponible=True)
    serializer_class = PlatSerializer

    def get_permissions(self):
        if self.action in ["list", "retrieve"]:
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]
