from rest_framework.routers import DefaultRouter

from .views import CategorieViewSet, PlatViewSet

router = DefaultRouter()
router.register("categories", CategorieViewSet, basename="categorie")
router.register("plats", PlatViewSet, basename="plat")

urlpatterns = router.urls
