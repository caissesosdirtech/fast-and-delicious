from rest_framework.permissions import BasePermission


class IsRole(BasePermission):
    """Autorise uniquement les utilisateurs ayant l'un des rôles listés dans `allowed_roles`.

    Usage : ajouter `allowed_roles = ["caissiere", "admin"]` sur la vue.
    """

    allowed_roles = None  # peut être redéfini sur une sous-classe ou sur la vue (view.allowed_roles)

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        allowed_roles = self.allowed_roles or getattr(view, "allowed_roles", None)
        if not allowed_roles:
            return True
        return request.user.role in allowed_roles


class EstAdminCompte(IsRole):
    allowed_roles = ["admin"]
