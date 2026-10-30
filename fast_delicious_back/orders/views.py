from django.db import models
from django.http import HttpResponse
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
from .serializers import CommandeCreationSerializer, CommandeSerializer, VenteDirecteSerializer


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
        date_str = request.query_params.get("date")

        aujourd_hui = timezone.localdate()

        # ============================================================
        # DÉTERMINATION DE LA PÉRIODE
        # ============================================================

        # Date précise demandée (?date=YYYY-MM-DD) : on affiche ce jour-là,
        # prioritaire sur la période.
        if date_str:
            try:
                jour = datetime.strptime(date_str, "%Y-%m-%d").date()
            except ValueError:
                return Response(
                    {"detail": "Format de date invalide. Utilisez YYYY-MM-DD."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            date_debut = jour
            date_fin = jour
            libelle_periode = f"Ventes du {jour.strftime('%d/%m/%Y')}"

        elif periode == "jour":

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


# ============================================================
# EXPORT DU RAPPORT DE CAISSE (PDF / Excel)
# ============================================================

LABELS_MODE_PAIEMENT = {
    "ESPECES": "Espèces",
    "PI_MIX": "QR (PI Mix / YAS)",
    "WAVE": "Wave",
    "ORANGE_MONEY": "Orange Money",
}


def _plage_caisse(periode, date_str, aujourd_hui):
    """(date_debut, date_fin, libelle) pour l'export — même logique que EtatCaisseView.
    Lève ValueError si la date est invalide, renvoie None si la période est inconnue."""
    if date_str:
        jour = datetime.strptime(date_str, "%Y-%m-%d").date()
        return jour, jour, f"Ventes du {jour.strftime('%d/%m/%Y')}"
    if periode == "jour":
        return aujourd_hui, aujourd_hui, f"Ventes du {aujourd_hui.strftime('%d/%m/%Y')}"
    if periode == "semaine":
        d = aujourd_hui - timedelta(days=aujourd_hui.weekday())
        return d, aujourd_hui, f"Du {d.strftime('%d/%m/%Y')} au {aujourd_hui.strftime('%d/%m/%Y')}"
    if periode == "mois":
        return aujourd_hui.replace(day=1), aujourd_hui, aujourd_hui.strftime("%B %Y").capitalize()
    if periode == "annee":
        return aujourd_hui.replace(month=1, day=1), aujourd_hui, f"Année {aujourd_hui.year}"
    return None


def _espace(n):
    """Formate un entier avec des espaces comme séparateur de milliers."""
    return f"{int(n):,}".replace(",", " ")


class ExportCaisseView(APIView):
    """GET /api/admin/caisse/export/?format=pdf|xlsx&periode=...&date=YYYY-MM-DD&lieu=<id>
    Rapport de caisse téléchargeable (résumé + répartition paiement + liste des ventes)."""

    # Admin ET caissière : la caissière doit pouvoir télécharger le rapport du jour depuis le mobile.
    permission_classes = [EstAdmin | EstCaissiere]

    def get(self, request):
        periode = request.query_params.get("periode", "jour")
        date_str = request.query_params.get("date")
        fmt = request.query_params.get("fmt", "pdf").lower()
        aujourd_hui = timezone.localdate()

        try:
            plage = _plage_caisse(periode, date_str, aujourd_hui)
        except ValueError:
            return Response({"detail": "Format de date invalide. Utilisez YYYY-MM-DD."}, status=status.HTTP_400_BAD_REQUEST)
        if plage is None:
            return Response({"detail": "Période invalide."}, status=status.HTTP_400_BAD_REQUEST)
        date_debut, date_fin, libelle = plage

        lieu_id = request.query_params.get("lieu")
        commandes = (
            Commande.objects
            .filter(date_creation__date__gte=date_debut, date_creation__date__lte=date_fin)
            .exclude(statut=Commande.Statut.ANNULEE)
            .prefetch_related("lignes__plat")
            .order_by("date_creation")
        )
        if lieu_id:
            commandes = commandes.filter(lieu_id=lieu_id)

        ventes = []
        chiffre = 0
        par_mode = {}
        for c in commandes:
            total = c.total
            chiffre += total
            mode_p = getattr(c, "mode_paiement", "ESPECES")
            par_mode[mode_p] = par_mode.get(mode_p, 0) + total
            articles = ", ".join(f"{l.quantite}x {l.plat.nom}" for l in c.lignes.all())
            if getattr(c, "mode_commande", "SUR_PLACE") == "LIVRAISON":
                lieu_txt = "Livraison"
            else:
                lieu_txt = getattr(c, "numero_table", "") or "Sur place"
            ventes.append({
                "id": c.id,
                "heure": timezone.localtime(c.date_creation).strftime("%d/%m %H:%M"),
                "lieu": lieu_txt,
                "articles": articles,
                "mode": LABELS_MODE_PAIEMENT.get(mode_p, mode_p),
                "statut": c.statut,
                "total": total,
            })
        nombre = len(ventes)
        panier = round(chiffre / nombre, 0) if nombre else 0

        if fmt == "xlsx":
            return self._excel(libelle, chiffre, nombre, panier, par_mode, ventes, date_fin)
        return self._pdf(libelle, chiffre, nombre, panier, par_mode, ventes, date_fin)

    # --------------------------------------------------------
    def _excel(self, libelle, chiffre, nombre, panier, par_mode, ventes, date_fin):
        import io
        from openpyxl import Workbook
        from openpyxl.styles import Font, PatternFill
        from openpyxl.utils import get_column_letter

        wb = Workbook()
        ws = wb.active
        ws.title = "Caisse"

        ws["A1"] = "RAPPORT DE CAISSE"
        ws["A1"].font = Font(size=16, bold=True, color="D6402A")
        ws["A2"] = libelle
        ws["A3"] = f"Généré le {date_fin.strftime('%d/%m/%Y')}"

        ws["A5"] = "Total encaissé (FCFA)"
        ws["B5"] = int(chiffre)
        ws["B5"].font = Font(bold=True)
        ws["A6"] = "Nombre de ventes"
        ws["B6"] = nombre
        ws["A7"] = "Panier moyen (FCFA)"
        ws["B7"] = int(panier)

        row = 9
        ws.cell(row=row, column=1, value="Par mode de paiement").font = Font(bold=True)
        row += 1
        for mode, total in par_mode.items():
            ws.cell(row=row, column=1, value=LABELS_MODE_PAIEMENT.get(mode, mode))
            ws.cell(row=row, column=2, value=int(total))
            row += 1

        row += 1
        entetes = ["N°", "Date/Heure", "Table / Livraison", "Articles", "Paiement", "Statut", "Total (FCFA)"]
        for i, e in enumerate(entetes, start=1):
            cell = ws.cell(row=row, column=i, value=e)
            cell.font = Font(bold=True, color="FFFFFF")
            cell.fill = PatternFill("solid", fgColor="2B241A")
        row += 1
        for v in ventes:
            ws.cell(row=row, column=1, value=v["id"])
            ws.cell(row=row, column=2, value=v["heure"])
            ws.cell(row=row, column=3, value=v["lieu"])
            ws.cell(row=row, column=4, value=v["articles"])
            ws.cell(row=row, column=5, value=v["mode"])
            ws.cell(row=row, column=6, value=v["statut"])
            ws.cell(row=row, column=7, value=int(v["total"]))
            row += 1
        ws.cell(row=row, column=6, value="TOTAL").font = Font(bold=True)
        ws.cell(row=row, column=7, value=int(chiffre)).font = Font(bold=True)

        largeurs = [8, 14, 20, 45, 16, 14, 14]
        for i, w in enumerate(largeurs, start=1):
            ws.column_dimensions[get_column_letter(i)].width = w

        buf = io.BytesIO()
        wb.save(buf)
        buf.seek(0)
        resp = HttpResponse(
            buf.read(),
            content_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
        resp["Content-Disposition"] = f'attachment; filename="caisse_{date_fin.isoformat()}.xlsx"'
        return resp

    # --------------------------------------------------------
    def _pdf(self, libelle, chiffre, nombre, panier, par_mode, ventes, date_fin):
        import io
        from reportlab.lib.pagesizes import A4
        from reportlab.lib import colors
        from reportlab.lib.units import mm
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle

        buf = io.BytesIO()
        doc = SimpleDocTemplate(
            buf, pagesize=A4,
            topMargin=16 * mm, bottomMargin=14 * mm, leftMargin=12 * mm, rightMargin=12 * mm,
        )
        styles = getSampleStyleSheet()
        style_titre = ParagraphStyle("t", parent=styles["Title"], textColor=colors.HexColor("#D6402A"), fontSize=20, spaceAfter=2)
        style_sous = ParagraphStyle("s", parent=styles["Normal"], textColor=colors.HexColor("#7A7061"), fontSize=10)
        style_cell = ParagraphStyle("c", parent=styles["BodyText"], fontSize=8, leading=10)

        elements = [
            Paragraph("RAPPORT DE CAISSE", style_titre),
            Paragraph(libelle, style_sous),
            Paragraph(f"Généré le {date_fin.strftime('%d/%m/%Y')}", style_sous),
            Spacer(1, 10),
        ]

        resume = [
            ["Total encaissé", f"{_espace(chiffre)} FCFA"],
            ["Nombre de ventes", str(nombre)],
            ["Panier moyen", f"{_espace(panier)} FCFA"],
        ]
        for mode, total in par_mode.items():
            resume.append([LABELS_MODE_PAIEMENT.get(mode, mode), f"{_espace(total)} FCFA"])
        t_resume = Table(resume, colWidths=[60 * mm, 60 * mm])
        t_resume.setStyle(TableStyle([
            ("FONTSIZE", (0, 0), (-1, -1), 10),
            ("TEXTCOLOR", (0, 0), (0, -1), colors.HexColor("#7A7061")),
            ("FONTNAME", (1, 0), (1, -1), "Helvetica-Bold"),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]))
        elements.append(t_resume)
        elements.append(Spacer(1, 14))

        data = [["N°", "Heure", "Table/Livr.", "Articles", "Paiement", "Total"]]
        for v in ventes:
            data.append([
                str(v["id"]),
                v["heure"],
                Paragraph(v["lieu"], style_cell),
                Paragraph(v["articles"], style_cell),
                Paragraph(v["mode"], style_cell),
                _espace(v["total"]),
            ])
        data.append(["", "", "", "", "TOTAL", _espace(chiffre)])
        tbl = Table(
            data,
            colWidths=[11 * mm, 20 * mm, 26 * mm, 70 * mm, 24 * mm, 22 * mm],
            repeatRows=1,
        )
        tbl.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#2B241A")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 8),
            ("ROWBACKGROUNDS", (0, 1), (-1, -2), [colors.white, colors.HexColor("#F7F2E8")]),
            ("LINEBELOW", (0, 0), (-1, -1), 0.3, colors.HexColor("#E0D8C8")),
            ("FONTNAME", (4, -1), (-1, -1), "Helvetica-Bold"),
            ("ALIGN", (5, 0), (5, -1), "RIGHT"),
            ("ALIGN", (0, 0), (0, -1), "CENTER"),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("TOPPADDING", (0, 0), (-1, -1), 3),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ]))
        elements.append(tbl)

        doc.build(elements)
        buf.seek(0)
        resp = HttpResponse(buf.read(), content_type="application/pdf")
        resp["Content-Disposition"] = f'attachment; filename="caisse_{date_fin.isoformat()}.pdf"'
        return resp


