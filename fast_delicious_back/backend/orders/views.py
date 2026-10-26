from django.http import HttpResponse
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

from datetime import datetime

from datetime import timedelta

from django.db.models import Count
from django.db.models.functions import TruncDate
from django.utils import timezone

from rest_framework.response import Response


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
    """
    GET /api/admin/statistiques/

    Paramètres :
    - date=YYYY-MM-DD : date à consulter
    - lieu=<id>       : filtrer par lieu (optionnel)
    """

    permission_classes = [EstAdmin]

    def get(self, request):
        # ============================================================
        # 1. DATE DEMANDÉE
        # ============================================================
        date_str = request.query_params.get("date")

        if date_str:
            try:
                date_selectionnee = datetime.strptime(
                    date_str, "%Y-%m-%d"
                ).date()
            except ValueError:
                return Response(
                    {
                        "detail": "Format de date invalide. Utilisez YYYY-MM-DD."
                    },
                    status=400,
                )
        else:
            date_selectionnee = timezone.localdate()

        # ============================================================
        # 2. COMMANDES DE LA DATE SÉLECTIONNÉE
        # ============================================================
        commandes_jour = Commande.objects.filter(
            date_creation__date=date_selectionnee
        )

        # ============================================================
        # 3. FILTRE PAR LIEU
        # ============================================================
        lieu_id = request.query_params.get("lieu")

        if lieu_id:
            commandes_jour = commandes_jour.filter(
                lieu_id=lieu_id
            )

        # ============================================================
        # 4. COMMANDES VALIDES
        # ============================================================
        commandes_valides = (
            commandes_jour
            .exclude(statut=Commande.Statut.ANNULEE)
            .prefetch_related("lignes__plat")
        )

        # ============================================================
        # 5. CHIFFRE D'AFFAIRES
        # ============================================================
        chiffre_affaires = sum(
            (c.total for c in commandes_valides),
            0
        )

        nb_valides = commandes_valides.count()

        # ============================================================
        # 6. COMMANDES PAR STATUT
        # ============================================================
        par_statut = {
            statut: commandes_jour.filter(
                statut=statut
            ).count()
            for statut, _ in Commande.Statut.choices
        }

        # ============================================================
        # 7. PLATS LES PLUS VENDUS
        # ============================================================
        lignes_jour = (
            LigneCommande.objects
            .filter(commande__in=commandes_valides)
            .select_related("plat")
        )

        ventes_par_plat = {}

        for ligne in lignes_jour:
            cle = ligne.plat.nom

            ventes_par_plat[cle] = (
                ventes_par_plat.get(cle, 0)
                + ligne.quantite
            )

        top_plats = sorted(
            ventes_par_plat.items(),
            key=lambda item: -item[1]
        )[:6]

        # ============================================================
        # 8. COMMANDES RÉCENTES DE LA DATE
        # ============================================================
        commandes_recentes = (
            commandes_jour
            .order_by("-date_creation")
            .prefetch_related("lignes__plat")[:15]
        )

        # ============================================================
        # 9. RÉPONSE
        # ============================================================
        return Response({
            "date": date_selectionnee.isoformat(),

            "est_aujourdhui": (
                date_selectionnee == timezone.localdate()
            ),

            "nombre_commandes": commandes_jour.count(),

            "chiffre_affaires": chiffre_affaires,

            "panier_moyen": (
                round(chiffre_affaires / nb_valides, 0)
                if nb_valides
                else 0
            ),

            "commandes_par_statut": par_statut,

            "top_plats": [
                {
                    "nom": nom,
                    "quantite": q
                }
                for nom, q in top_plats
            ],

            "commandes_recentes": (
                CommandeSerializer(
                    commandes_recentes,
                    many=True
                ).data
            ),
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

    permission_classes = [EstAdmin]

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
