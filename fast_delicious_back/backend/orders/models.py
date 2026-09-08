from django.conf import settings
from django.db import models
from django.utils import timezone

from menu.models import Plat


```python
class Commande(models.Model):
    class Statut(models.TextChoices):
        EN_ATTENTE = "EN_ATTENTE", "En attente"
        VALIDEE = "VALIDEE", "Validée"
        EN_PREPARATION = "EN_PREPARATION", "En préparation"
        PRETE = "PRETE", "Prête"
        SERVIE = "SERVIE", "Servie"
        ANNULEE = "ANNULEE", "Annulée"


    client = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        related_name="commandes",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )

    # Lieu où la commande a été passée
    lieu = models.ForeignKey(
        "menu.Lieu",
        related_name="commandes",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )

    numero_table = models.CharField(
        max_length=10,
        blank=True,
    )

    statut = models.CharField(
        max_length=20,
        choices=Statut.choices,
        default=Statut.EN_ATTENTE,
    )

    date_creation = models.DateTimeField(auto_now_add=True)
    date_validation = models.DateTimeField(null=True, blank=True)
    date_debut_preparation = models.DateTimeField(null=True, blank=True)
    date_prete = models.DateTimeField(null=True, blank=True)
    date_servie = models.DateTimeField(null=True, blank=True)

    caissiere = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        related_name="commandes_encaissees",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )

    cuisinier = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        related_name="commandes_preparees",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
    )

    class Meta:
        ordering = ["date_creation"]

    def __str__(self):
        return f"Commande #{self.id} — {self.statut}"

    @property
    def total(self):
        return sum(
            ligne.sous_total
            for ligne in self.lignes.all()
        )

    @property
    def temps_total_estime_min(self):
        """
        Temps de préparation théorique total
        (somme des plats), sans tenir compte
        de la charge cuisine.
        """
        return sum(
            l.plat.temps_preparation_min * l.quantite
            for l in self.lignes.all()
        )

    @property
    def temps_restant_estime_min(self):
        """
        Temps restant estimé à partir du début
        de préparation.

        Si la préparation n'a pas commencé,
        renvoie le temps total théorique.
        """
        if self.statut in [
            self.Statut.PRETE,
            self.Statut.SERVIE,
            self.Statut.ANNULEE,
        ]:
            return 0

        if not self.date_debut_preparation:
            return self.temps_total_estime_min

        ecoule_min = (
            timezone.now() - self.date_debut_preparation
        ).total_seconds() / 60

        return max(
            0,
            round(
                self.temps_total_estime_min - ecoule_min
            )
        )

    def enregistrer_historique(self):
        HistoriqueStatut.objects.create(
            commande=self,
            statut=self.statut,
        )


class LigneCommande(models.Model):
    commande = models.ForeignKey(Commande, related_name="lignes", on_delete=models.CASCADE)
    plat = models.ForeignKey(Plat, on_delete=models.PROTECT)
    quantite = models.PositiveIntegerField(default=1)
    accompagnement = models.ForeignKey(
        "menu.OptionAccompagnement", null=True, blank=True, on_delete=models.SET_NULL,
        help_text="Accompagnement choisi par le client pour cette ligne, si applicable.",
    )

    @property
    def sous_total(self):
        return self.plat.prix * self.quantite

    def __str__(self):
        base = f"{self.quantite}x {self.plat.nom}"
        return f"{base} ({self.accompagnement.nom})" if self.accompagnement else base


class SelectionChoix(models.Model):
    """Une sélection faite par le client dans un groupe de choix, pour une ligne de commande donnée
    (ex : pour la Formule complète, une ligne aura 3 sélections : Grillade, Accompagnement, Crudité).
    """

    ligne = models.ForeignKey(LigneCommande, related_name="selections", on_delete=models.CASCADE)
    groupe = models.ForeignKey("menu.GroupeChoix", on_delete=models.PROTECT)
    option = models.ForeignKey("menu.OptionChoix", on_delete=models.PROTECT)

    def __str__(self):
        return f"{self.groupe.nom} : {self.option.nom}"


class HistoriqueStatut(models.Model):
    commande = models.ForeignKey(Commande, related_name="historique", on_delete=models.CASCADE)
    statut = models.CharField(max_length=20)
    date = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["date"]
