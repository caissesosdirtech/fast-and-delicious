from django.contrib.auth import get_user_model
from rest_framework import serializers

Utilisateur = get_user_model()


class UtilisateurSerializer(serializers.ModelSerializer):
    class Meta:
        model = Utilisateur
        fields = ["id", "username", "first_name", "last_name", "role"]
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
