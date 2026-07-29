from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand

from menu.models import Categorie, GroupeChoix, OptionAccompagnement, OptionChoix, Plat

Utilisateur = get_user_model()


class Command(BaseCommand):
    help = "Crée des comptes de démonstration (un par rôle) et le menu Fast & Delicious."

    def handle(self, *args, **options):
        # Comptes de démo
        comptes = [
            ("admin", "admin123", Utilisateur.Role.ADMIN, True),
            ("caissiere1", "caisse123", Utilisateur.Role.CAISSIERE, False),
            ("cuisinier1", "cuisine123", Utilisateur.Role.CUISINE, False),
            ("client1", "client123", Utilisateur.Role.CLIENT, False),
        ]
        for username, password, role, is_super in comptes:
            if not Utilisateur.objects.filter(username=username).exists():
                if is_super:
                    user = Utilisateur.objects.create_superuser(username, password=password)
                else:
                    user = Utilisateur(username=username)
                    user.set_password(password)
                    user.save()
                user.role = role
                user.save()
                self.stdout.write(self.style.SUCCESS(f"Compte créé : {username} / {password} ({role})"))

        # Menu
        categories = {
            "Fast Food & Snacks": [
                ("Tortilla Poulet Fumé", 2500, 6),
                ("Tortilla Jambon", 2000, 5),
                ("Corn Dog / Hot Dog", 1500, 5),
                ("Chicken Pop Corn", 2000, 6),
                ("Finger (Poulet pané)", 2000, 7),
            ],
            "Crêpes": [
                ("Crêpe Nutella", 1000, 4),
                ("Crêpe El Mordjene", 1000, 4),
                ("Crêpe Nestlé", 1000, 4),
                ("Churros", 1000, 4),
                ("Crêpe Jambon Fromage", 2500, 5),
                ("Crêpe Poulet Fumé", 2500, 6),
            ],
            "Grillades": [
                ("Brochette Poulet Ananas", 2000, 10),
                ("Brochette Bœuf Chili BBQ", 2000, 10),
                ("Poulet Fumé (portion)", 3000, 15),
                ("Maïs doux grillé", 1000, 8),
                ("Formule complète", 4000, 15),
            ],
            "Boissons": [
                ("Jus naturel", 500, 1),
                ("Soda", 500, 1),
                ("Eau", 500, 1),
            ],
        }

        for ordre, (nom_cat, plats) in enumerate(categories.items()):
            categorie, _ = Categorie.objects.get_or_create(nom=nom_cat, defaults={"ordre": ordre})
            for nom_plat, prix, temps in plats:
                Plat.objects.get_or_create(
                    nom=nom_plat, categorie=categorie,
                    defaults={"prix": prix, "temps_preparation_min": temps},
                )

        # Options d'accompagnement (réutilisables sur les grillades à la pièce)
        noms_accompagnements = ["Athiekke", "Crudités", "Alloco", "Patates frites", "Pomme de terre frites"]
        accompagnements = []
        for nom in noms_accompagnements:
            option, _ = OptionAccompagnement.objects.get_or_create(nom=nom)
            accompagnements.append(option)

        # Les grillades à la pièce proposent un accompagnement en option (facultatif).
        for nom_plat in ["Brochette Poulet Ananas", "Brochette Bœuf Chili BBQ", "Poulet Fumé (portion)"]:
            plat = Plat.objects.filter(nom=nom_plat).first()
            if plat:
                plat.accompagnements.set(accompagnements)
                plat.save()

        # La Formule complète est une formule composée : 3 groupes de choix obligatoires.
        formule = Plat.objects.filter(nom="Formule complète").first()
        if formule and not formule.groupes_choix.exists():
            grillades_disponibles = [
                "Brochette Poulet Ananas", "Brochette Bœuf Chili BBQ", "Poulet Fumé (portion)",
            ]
            crudites_disponibles = ["Crudités"]
            accompagnements_disponibles = ["Alloco", "Patates frites", "Athiekke", "Pomme de terre frites"]

            groupe_grillade = GroupeChoix.objects.create(
                plat=formule, nom="Grillade au choix", obligatoire=True, ordre=1,
            )
            for nom in grillades_disponibles:
                OptionChoix.objects.create(groupe=groupe_grillade, nom=nom)

            groupe_accompagnement = GroupeChoix.objects.create(
                plat=formule, nom="Accompagnement", obligatoire=True, ordre=2,
            )
            for nom in accompagnements_disponibles:
                OptionChoix.objects.create(groupe=groupe_accompagnement, nom=nom)

            groupe_crudite = GroupeChoix.objects.create(
                plat=formule, nom="Crudité", obligatoire=True, ordre=3,
            )
            for nom in crudites_disponibles:
                OptionChoix.objects.create(groupe=groupe_crudite, nom=nom)

        self.stdout.write(self.style.SUCCESS("Menu Fast & Delicious chargé."))
