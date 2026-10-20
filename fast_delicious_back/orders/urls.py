from django.urls import path

from . import views

urlpatterns = [
    # Client
    path("commandes/", views.CommandeCreationView.as_view(), name="commande-creation"),
    path("commandes/<int:pk>/", views.CommandeDetailView.as_view(), name="commande-detail"),
    path("commandes/<int:pk>/servie/", views.MarquerServieView.as_view(), name="commande-servie"),
    path("commandes/<int:pk>/annuler/", views.AnnulerCommandeView.as_view(), name="commande-annuler"),

    # Caisse
    path("caisse/commandes/", views.FileAttenteCaisseView.as_view(), name="caisse-file"),
    path("caisse/commandes/<int:pk>/encaisser/", views.EncaisserCommandeView.as_view(), name="caisse-encaisser"),
    path("caisse/commandes/<int:pk>/valider/", views.ValiderCommandeView.as_view(), name="caisse-valider"),
    path("caisse/commandes/<int:pk>/prete/", views.MarquerPreteView.as_view(), name="caisse-prete"),
    path("caisse/commandes/<int:pk>/terminer/", views.MarquerServieView.as_view(), name="caisse-terminer"),

    # Cuisine
    path("cuisine/commandes/", views.FileAttenteCuisineView.as_view(), name="cuisine-file"),
    path("cuisine/commandes/<int:pk>/preparer/", views.DemarrerPreparationView.as_view(), name="cuisine-preparer"),
    path("cuisine/commandes/<int:pk>/prete/", views.MarquerPreteView.as_view(), name="cuisine-prete"),

    # Livraison
    path("livraison/commandes/", views.FileLivraisonView.as_view(), name="livraison-file"),
    path("livraison/commandes/<int:pk>/prendre/", views.PrendreLivraisonView.as_view(), name="livraison-prendre"),
    path("livraison/commandes/<int:pk>/livree/", views.MarquerLivreeView.as_view(), name="livraison-livree"),

    path("caisse/clients/", views.ClientsLivraisonView.as_view(), name="caisse-clients"),
    path("caisse/paiements-recents/", views.PaiementsRecentsView.as_view(), name="caisse-paiements-recents"),
    path("caisse/historique-recent/", views.HistoriqueRecentView.as_view(), name="caisse-historique-recent"),

    # Admin
    path("admin/statistiques/", views.StatistiquesAdminView.as_view(), name="admin-statistiques"),
    path("admin/caisse/", views.EtatCaisseView.as_view(), name="admin-caisse",),
]
