from django.db import models


class Categorie(models.Model):
    nom = models.CharField(max_length=100)
    ordre = models.PositiveIntegerField(default=0, help_text="Ordre d'affichage dans le menu")

    class Meta:
        ordering = ["ordre", "nom"]

    def __str__(self):
        return self.nom


class OptionAccompagnement(models.Model):
    """Un choix d'accompagnement réutilisable (ex : Alloco, Patates frites...)."""

    nom = models.CharField(max_length=100, unique=True)

    class Meta:
        ordering = ["nom"]

    def __str__(self):
        return self.nom


class Plat(models.Model):
    categorie = models.ForeignKey(Categorie, related_name="plats", on_delete=models.CASCADE)
    nom = models.CharField(max_length=150)
    description = models.CharField(max_length=255, blank=True)
    prix = models.DecimalField(max_digits=8, decimal_places=2, help_text="Prix en FCFA")
    temps_preparation_min = models.PositiveIntegerField(
        default=8, help_text="Temps de préparation moyen, en minutes"
    )
    disponible = models.BooleanField(default=True)
    image = models.ImageField(upload_to="plats/", blank=True, null=True)

    accompagnements = models.ManyToManyField(
        OptionAccompagnement, blank=True, related_name="plats",
        help_text="Accompagnements proposés au client pour ce plat (laisser vide si aucun).",
    )
    accompagnement_obligatoire = models.BooleanField(
        default=False,
        help_text="Le client doit choisir un accompagnement avant de pouvoir ajouter ce plat au panier.",
    )

    class Meta:
        ordering = ["categorie__ordre", "nom"]

    def __str__(self):
        return f"{self.nom} ({self.prix} F)"


class GroupeChoix(models.Model):
    """Un groupe de choix pour un plat composé (ex : 'Grillade au choix', 'Accompagnement', 'Crudité').
    Utilisé pour les formules (comme la Formule complète) où le client doit sélectionner
    une option dans plusieurs groupes différents pour composer son repas.
    """

    plat = models.ForeignKey(Plat, related_name="groupes_choix", on_delete=models.CASCADE)
    nom = models.CharField(max_length=100, help_text="Ex : 'Grillade au choix', 'Accompagnement', 'Crudité'")
    obligatoire = models.BooleanField(default=True)
    ordre = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ["ordre", "id"]

    def __str__(self):
        return f"{self.plat.nom} — {self.nom}"


class OptionChoix(models.Model):
    """Une option sélectionnable au sein d'un groupe de choix (ex : 'Brochette Poulet Ananas' dans 'Grillade au choix')."""

    groupe = models.ForeignKey(GroupeChoix, related_name="options", on_delete=models.CASCADE)
    nom = models.CharField(max_length=150)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return self.nom
