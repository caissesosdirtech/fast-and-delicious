from django.db import models
from django.utils import timezone
from datetime import timedelta, datetime
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from realtime.utils import notifier_caisse, notifier_client, notifier_cuisine, notifier_livraison

from .models import Commande, LigneCommande
from .permissions import EstAdmin, EstCaissiere, EstCuisinier, EstLivreur, EstPersonnelInterne
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
    """GET /api/caisse/commandes/ — commandes en attente de validation par la caissière.
    Si la caissière est affectée à un lieu précis (cas de deux événements simultanés),
    elle ne voit que les commandes de son lieu. Sans affectation, elle voit tout.
    """

    serializer_class = CommandeSerializer
    permission_classes = [EstCaissiere]

    def get_queryset(self):
        # Parcours simplifié : la caissière/l'admin suit toute la commande (en attente,
        # validée, prête) sur un seul écran, jusqu'à ce qu'elle soit terminée (servie).
        qs = Commande.objects.filter(statut__in=[
            Commande.Statut.EN_ATTENTE,
            Commande.Statut.VALIDEE,
            Commande.Statut.PRETE,
        ])
        if self.request.user.lieu_id:
            qs = qs.filter(lieu_id=self.request.user.lieu_id)
        return qs.prefetch_related("lignes__plat")


class EncaisserCommandeView(APIView):
    """PATCH /api/caisse/commandes/<id>/encaisser/ — confirme que le paiement a bien été reçu,
    sans envoyer la commande en cuisine (ça reste l'action de ValiderCommandeView).
    Utile si la caissière veut confirmer l'argent reçu avant de décider du moment d'envoyer en cuisine.
    """

    permission_classes = [EstCaissiere]

    def patch(self, request, pk):
        commande = get_object_or_404(Commande, pk=pk)
        if commande.statut != Commande.Statut.EN_ATTENTE:
            raise PermissionDenied("Cette commande n'est plus en attente.")

        commande.paiement_confirme = True
        commande.save()

        return Response(CommandeSerializer(commande).data)


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
        commande.paiement_confirme = True  # la caissière valide = elle a vérifié le paiement (espèces ou mobile money)
        commande.save()
        commande.enregistrer_historique()

        notifier_client(commande)
        notifier_cuisine(commande, evenement="commande_validee")

        return Response(CommandeSerializer(commande).data)


class FileAttenteCuisineView(generics.ListAPIView):
    """GET /api/cuisine/commandes/ — commandes validées, en préparation, ou prêtes (sur place
    uniquement — les commandes en livraison une fois prêtes passent par le circuit livreur).
    Filtré par lieu si le cuisinier est affecté à un site précis."""

    serializer_class = CommandeSerializer
    permission_classes = [EstCuisinier]

    def get_queryset(self):
        qs = Commande.objects.filter(
            models.Q(statut__in=[Commande.Statut.VALIDEE, Commande.Statut.EN_PREPARATION])
            | models.Q(statut=Commande.Statut.PRETE, mode_commande=Commande.ModeCommande.SUR_PLACE)
        )
        if self.request.user.lieu_id:
            qs = qs.filter(lieu_id=self.request.user.lieu_id)
        return qs.prefetch_related("lignes__plat")


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
    """PATCH /api/caisse/commandes/<id>/prete/ — la caissière/l'admin marque la commande prête.
    Parcours simplifié : on passe directement de « Validée » à « Prête » (l'étape cuisine n'est
    plus un rôle séparé)."""

    permission_classes = [EstCaissiere]

    def patch(self, request, pk):
        commande = get_object_or_404(Commande, pk=pk)
        # On accepte aussi EN_PREPARATION pour d'anciennes commandes déjà en cours.
        if commande.statut not in [Commande.Statut.VALIDEE, Commande.Statut.EN_PREPARATION]:
            raise PermissionDenied("Cette commande doit d'abord être validée.")

        commande.statut = Commande.Statut.PRETE
        commande.date_prete = timezone.now()
        commande.save()
        commande.enregistrer_historique()

        notifier_client(commande)

        return Response(CommandeSerializer(commande).data)


class MarquerServieView(APIView):
    """PATCH /api/caisse/commandes/<id>/terminer/ — la caissière/l'admin clôture la commande
    (sur place comme en livraison). Dernière étape du parcours simplifié avant le reçu.
    """

    permission_classes = [EstCaissiere]

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


