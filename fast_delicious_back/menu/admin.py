from django.contrib import admin

from .models import Categorie, GroupeChoix, OptionAccompagnement, OptionChoix, Plat


@admin.register(Categorie)
class CategorieAdmin(admin.ModelAdmin):
    list_display = ["nom", "ordre"]


@admin.register(OptionAccompagnement)
class OptionAccompagnementAdmin(admin.ModelAdmin):
    list_display = ["nom"]
    search_fields = ["nom"]


class OptionChoixInline(admin.TabularInline):
    model = OptionChoix
    extra = 2


class GroupeChoixInline(admin.TabularInline):
    """Permet de créer les groupes (ex: 'Grillade au choix') directement depuis la page du plat.
    Pour ajouter les options de chaque groupe, il faut ensuite ouvrir le groupe
    depuis la liste 'Groupes de choix' dans le menu admin.
    """
    model = GroupeChoix
    extra = 1
    fields = ["nom", "obligatoire", "ordre"]


@admin.register(GroupeChoix)
class GroupeChoixAdmin(admin.ModelAdmin):
    list_display = ["nom", "plat", "obligatoire", "ordre"]
    list_filter = ["plat"]
    inlines = [OptionChoixInline]


@admin.register(Plat)
class PlatAdmin(admin.ModelAdmin):
    list_display = ["nom", "categorie", "prix", "temps_preparation_min", "disponible", "accompagnement_obligatoire"]
    list_filter = ["categorie", "disponible"]
    search_fields = ["nom"]
    filter_horizontal = ["accompagnements"]
    inlines = [GroupeChoixInline]
