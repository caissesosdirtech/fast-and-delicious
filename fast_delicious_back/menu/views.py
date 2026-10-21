from rest_framework import viewsets, permissions

from .models import Categorie, Lieu, Plat, TableRestaurant
from .serializers import CategorieSerializer, LieuSerializer, PlatSerializer, TableRestaurantSerializer


class EcritureAdmin(permissions.BasePermission):
    """Écriture réservée à l'admin : accepte le rôle métier « admin » OU un compte Django
    staff/superuser (is_staff). Évite que l'ajout/suppression échoue silencieusement quand
    l'admin a role='admin' mais pas is_staff."""

    def has_permission(self, request, view):
        u = request.user
        return bool(u and u.is_authenticated and (getattr(u, "role", "") == "admin" or u.is_staff))


class LieuViewSet(viewsets.ModelViewSet):
    """CRUD sur les lieux/événements. Lecture publique (menu client, pour choisir son site),
    écriture réservée à l'admin."""

    queryset = Lieu.objects.all()
    serializer_class = LieuSerializer

    def get_permissions(self):
        if self.action in ["list", "retrieve"]:
            return [permissions.AllowAny()]
        return [EcritureAdmin()]


class CategorieViewSet(viewsets.ModelViewSet):
    """CRUD sur les catégories. Lecture publique (menu client), écriture réservée à l'admin."""

    queryset = Categorie.objects.prefetch_related("plats")
    serializer_class = CategorieSerializer

    def get_permissions(self):
        if self.action in ["list", "retrieve"]:
            return [permissions.AllowAny()]
        return [EcritureAdmin()]


class PlatViewSet(viewsets.ModelViewSet):
    """CRUD sur les plats. Lecture publique (uniquement les disponibles), écriture réservée à l'admin.
    L'admin voit aussi les plats indisponibles, pour pouvoir les réactiver.
    """

    serializer_class = PlatSerializer

    def get_queryset(self):
        u = self.request.user
        if u.is_authenticated and (u.is_staff or getattr(u, "role", "") == "admin"):
            return Plat.objects.all()
        return Plat.objects.filter(disponible=True)

    def get_permissions(self):
        if self.action in ["list", "retrieve"]:
            return [permissions.AllowAny()]
        return [EcritureAdmin()]


class TableRestaurantViewSet(viewsets.ModelViewSet):
    """CRUD sur les tables/stands référencés. Lecture publique, écriture réservée à l'admin."""

    queryset = TableRestaurant.objects.all()
    serializer_class = TableRestaurantSerializer

    def get_permissions(self):
        if self.action in ["list", "retrieve"]:
            return [permissions.AllowAny()]
        return [EcritureAdmin()]