class FileLivraisonView(generics.ListAPIView):
    """GET /api/livraison/commandes/ — commandes prêtes à livrer (non assignées),
    plus celles déjà prises en charge par le livreur connecté. Filtré par lieu si le
    livreur est affecté à un site précis.
    """

    serializer_class = CommandeSerializer
    permission_classes = [EstLivreur]

    def get_queryset(self):
        qs = Commande.objects.filter(
            mode_commande=Commande.ModeCommande.LIVRAISON,
        ).filter(
            models.Q(statut=Commande.Statut.PRETE, livreur__isnull=True)
            | models.Q(statut=Commande.Statut.EN_LIVRAISON, livreur=self.request.user)
        )
        if self.request.user.lieu_id:
            qs = qs.filter(lieu_id=self.request.user.lieu_id)
        return qs.prefetch_related("lignes__plat")


class PrendreLivraisonView(APIView):
    """PATCH /api/livraison/commandes/<id>/prendre/ — le livreur prend la commande en charge."""

    permission_classes = [EstLivreur]

    def patch(self, request, pk):
        commande = get_object_or_404(Commande, pk=pk)
        if commande.mode_commande != Commande.ModeCommande.LIVRAISON:
            raise PermissionDenied("Cette commande n'est pas une commande en livraison.")
        if commande.statut != Commande.Statut.PRETE:
            raise PermissionDenied("Cette commande n'est pas prête ou est déjà prise en charge.")

        commande.statut = Commande.Statut.EN_LIVRAISON
        commande.date_debut_livraison = timezone.now()
        commande.livreur = request.user
        commande.save()
        commande.enregistrer_historique()

        notifier_client(commande)

        return Response(CommandeSerializer(commande).data)


class MarquerLivreeView(APIView):
    """PATCH /api/livraison/commandes/<id>/livree/ — le livreur confirme la livraison effectuée."""

    permission_classes = [EstLivreur]

    def patch(self, request, pk):
        commande = get_object_or_404(Commande, pk=pk)
        if commande.statut != Commande.Statut.EN_LIVRAISON:
            raise PermissionDenied("Cette commande n'est pas en cours de livraison.")
        if commande.livreur_id != request.user.id and request.user.role != "admin":
            raise PermissionDenied("Cette commande est prise en charge par un autre livreur.")

        commande.statut = Commande.Statut.SERVIE
        commande.date_servie = timezone.now()
        commande.save()
        commande.enregistrer_historique()

        notifier_client(commande)

        return Response(CommandeSerializer(commande).data)


class AnnulerCommandeView(APIView):
    """PATCH /api/commandes/<id>/annuler/ — annule une commande.
    - Le client (anonyme) peut annuler tant qu'elle est encore EN_ATTENTE (avant validation caisse).
    - Seule la caissière (ou l'admin) peut annuler jusqu'à EN_PREPARATION inclus — la décision
      d'annuler revient à la caisse, jamais à la cuisine ni au livreur, même une fois la commande
      prise en charge en cuisine.
    """

    permission_classes = [permissions.AllowAny]

    STATUTS_ANNULABLES_STAFF = [
        Commande.Statut.EN_ATTENTE, Commande.Statut.VALIDEE, Commande.Statut.EN_PREPARATION,
    ]

    def patch(self, request, pk):
        commande = get_object_or_404(Commande, pk=pk)
        utilisateur = request.user if request.user.is_authenticated else None
        est_staff = utilisateur and utilisateur.role in ["caissiere", "admin"]

        if est_staff:
            if commande.statut not in self.STATUTS_ANNULABLES_STAFF:
                raise PermissionDenied("Cette commande est trop avancée pour être annulée.")
        else:
            if commande.statut != Commande.Statut.EN_ATTENTE:
                raise PermissionDenied(
                    "Cette commande a déjà été prise en charge et ne peut plus être annulée directement ; "
                    "contactez la caisse."
                )

        commande.statut = Commande.Statut.ANNULEE
        commande.motif_annulation = request.data.get("motif", "").strip()
        commande.save()
        commande.enregistrer_historique()

        notifier_client(commande)
        notifier_caisse(commande, evenement="commande_annulee")
        notifier_cuisine(commande, evenement="commande_annulee")
        if commande.mode_commande == Commande.ModeCommande.LIVRAISON:
            notifier_livraison(commande, evenement="commande_annulee")

        return Response(CommandeSerializer(commande).data)


