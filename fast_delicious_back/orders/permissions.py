from accounts.permissions import IsRole
from accounts.models import Utilisateur


class EstCaissiere(IsRole):
    allowed_roles = [Utilisateur.Role.CAISSIERE, Utilisateur.Role.ADMIN]


class EstCuisinier(IsRole):
    allowed_roles = [Utilisateur.Role.CUISINE, Utilisateur.Role.ADMIN]


class EstAdmin(IsRole):
    allowed_roles = [Utilisateur.Role.ADMIN]


class EstLivreur(IsRole):
    allowed_roles = [Utilisateur.Role.LIVREUR, Utilisateur.Role.ADMIN]


class EstPersonnelInterne(IsRole):
    """Tout membre du staff (caissière, cuisinier, livreur, admin) — utilisé pour les
    statistiques globales en lecture seule, affichées en KPI sur chaque tableau de bord."""
    allowed_roles = [
        Utilisateur.Role.CAISSIERE, Utilisateur.Role.CUISINE,
        Utilisateur.Role.LIVREUR, Utilisateur.Role.ADMIN,
    ]
