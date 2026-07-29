from django.contrib.auth.models import AbstractUser
from django.db import models


class Utilisateur(AbstractUser):
    """Utilisateur avec un rôle métier : client, caissière, cuisinier, livreur ou admin."""

    class Role(models.TextChoices):
        CLIENT = "client", "Client"
        CAISSIERE = "caissiere", "Caissière"
        CUISINE = "cuisine", "Cuisinier"
        LIVREUR = "livreur", "Livreur"
        ADMIN = "admin", "Administrateur"

    role = models.CharField(max_length=20, choices=Role.choices, default=Role.CLIENT)
    lieu = models.ForeignKey(
        "menu.Lieu", related_name="personnel", on_delete=models.SET_NULL, null=True, blank=True,
        help_text="Site/événement auquel ce membre du staff est affecté (laisser vide si un seul événement).",
    )

    def __str__(self):
        return f"{self.username} ({self.get_role_display()})"
