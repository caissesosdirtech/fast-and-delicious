from rest_framework import generics, permissions, viewsets
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView
from django.contrib.auth import get_user_model

from .permissions import EstAdminCompte
from .serializers import EmployeSerializer, InscriptionClientSerializer, UtilisateurSerializer

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


class ChangerMotDePasseView(APIView):
    """POST /api/comptes/changer-mot-de-passe/ — l'utilisateur connecté change son propre mot de passe."""

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        ancien = request.data.get("ancien_mot_de_passe", "")
        nouveau = request.data.get("nouveau_mot_de_passe", "")

        if not request.user.check_password(ancien):
            raise ValidationError({"ancien_mot_de_passe": "Mot de passe actuel incorrect."})
        if len(nouveau) < 6:
            raise ValidationError({"nouveau_mot_de_passe": "Le nouveau mot de passe doit faire au moins 6 caractères."})

        request.user.set_password(nouveau)
        request.user.save()
        return Response({"detail": "Mot de passe mis à jour avec succès."})


class EmployeViewSet(viewsets.ModelViewSet):
    """CRUD sur les comptes staff (caissière, cuisine, livreur, admin) — réservé à l'admin.
    Les comptes clients ne sont jamais inclus.
    """

    queryset = Utilisateur.objects.exclude(role=Utilisateur.Role.CLIENT).order_by("username")
    serializer_class = EmployeSerializer
    permission_classes = [EstAdminCompte]
