from django.urls import path

from . import views

urlpatterns = [
    # Client
    path("commandes/", views.CommandeCreationView.as_view(), name="commande-creation"),
    path("commandes/<int:pk>/", views.CommandeDetailView.as_view(), name="commande-detail"),
    path("commandes/<int:pk>/servie/", views.MarquerServieView.as_view(), name="commande-servie"),

    # Caisse
    path("caisse/commandes/", views.FileAttenteCaisseView.as_view(), name="caisse-file"),
    path("caisse/commandes/<int:pk>/valider/", views.ValiderCommandeView.as_view(), name="caisse-valider"),

    # Cuisine
    path("cuisine/commandes/", views.FileAttenteCuisineView.as_view(), name="cuisine-file"),
    path("cuisine/commandes/<int:pk>/preparer/", views.DemarrerPreparationView.as_view(), name="cuisine-preparer"),
    path("cuisine/commandes/<int:pk>/prete/", views.MarquerPreteView.as_view(), name="cuisine-prete"),

    # Admin
    path("admin/statistiques/", views.StatistiquesAdminView.as_view(), name="admin-statistiques"),
]
