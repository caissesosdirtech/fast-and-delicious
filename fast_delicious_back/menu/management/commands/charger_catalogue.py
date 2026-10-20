"""Charge en une commande les plats du catalogue JOJ dans les 4 catégories.

Équivalent d'un `loaddata`, mais sûr : au lieu d'exiger les identifiants internes des
catégories (qu'un fixture brut impose), cette commande retrouve TES catégories existantes
par leur nom et ne crée que les plats manquants.

- Idempotente : on peut la relancer sans créer de doublon (un plat déjà présent est ignoré).
- Ne modifie pas les plats que tu as déjà créés/édités (ni leur prix, ni leur description).
- Les photos s'affichent automatiquement côté front (associées par nom), aucun upload requis.

Lancer :  python manage.py charger_catalogue
"""

import unicodedata
from decimal import Decimal

from django.core.management.base import BaseCommand

from menu.models import Categorie, Plat


def _norm(texte):
    """minuscules, sans accents, espaces simples — pour comparer des noms de façon souple."""
    t = unicodedata.normalize("NFD", (texte or "").lower())
    t = "".join(c for c in t if unicodedata.category(c) != "Mn")
    return " ".join(t.split())


# (nom de catégorie, ordre d'affichage, [ (nom du plat, prix FCFA, description) ... ])
CATALOGUE = [
    # Vitrine spéciale "Nos formules" (affichée en haut du menu, affiches toutes faites).
    ("Formules", 0, [
        ("Formule 1 — Doukouré", 2000, "Pain haricots + jus local"),
        ("Formule 2 — Diaytaar", 3200, "Hot dog + frites + soda"),
        ("Formule 3 — Beuri Maana", 3300, "Nuggets + frites + jus"),
    ]),
    ("Fast Food & Snacks", 1, [
        ("Wrap poulet", 3000, "Chicken wrap · 300 g"),
        ("Chicken tenders", 2000, "Filets de poulet panés (5 à 6 pièces) · 200 g"),
        ("Hot dog", 1500, "Saucisse volaille ou bœuf, moutarde, ketchup · 200 g"),
        ("Green Teranga Fataya", 1000, "Vegetarian pie · 150 g · 2 à 3 pièces"),
        ("Pain haricots", 500, "Black beans sandwich · 250 g"),
        ("Pain thon", 500, "Tuna sandwich · 220 g"),
        ("Donuts bissap / bouye / ditakh", 1000, "Hibiscus · Baobab fruit · 100 g"),
    ]),
    ("Crêpes", 2, [
        ("Crêpe jambon fromage", 2000, "Cheese and beef ham crepe · 220 g"),
        ("Crêpe Nutella — El Mordjene", 1000, "150 g"),
    ]),
    ("Grillades", 3, [
        # Vide pour le moment (aucune grillade dans le catalogue JOJ fourni).
    ]),
    ("Boissons / Jus naturel", 4, [
        # Jus naturels en canette, un par parfum (25 cl) — 600 F chacun.
        ("Jus Bissap", 600, "Hibiscus · 25 cl"),
        ("Jus Bouyé", 600, "Pain de singe (baobab) · 25 cl"),
        ("Jus Maad", 600, "Saba senegalensis · 25 cl"),
        ("Jus Ditakh", 600, "Détar (ditakh) · 25 cl"),
        ("Jus Gingembre", 600, "Gingembre frais · 25 cl"),
        ("Jus Citron", 600, "Citron pressé · 25 cl"),
        ("Café Touba", 300, "Au poivre de Sélim (djar) et clou de girofle · 20 cl"),
        ("Thé à la menthe", 300, "Mint tea · 20 cl"),
        ("Thé bissap", 300, "Hibiscus & menthe · 20 cl"),
        ("Fanta, Coca, Sprite", 1000, "33 cl"),
    ]),
]


class Command(BaseCommand):
    help = "Charge les plats du catalogue JOJ dans les catégories existantes (sans doublon)."

    def handle(self, *args, **options):
        # Index des catégories déjà en base, par nom normalisé (évite d'en recréer une en double).
        existantes = {_norm(c.nom): c for c in Categorie.objects.all()}

        crees = 0
        ignores = 0
        for cat_nom, ordre, plats in CATALOGUE:
            cat = existantes.get(_norm(cat_nom))
            if cat is None:
                cat = Categorie.objects.create(nom=cat_nom, ordre=ordre)
                existantes[_norm(cat_nom)] = cat
                self.stdout.write(self.style.WARNING(f"Catégorie créée : {cat_nom}"))
            else:
                self.stdout.write(f"Catégorie trouvée : {cat.nom}")

            for nom, prix, description in plats:
                deja = Plat.objects.filter(categorie=cat, nom__iexact=nom).first()
                if deja:
                    ignores += 1
                    self.stdout.write(f"  — déjà présent, ignoré : {nom}")
                    continue
                Plat.objects.create(
                    categorie=cat,
                    nom=nom,
                    prix=Decimal(prix),
                    description=description,
                    disponible=True,
                )
                crees += 1
                self.stdout.write(self.style.SUCCESS(f"  + plat créé : {nom} ({prix} F)"))

        self.stdout.write(self.style.SUCCESS(
            f"\nTerminé : {crees} plat(s) créé(s), {ignores} déjà présent(s) et laissé(s) intact(s)."
        ))
