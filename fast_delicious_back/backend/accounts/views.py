from rest_framework import generics, permissions
from django.contrib.auth import get_user_model

from .serializers import InscriptionClientSerializer, UtilisateurSerializer

Utilisateur = get_user_model()


class InscriptionClientView(generics.CreateAPIView):
    """POST /api/comptes/inscription/  — un client crée son propre compte."""

    queryset = Utilisateur.objects.all()
    serializer_class = InscriptionClientSerializer
    permission_classes = [permissions.AllowAny]


class MonProfilView(generics.RetrieveAPIView):
    """GET /api/comptes/moi/ — profil de l'utilisateur connecté (utile pour connaître son rôle)."""

    serializer_class = UtilisateurSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user
