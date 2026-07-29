import random

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.utils import timezone

from menu.models import Plat
from orders.models import Commande, LigneCommande

Utilisateur = get_user_model()


class Command(BaseCommand):
    help = "Génère des commandes de test à différents statuts, pour peupler le tableau de bord admin."

    def add_arguments(self, parser):
        parser.add_argument(
            "--nombre", type=int, default=12,
            help="Nombre de commandes à générer (défaut : 12)",
        )

    def handle(self, *args, **options):
        plats = list(Plat.objects.filter(disponible=True))
        if not plats:
            self.stdout.write(self.style.ERROR(
                "Aucun plat en base. Lance d'abord `python manage.py seed_demo`."
            ))
            return

        caissiere = Utilisateur.objects.filter(role=Utilisateur.Role.CAISSIERE).first()
        cuisinier = Utilisateur.objects.filter(role=Utilisateur.Role.CUISINE).first()

        nombre = options["nombre"]
        # Répartition volontairement variée pour bien voir tous les blocs du dashboard.
        statuts_cibles = (
            ["EN_ATTENTE"] * 2
            + ["VALIDEE"] * 2
            + ["EN_PREPARATION"] * 2
            + ["PRETE"] * 2
            + ["SERVIE"] * max(nombre - 8, 2)
        )
        random.shuffle(statuts_cibles)

        maintenant = timezone.now()
        crees = 0

        for statut_cible in statuts_cibles[:nombre]:
            commande = Commande.objects.create(
                numero_table=f"Stand {random.randint(1, 4)}",
                statut="EN_ATTENTE",
            )
            for plat in random.sample(plats, k=random.randint(1, 3)):
                LigneCommande.objects.create(
                    commande=commande, plat=plat, quantite=random.randint(1, 3)
                )
            commande.enregistrer_historique()

            # Fait avancer la commande jusqu'au statut visé, avec des horodatages décalés.
            if statut_cible in ["VALIDEE", "EN_PREPARATION", "PRETE", "SERVIE"]:
                commande.statut = "VALIDEE"
                commande.date_validation = maintenant - timezone.timedelta(minutes=random.randint(2, 25))
                commande.caissiere = caissiere
                commande.save()
                commande.enregistrer_historique()

            if statut_cible in ["EN_PREPARATION", "PRETE", "SERVIE"]:
                commande.statut = "EN_PREPARATION"
                commande.date_debut_preparation = commande.date_validation + timezone.timedelta(minutes=1)
                commande.cuisinier = cuisinier
                commande.save()
                commande.enregistrer_historique()

            if statut_cible in ["PRETE", "SERVIE"]:
                commande.statut = "PRETE"
                commande.date_prete = commande.date_debut_preparation + timezone.timedelta(minutes=random.randint(5, 12))
                commande.save()
                commande.enregistrer_historique()

            if statut_cible == "SERVIE":
                commande.statut = "SERVIE"
                commande.date_servie = commande.date_prete + timezone.timedelta(minutes=random.randint(1, 5))
                commande.save()
                commande.enregistrer_historique()

            crees += 1

        self.stdout.write(self.style.SUCCESS(f"{crees} commandes de test créées."))
