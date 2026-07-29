from django.urls import path

from .views import InscriptionClientView, MonProfilView

urlpatterns = [
    path("inscription/", InscriptionClientView.as_view(), name="inscription-client"),
    path("moi/", MonProfilView.as_view(), name="mon-profil"),
]
