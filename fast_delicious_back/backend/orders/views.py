from django.utils import timezone
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from realtime.utils import notifier_caisse, notifier_client, notifier_cuisine

from .models import Commande, LigneCommande
from .permissions import EstAdmin, EstCaissiere, EstCuisinier
from .serializers import CommandeCreationSerializer, CommandeSerializer


class CommandeCreationView(generics.CreateAPIView):
    """POST /api/commandes/ — le client crée sa commande depuis le menu."""

    serializer_class = CommandeCreationSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        commande = serializer.save()

        notifier_caisse(commande, evenement="nouvelle_commande")

        out = CommandeSerializer(commande)
        return Response(out.data, status=status.HTTP_201_CREATED)


class CommandeDetailView(generics.RetrieveAPIView):
    """GET /api/commandes/<id>/ — utilisé par l'écran de suivi client (statut + temps restant)."""

    queryset = Commande.objects.prefetch_related("lignes__plat")
    serializer_class = CommandeSerializer
    permission_classes = [permissions.AllowAny]


class FileAttenteCaisseView(generics.ListAPIView):
    """GET /api/caisse/commandes/ — commandes en attente de validation par la caissière."""

    serializer_class = CommandeSerializer
    permission_classes = [EstCaissiere]

    def get_queryset(self):
        return Commande.objects.filter(
            statut=Commande.Statut.EN_ATTENTE
        ).prefetch_related("lignes__plat")


class ValiderCommandeView(APIView):
    """PATCH /api/caisse/commandes/<id>/valider/ — la caissière encaisse et envoie en cuisine."""

    permission_classes = [EstCaissiere]

    def patch(self, request, pk):
        commande = get_object_or_404(Commande, pk=pk)
        if commande.statut != Commande.Statut.EN_ATTENTE:
            raise PermissionDenied("Cette commande n'est plus en attente de validation.")

        commande.statut = Commande.Statut.VALIDEE
        commande.date_validation = timezone.now()
        commande.caissiere = request.user
        commande.save()
        commande.enregistrer_historique()

        notifier_client(commande)
        notifier_cuisine(commande, evenement="commande_validee")

        return Response(CommandeSerializer(commande).data)


class FileAttenteCuisineView(generics.ListAPIView):
    """GET /api/cuisine/commandes/ — commandes validées, à préparer ou en cours de préparation."""

    serializer_class = CommandeSerializer
    permission_classes = [EstCuisinier]

    def get_queryset(self):
        return Commande.objects.filter(
            statut__in=[Commande.Statut.VALIDEE, Commande.Statut.EN_PREPARATION]
        ).prefetch_related("lignes__plat")


class DemarrerPreparationView(APIView):
    """PATCH /api/cuisine/commandes/<id>/preparer/ — le cuisinier prend la commande en charge."""

    permission_classes = [EstCuisinier]

    def patch(self, request, pk):
        commande = get_object_or_404(Commande, pk=pk)
        if commande.statut != Commande.Statut.VALIDEE:
            raise PermissionDenied("Cette commande n'est pas en attente de préparation.")

        commande.statut = Commande.Statut.EN_PREPARATION
        commande.date_debut_preparation = timezone.now()
        commande.cuisinier = request.user
        commande.save()
        commande.enregistrer_historique()

        notifier_client(commande)

        return Response(CommandeSerializer(commande).data)


class MarquerPreteView(APIView):
    """PATCH /api/cuisine/commandes/<id>/prete/ — le plat est prêt à être servi."""

    permission_classes = [EstCuisinier]

    def patch(self, request, pk):
        commande = get_object_or_404(Commande, pk=pk)
        if commande.statut != Commande.Statut.EN_PREPARATION:
            raise PermissionDenied("Cette commande n'est pas en cours de préparation.")

        commande.statut = Commande.Statut.PRETE
        commande.date_prete = timezone.now()
        commande.save()
        commande.enregistrer_historique()

        notifier_client(commande)

        return Response(CommandeSerializer(commande).data)


class MarquerServieView(APIView):
    """PATCH /api/commandes/<id>/servie/ — clôture la commande (caissière ou cuisine)."""

    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, pk):
        commande = get_object_or_404(Commande, pk=pk)
        if commande.statut != Commande.Statut.PRETE:
            raise PermissionDenied("Cette commande n'est pas encore prête.")

        commande.statut = Commande.Statut.SERVIE
        commande.date_servie = timezone.now()
        commande.save()
        commande.enregistrer_historique()

        notifier_client(commande)

        return Response(CommandeSerializer(commande).data)


class StatistiquesAdminView(APIView):
    """GET /api/admin/statistiques/ — vue d'ensemble du jour pour le tableau de bord admin."""

    permission_classes = [EstAdmin]

    def get(self, request):
        aujourdhui = timezone.now().date()
        commandes_jour = Commande.objects.filter(date_creation__date=aujourdhui)
        commandes_valides = commandes_jour.exclude(statut=Commande.Statut.ANNULEE).prefetch_related("lignes__plat")

        chiffre_affaires = sum((c.total for c in commandes_valides), 0)
        nb_valides = commandes_valides.count()

        par_statut = {
            statut: commandes_jour.filter(statut=statut).count()
            for statut, _ in Commande.Statut.choices
        }

        lignes_jour = LigneCommande.objects.filter(
            commande__in=commandes_valides
        ).select_related("plat")

        ventes_par_plat = {}
        for ligne in lignes_jour:
            cle = ligne.plat.nom
            ventes_par_plat[cle] = ventes_par_plat.get(cle, 0) + ligne.quantite
        top_plats = sorted(ventes_par_plat.items(), key=lambda item: -item[1])[:6]

        commandes_recentes = commandes_jour.order_by("-date_creation").prefetch_related("lignes__plat")[:15]

        return Response({
            "date": aujourdhui.isoformat(),
            "nombre_commandes": commandes_jour.count(),
            "chiffre_affaires": chiffre_affaires,
            "panier_moyen": round(chiffre_affaires / nb_valides, 0) if nb_valides else 0,
            "commandes_par_statut": par_statut,
            "top_plats": [{"nom": nom, "quantite": q} for nom, q in top_plats],
            "commandes_recentes": CommandeSerializer(commandes_recentes, many=True).data,
        })