class PaiementsRecentsView(generics.ListAPIView):
    """GET /api/caisse/paiements-recents/ — les 10 dernières commandes payées en mobile money
    (Wave/Orange Money/QR), peu importe le jour — pas limité à aujourd'hui."""

    serializer_class = CommandeSerializer
    permission_classes = [EstCaissiere]

    def get_queryset(self):
        return Commande.objects.exclude(
            mode_paiement=Commande.ModePaiement.ESPECES,
        ).order_by("-date_creation").prefetch_related("lignes__plat")[:10]


class HistoriqueRecentView(generics.ListAPIView):
    """GET /api/caisse/historique-recent/ — les 10 dernières commandes terminées (servies ou
    annulées), peu importe le jour — pas limité à aujourd'hui."""

    serializer_class = CommandeSerializer
    permission_classes = [EstCaissiere]

    def get_queryset(self):
        # ?limite=N (défaut 10, borné à 100) — permet un bouton "Voir plus" côté tableau de bord.
        try:
            limite = int(self.request.query_params.get("limite", 10))
        except (TypeError, ValueError):
            limite = 10
        limite = max(1, min(limite, 100))
        return Commande.objects.filter(
            statut__in=[Commande.Statut.SERVIE, Commande.Statut.ANNULEE],
        ).order_by("-date_creation").prefetch_related("lignes__plat")[:limite]


class ClientsLivraisonView(APIView):
    """GET /api/caisse/clients/ — clients agrégés à partir de leurs commandes en livraison
    (aucune fiche client dédiée n'existe : on regroupe simplement par numéro de téléphone).
    """

    permission_classes = [EstCaissiere]

    def get(self, request):
        commandes = Commande.objects.filter(
            mode_commande=Commande.ModeCommande.LIVRAISON,
        ).exclude(telephone_client="").order_by("date_creation")

        agrege = {}
        for c in commandes:
            tel = c.telephone_client
            entree = agrege.setdefault(tel, {
                "telephone": tel,
                "derniere_adresse": c.adresse_livraison,
                "nombre_commandes": 0,
                "total_depense": 0,
                "derniere_commande": c.date_creation,
            })
            entree["nombre_commandes"] += 1
            entree["total_depense"] += float(c.total)
            if c.date_creation >= entree["derniere_commande"]:
                entree["derniere_commande"] = c.date_creation
                entree["derniere_adresse"] = c.adresse_livraison

        resultats = sorted(agrege.values(), key=lambda x: x["derniere_commande"], reverse=True)
        for r in resultats:
            r["derniere_commande"] = r["derniere_commande"].isoformat()

        return Response(resultats)


class StatistiquesAdminView(APIView):
    """GET /api/admin/statistiques/ — vue d'ensemble du jour, utilisée par tous les tableaux
    de bord staff (KPI en caisse/cuisine, tableau complet pour l'admin).
    Si l'utilisateur est affecté à un lieu précis, les stats sont automatiquement filtrées sur
    ce lieu. Un admin (non affecté) peut passer ?lieu=<id> pour consulter un site en particulier,
    ou ne rien passer pour voir l'ensemble (tous lieux confondus).
    """

    permission_classes = [EstPersonnelInterne]

    def get(self, request):
        lieu_id = request.query_params.get("lieu")
        if request.user.lieu_id and request.user.role != "admin":
            lieu_id = request.user.lieu_id  # le staff affecté à un lieu ne voit que le sien

        aujourdhui = timezone.localdate()
        # Date demandée (?date=YYYY-MM-DD), sinon aujourd'hui.
        date_str = request.query_params.get("date")
        if date_str:
            try:
                jour_ref = datetime.strptime(date_str, "%Y-%m-%d").date()
            except ValueError:
                return Response({"detail": "Format de date invalide. Utilisez YYYY-MM-DD."}, status=400)
        else:
            jour_ref = aujourdhui
        commandes_jour = Commande.objects.filter(date_creation__date=jour_ref)
        if lieu_id:
            commandes_jour = commandes_jour.filter(lieu_id=lieu_id)
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

        # Tendance des ventes sur les 7 derniers jours (dont aujourd'hui), pour le graphique admin.
        ventes_7_jours = []
        for i in range(6, -1, -1):
            jour = jour_ref - timedelta(days=i)
            commandes_du_jour = Commande.objects.filter(date_creation__date=jour).exclude(statut=Commande.Statut.ANNULEE)
            if lieu_id:
                commandes_du_jour = commandes_du_jour.filter(lieu_id=lieu_id)
            total_jour = sum((c.total for c in commandes_du_jour), 0)
            ventes_7_jours.append({"date": jour.isoformat(), "total": total_jour})

        return Response({
            "date": jour_ref.isoformat(),
            "est_aujourdhui": jour_ref == aujourdhui,
            "lieu_id": int(lieu_id) if lieu_id else None,
            "nombre_commandes": commandes_jour.count(),
            "chiffre_affaires": chiffre_affaires,
            "panier_moyen": round(chiffre_affaires / nb_valides, 0) if nb_valides else 0,
            "commandes_par_statut": par_statut,
            "top_plats": [{"nom": nom, "quantite": q} for nom, q in top_plats],
            "commandes_recentes": CommandeSerializer(commandes_recentes, many=True).data,
            "ventes_7_jours": ventes_7_jours,
        })

