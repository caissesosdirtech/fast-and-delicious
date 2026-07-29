from rest_framework import viewsets, permissions

from .models import Categorie, Lieu, Plat, TableRestaurant
from .serializers import CategorieSerializer, LieuSerializer, PlatSerializer, TableRestaurantSerializer


class LieuViewSet(viewsets.ModelViewSet):
    """CRUD sur les lieux/événements. Lecture publique (menu client, pour choisir son site),
    écriture réservée à l'admin."""

    queryset = Lieu.objects.all()
    serializer_class = LieuSerializer

    def get_permissions(self):
        if self.action in ["list", "retrieve"]:
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]


class CategorieViewSet(viewsets.ModelViewSet):
    """CRUD sur les catégories. Lecture publique (menu client), écriture réservée à l'admin."""

    queryset = Categorie.objects.prefetch_related("plats")
    serializer_class = CategorieSerializer

    def get_permissions(self):
        if self.action in ["list", "retrieve"]:
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]


class PlatViewSet(viewsets.ModelViewSet):
    """CRUD sur les plats. Lecture publique (uniquement les disponibles), écriture réservée à l'admin.
    L'admin voit aussi les plats indisponibles, pour pouvoir les réactiver.
    """

    serializer_class = PlatSerializer

    def get_queryset(self):
        if self.request.user.is_authenticated and self.request.user.is_staff:
            return Plat.objects.all()
        return Plat.objects.filter(disponible=True)

    def get_permissions(self):
        if self.action in ["list", "retrieve"]:
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]


class TableRestaurantViewSet(viewsets.ModelViewSet):
    """CRUD sur les tables/stands référencés. Lecture publique, écriture réservée à l'admin."""

    queryset = TableRestaurant.objects.all()
    serializer_class = TableRestaurantSerializer

    def get_permissions(self):
        if self.action in ["list", "retrieve"]:
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]
