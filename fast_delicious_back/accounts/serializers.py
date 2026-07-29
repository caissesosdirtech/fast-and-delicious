from django.contrib.auth import get_user_model
from rest_framework import serializers

Utilisateur = get_user_model()


class UtilisateurSerializer(serializers.ModelSerializer):
    lieu_nom = serializers.CharField(source="lieu.nom", read_only=True, default=None)

    class Meta:
        model = Utilisateur
        fields = ["id", "username", "first_name", "last_name", "role", "lieu", "lieu_nom"]
        read_only_fields = ["id", "role"]


class InscriptionClientSerializer(serializers.ModelSerializer):
    """Inscription simplifiée pour un client (rôle forcé à 'client')."""

    password = serializers.CharField(write_only=True, min_length=6)

    class Meta:
        model = Utilisateur
        fields = ["id", "username", "first_name", "last_name", "password"]

    def create(self, validated_data):
        password = validated_data.pop("password")
        user = Utilisateur(**validated_data, role=Utilisateur.Role.CLIENT)
        user.set_password(password)
        user.save()
        return user


class EmployeSerializer(serializers.ModelSerializer):
    """Gestion des comptes staff (caissière, cuisine, livreur, admin) — pas les clients."""

    password = serializers.CharField(write_only=True, required=False, allow_blank=True, min_length=6)
    lieu_nom = serializers.CharField(source="lieu.nom", read_only=True, default=None)

    class Meta:
        model = Utilisateur
        fields = ["id", "username", "role", "is_active", "password", "lieu", "lieu_nom"]

    def validate_role(self, value):
        if value == Utilisateur.Role.CLIENT:
            raise serializers.ValidationError("Ce formulaire gère le personnel, pas les comptes clients.")
        return value

    def create(self, validated_data):
        password = validated_data.pop("password", None)
        user = Utilisateur(**validated_data)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save()
        return user

    def update(self, instance, validated_data):
        password = validated_data.pop("password", None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        if password:
            instance.set_password(password)
        instance.save()
        return instance
