from django.contrib.auth.models import AbstractUser
from django.db import models


class Utilisateur(AbstractUser):
    """Utilisateur avec un rôle métier : client, caissière, cuisinier ou admin."""

    class Role(models.TextChoices):
        CLIENT = "client", "Client"
        CAISSIERE = "caissiere", "Caissière"
        CUISINE = "cuisine", "Cuisinier"
        ADMIN = "admin", "Administrateur"

    role = models.CharField(max_length=20, choices=Role.choices, default=Role.CLIENT)

    def __str__(self):
        return f"{self.username} ({self.get_role_display()})"