class EtatCaisseView(APIView):
    """
    GET /api/admin/caisse/?periode=jour
    GET /api/admin/caisse/?periode=semaine
    GET /api/admin/caisse/?periode=mois
    GET /api/admin/caisse/?periode=annee
    """

    permission_classes = [EstAdmin]

    def get(self, request):
        periode = request.query_params.get("periode", "jour")

        aujourd_hui = timezone.localdate()

        # ============================================================
        # DÉTERMINATION DE LA PÉRIODE
        # ============================================================

        if periode == "jour":

            date_debut = aujourd_hui
            date_fin = aujourd_hui

            libelle_periode = (
                f"Ventes du {aujourd_hui.strftime('%d/%m/%Y')}"
            )

        elif periode == "semaine":

            date_debut = (
                aujourd_hui
                - timedelta(days=aujourd_hui.weekday())
            )

            date_fin = aujourd_hui

            libelle_periode = (
                f"Du {date_debut.strftime('%d/%m/%Y')} "
                f"au {date_fin.strftime('%d/%m/%Y')}"
            )

        elif periode == "mois":

            date_debut = aujourd_hui.replace(day=1)
            date_fin = aujourd_hui

            libelle_periode = (
                aujourd_hui.strftime("%B %Y").capitalize()
            )

        elif periode == "annee":

            date_debut = aujourd_hui.replace(
                month=1,
                day=1
            )

            date_fin = aujourd_hui

            libelle_periode = f"Année {aujourd_hui.year}"

        else:
            return Response(
                {
                    "detail": (
                        "Période invalide. "
                        "Utilisez jour, semaine, mois ou annee."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # ============================================================
        # COMMANDES DE LA PÉRIODE
        # ============================================================

        commandes = (
            Commande.objects
            .filter(
                date_creation__date__gte=date_debut,
                date_creation__date__lte=date_fin
            )
            .exclude(
                statut=Commande.Statut.ANNULEE
            )
            .prefetch_related("lignes__plat")
            .order_by("-date_creation")
        )

        # ============================================================
        # CHIFFRE D'AFFAIRES
        # ============================================================

        chiffre_affaires = sum(
            (commande.total for commande in commandes),
            0
        )

        nombre_commandes = commandes.count()

        panier_moyen = (
            round(
                chiffre_affaires / nombre_commandes,
                0
            )
            if nombre_commandes
            else 0
        )

        # ============================================================
        # ÉVOLUTION JOUR PAR JOUR
        # ============================================================

        evolution = []

        date_courante = date_debut

        while date_courante <= date_fin:

            commandes_date = [
                commande
                for commande in commandes
                if timezone.localtime(
                    commande.date_creation
                ).date() == date_courante
            ]

            total_date = sum(
                (commande.total for commande in commandes_date),
                0
            )

            evolution.append({
                "date": date_courante.isoformat(),

                "label": date_courante.strftime("%d/%m"),

                "total": total_date,

                "commandes": len(commandes_date),
            })

            date_courante += timedelta(days=1)

        # ============================================================
        # RÉPONSE
        # ============================================================

        return Response({
            "periode": periode,

            "date_debut": date_debut.isoformat(),

            "date_fin": date_fin.isoformat(),

            "libelle_periode": libelle_periode,

            "chiffre_affaires": chiffre_affaires,

            "nombre_commandes": nombre_commandes,

            "panier_moyen": panier_moyen,

            "evolution": evolution,

            "commandes": CommandeSerializer(
                commandes[:30],
                many=True
            ).data,
        })    