class VenteDirecteView(APIView):
    """POST /api/caisse/vente-directe/ — vente au comptoir.

    Crée une commande déjà encaissée et servie (statut SERVIE, paiement confirmé),
    en un seul appel : le client achète directement à la caisse sans commande en ligne.
    Accessible à la caissière et à l'admin.
    """

    permission_classes = [EstCaissiere]

    def post(self, request):
        serializer = VenteDirecteSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        commande = serializer.save()
        return Response(CommandeSerializer(commande).data, status=status.HTTP_201_CREATED)


class StatistiquesAvanceesView(APIView):
    """GET /api/admin/statistiques/avancees/?periode=jour|semaine|mois|annee[&lieu=<id>]

    Statistiques enrichies pour l'admin :
      - produits les plus vendus (quantité + chiffre d'affaires) ;
      - heures de pointe (nombre de commandes et CA par heure de la journée) ;
      - chiffre d'affaires par caissière ;
      - chiffre d'affaires par stand / lieu.

    Comme pour la vue d'ensemble, un membre du staff affecté à un lieu ne voit
    que son lieu ; un admin voit tout (ou un lieu précis via ?lieu=<id>).
    """

    permission_classes = [EstPersonnelInterne]

    def get(self, request):
        lieu_id = request.query_params.get("lieu")
        if getattr(request.user, "lieu_id", None) and request.user.role != "admin":
            lieu_id = request.user.lieu_id

        periode = request.query_params.get("periode", "jour")
        aujourdhui = timezone.localdate()
        if periode == "semaine":
            debut = aujourdhui - timedelta(days=6)
        elif periode == "mois":
            debut = aujourdhui.replace(day=1)
        elif periode == "annee":
            debut = aujourdhui.replace(month=1, day=1)
        else:
            periode = "jour"
            debut = aujourdhui
        fin = aujourdhui

        commandes = Commande.objects.filter(
            date_creation__date__gte=debut, date_creation__date__lte=fin,
        ).exclude(statut=Commande.Statut.ANNULEE)
        if lieu_id:
            commandes = commandes.filter(lieu_id=lieu_id)

        montant = lambda champ_qte, champ_prix: models.Sum(
            models.ExpressionWrapper(
                models.F(champ_qte) * models.F(champ_prix),
                output_field=models.DecimalField(max_digits=12, decimal_places=2),
            )
        )

        # --- Produits les plus vendus (quantité + CA), agrégés en base ---
        lignes = (
            LigneCommande.objects.filter(commande__in=commandes)
            .values("plat__nom")
            .annotate(qte_totale=models.Sum("quantite"), ca=montant("quantite", "plat__prix"))
            .order_by("-qte_totale")[:10]
        )
        top_produits = [
            {"nom": l["plat__nom"], "quantite": l["qte_totale"], "ca": float(l["ca"] or 0)}
            for l in lignes
        ]

        # --- CA par commande (annotation), puis répartition par heure / caissière / lieu ---
        commandes_ca = commandes.annotate(
            ca=montant("lignes__quantite", "lignes__plat__prix")
        ).select_related("caissiere", "lieu")

        par_heure = {h: {"heure": h, "nombre": 0, "ca": 0.0} for h in range(24)}
        par_caissiere = {}
        par_lieu = {}
        total_ca = 0.0
        total_nb = 0

        for c in commandes_ca:
            ca = float(c.ca or 0)
            total_ca += ca
            total_nb += 1

            h = timezone.localtime(c.date_creation).hour
            par_heure[h]["nombre"] += 1
            par_heure[h]["ca"] += ca

            if c.caissiere:
                nom_c = (c.caissiere.get_full_name() or "").strip() or c.caissiere.username
            else:
                nom_c = "Non attribuée"
            agg_c = par_caissiere.setdefault(nom_c, {"nom": nom_c, "nombre": 0, "ca": 0.0})
            agg_c["nombre"] += 1
            agg_c["ca"] += ca

            nom_l = c.lieu.nom if c.lieu else "Sans lieu"
            agg_l = par_lieu.setdefault(nom_l, {"nom": nom_l, "nombre": 0, "ca": 0.0})
            agg_l["nombre"] += 1
            agg_l["ca"] += ca

        return Response({
            "periode": periode,
            "debut": debut.isoformat(),
            "fin": fin.isoformat(),
            "lieu_id": int(lieu_id) if lieu_id else None,
            "totaux": {"nombre": total_nb, "ca": round(total_ca, 2)},
            "top_produits": top_produits,
            "par_heure": [par_heure[h] for h in range(24)],
            "par_caissiere": sorted(par_caissiere.values(), key=lambda x: -x["ca"]),
            "par_lieu": sorted(par_lieu.values(), key=lambda x: -x["ca"]),
        })


