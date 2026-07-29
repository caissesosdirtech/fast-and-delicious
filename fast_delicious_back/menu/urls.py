from rest_framework.routers import DefaultRouter

from .views import CategorieViewSet, LieuViewSet, PlatViewSet, TableRestaurantViewSet

router = DefaultRouter()
router.register("categories", CategorieViewSet, basename="categorie")
router.register("plats", PlatViewSet, basename="plat")
router.register("tables", TableRestaurantViewSet, basename="table")
router.register("lieux", LieuViewSet, basename="lieu")

urlpatterns = router.urls
