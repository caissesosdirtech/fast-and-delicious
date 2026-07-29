from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import ChangerMotDePasseView, EmployeViewSet, InscriptionClientView, MonProfilView

router = DefaultRouter()
router.register("employes", EmployeViewSet, basename="employe")

urlpatterns = [
    path("inscription/", InscriptionClientView.as_view(), name="inscription-client"),
    path("moi/", MonProfilView.as_view(), name="mon-profil"),
    path("changer-mot-de-passe/", ChangerMotDePasseView.as_view(), name="changer-mot-de-passe"),
    path("", include(router.urls)),
]