# ============================================================
# PAIEMENT EN LIGNE — Wave & Orange Money
# ============================================================
from .paiements import (  # noqa: E402  (import groupé en fin de fichier)
    WaveClient, OrangeMoneyClient, PaiementNonConfigure, ErreurPaiement,
)


def _confirmer_paiement(commande, mode, reference=""):
    """Marque une commande comme payée et prévient la caisse en temps réel."""
    commande.paiement_confirme = True
    commande.mode_paiement = mode
    if reference:
        commande.reference_paiement = reference
    commande.save(update_fields=["paiement_confirme", "mode_paiement", "reference_paiement"])
    try:
        notifier_caisse(commande, evenement="paiement_confirme")
    except Exception:
        pass


class InitierPaiementView(APIView):
    """POST /api/caisse/commandes/<id>/paiement/  body: {"provider": "WAVE"|"ORANGE_MONEY"}

    Crée une demande de paiement chez le fournisseur et renvoie l'URL / QR à
    présenter au client. La confirmation arrivera via le webhook.
    """

    permission_classes = [EstCaissiere]

    def post(self, request, pk):
        commande = get_object_or_404(Commande, pk=pk)
        provider = (request.data.get("provider") or "").upper()
        montant = commande.total

        try:
            if provider == "WAVE":
                resultat = WaveClient.creer_session(commande, montant)
            elif provider == "ORANGE_MONEY":
                resultat = OrangeMoneyClient.creer_paiement(commande, montant)
            else:
                return Response({"detail": "Fournisseur inconnu (WAVE ou ORANGE_MONEY)."}, status=400)
        except PaiementNonConfigure as e:
            return Response({"detail": str(e)}, status=400)
        except ErreurPaiement as e:
            return Response({"detail": str(e)}, status=502)

        # On mémorise le fournisseur et l'identifiant de session (utile au webhook).
        commande.mode_paiement = provider
        commande.reference_paiement = resultat.get("session_id", "")
        commande.save(update_fields=["mode_paiement", "reference_paiement"])

        return Response(resultat, status=200)


