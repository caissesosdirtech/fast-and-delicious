from accounts.permissions import IsRole
from accounts.models import Utilisateur


class EstCaissiere(IsRole):
    allowed_roles = [Utilisateur.Role.CAISSIERE, Utilisateur.Role.ADMIN]


class EstCuisinier(IsRole):
    allowed_roles = [Utilisateur.Role.CUISINE, Utilisateur.Role.ADMIN]


class EstAdmin(IsRole):
    allowed_roles = [Utilisateur.Role.ADMIN]
