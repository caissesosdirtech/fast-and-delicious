from django.contrib import admin

from .models import Commande, HistoriqueStatut, LigneCommande


class LigneCommandeInline(admin.TabularInline):
    model = LigneCommande
    extra = 0


class HistoriqueStatutInline(admin.TabularInline):
    model = HistoriqueStatut
    extra = 0
    readonly_fields = ["statut", "date"]


@admin.register(Commande)
class CommandeAdmin(admin.ModelAdmin):
    list_display = ["id", "numero_table", "statut", "total", "date_creation"]
    list_filter = ["statut"]
    inlines = [LigneCommandeInline, HistoriqueStatutInline]