class WaveWebhookView(APIView):
    """POST /api/webhooks/wave/  — notification de Wave (signature vérifiée)."""

    authentication_classes = []
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        signature = request.headers.get("Wave-Signature", "")
        if not WaveClient.verifier_signature(request.body, signature):
            return Response({"detail": "Signature invalide."}, status=400)

        evenement = request.data or {}
        if evenement.get("type") != "checkout.session.completed":
            return Response({"recu": True})  # autre évènement : on accuse réception

        data = evenement.get("data", {}) or {}
        if (data.get("payment_status") or "").lower() not in ("succeeded", "success", "paid"):
            return Response({"recu": True})

        ref = data.get("client_reference")
        if ref:
            try:
                commande = Commande.objects.get(pk=int(ref))
                _confirmer_paiement(
                    commande, "WAVE",
                    reference=data.get("transaction_id") or data.get("id") or "",
                )
            except (Commande.DoesNotExist, ValueError, TypeError):
                pass
        return Response({"recu": True})


class OrangeMoneyWebhookView(APIView):
    """POST /api/webhooks/orange-money/ — notification d'Orange Money."""

    authentication_classes = []
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        data = request.data or {}
        order_id = data.get("order_id")
        statut = (data.get("status") or "").upper()
        if not order_id:
            return Response({"recu": True})

        try:
            commande = Commande.objects.get(pk=int(order_id))
        except (Commande.DoesNotExist, ValueError, TypeError):
            return Response({"recu": True})

        # Par sécurité, on reconfirme le statut auprès d'Orange (le pay_token a été
        # mémorisé dans reference_paiement au moment de l'initiation).
        succes = statut in ("SUCCESS", "SUCCESSFUL", "COMPLETED")
        pay_token = commande.reference_paiement
        if pay_token:
            try:
                succes = OrangeMoneyClient.verifier_statut(order_id, commande.total, pay_token)
            except ErreurPaiement:
                pass  # on garde le statut de la notification en secours

        if succes:
            _confirmer_paiement(commande, "ORANGE_MONEY", reference=str(data.get("txnid") or ""))
        return Response({"recu": True})
