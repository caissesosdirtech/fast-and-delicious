# Fast & Delicious — Backend Django

API REST + WebSocket (Django Channels) pour la gestion des commandes du stand.

## Installation

```bash
python -m venv venv
source venv/bin/activate          # Windows : venv\Scripts\activate
pip install -r requirements.txt

python manage.py migrate
python manage.py seed_demo        # crée les comptes de démo + le menu réel
python manage.py createsuperuser  # optionnel si vous ne voulez pas des comptes de démo

python manage.py runserver
```

L'API est alors disponible sur `http://127.0.0.1:8000/`.

## Comptes de démonstration (créés par `seed_demo`)

| Rôle       | Identifiant | Mot de passe |
|------------|-------------|--------------|
| Admin      | admin       | admin123     |
| Caissière  | caissiere1  | caisse123    |
| Cuisinier  | cuisinier1  | cuisine123   |
| Client     | client1     | client123    |

## Authentification

JWT via `djangorestframework-simplejwt`.

```
POST /api/auth/token/            {"username": "...", "password": "..."}   → {access, refresh}
POST /api/auth/token/refresh/    {"refresh": "..."}                       → {access}
```

Envoyer ensuite `Authorization: Bearer <access>` sur les endpoints protégés.
La création de commande et la consultation du suivi client sont **publiques** (pas besoin de compte) :
en fast-food de kermesse, le client passe rarement par une inscription.

## Endpoints principaux

| Endpoint | Méthode | Accès | Description |
|---|---|---|---|
| `/api/menu/categories/` | GET | public | Menu complet, catégories + plats |
| `/api/commandes/` | POST | public | Créer une commande |
| `/api/commandes/<id>/` | GET | public | Détail + statut + temps restant (écran de suivi) |
| `/api/commandes/<id>/servie/` | PATCH | authentifié | Clôturer la commande |
| `/api/caisse/commandes/` | GET | caissière/admin | File d'attente à valider |
| `/api/caisse/commandes/<id>/valider/` | PATCH | caissière/admin | Valider + envoyer en cuisine |
| `/api/cuisine/commandes/` | GET | cuisinier/admin | File de préparation |
| `/api/cuisine/commandes/<id>/preparer/` | PATCH | cuisinier/admin | Démarrer la préparation |
| `/api/cuisine/commandes/<id>/prete/` | PATCH | cuisinier/admin | Marquer comme prête |
| `/api/comptes/inscription/` | POST | public | Créer un compte client (optionnel) |
| `/api/comptes/moi/` | GET | authentifié | Profil + rôle de l'utilisateur connecté |

## Temps réel (WebSocket)

| URL | Qui s'y connecte | Reçoit |
|---|---|---|
| `ws://.../ws/commande/<id>/` | Écran de suivi client | `{statut, temps_restant_estime_min}` à chaque changement |
| `ws://.../ws/caisse/` | Dashboard caissière | Notification à chaque nouvelle commande |
| `ws://.../ws/cuisine/` | Dashboard cuisine | Notification à chaque commande validée |

En développement, la couche de communication (`CHANNEL_LAYERS`) utilise `InMemoryChannelLayer`
(un seul process). **Pour la production ou plusieurs workers, passer à Redis** :

```bash
pip install channels-redis
```

```python
# settings.py
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {"hosts": [("127.0.0.1", 6379)]},
    }
}
```

Et lancer le serveur avec un serveur ASGI (Daphne ou Uvicorn) plutôt que `runserver` :

```bash
pip install daphne
daphne fast_delicious.asgi:application
```

## Machine à états d'une commande

```
EN_ATTENTE → VALIDEE → EN_PREPARATION → PRETE → SERVIE
                                       ↘ ANNULEE
```

Chaque transition est enregistrée dans `HistoriqueStatut` et déclenche une notification
temps réel vers les groupes concernés (`realtime/utils.py`).

## Prochaines étapes suggérées

- Frontend React (menu, suivi, dashboards caissière/cuisine) branché sur cette API
- Endpoint d'annulation de commande
- Affinage du temps restant estimé selon la charge réelle de la cuisine (moyenne glissante)
- Passage à PostgreSQL + Redis pour la mise en production
