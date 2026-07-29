from rest_framework import serializers

from .models import Categorie, GroupeChoix, OptionAccompagnement, OptionChoix, Plat


class OptionAccompagnementSerializer(serializers.ModelSerializer):
    class Meta:
        model = OptionAccompagnement
        fields = ["id", "nom"]


class OptionChoixSerializer(serializers.ModelSerializer):
    class Meta:
        model = OptionChoix
        fields = ["id", "nom"]


class GroupeChoixSerializer(serializers.ModelSerializer):
    options = OptionChoixSerializer(many=True, read_only=True)

    class Meta:
        model = GroupeChoix
        fields = ["id", "nom", "obligatoire", "ordre", "options"]


class PlatSerializer(serializers.ModelSerializer):
    accompagnements = OptionAccompagnementSerializer(many=True, read_only=True)
    groupes_choix = GroupeChoixSerializer(many=True, read_only=True)

    class Meta:
        model = Plat
        fields = [
            "id", "nom", "description", "prix",
            "temps_preparation_min", "disponible", "image", "categorie",
            "accompagnements", "accompagnement_obligatoire", "groupes_choix",
        ]


class CategorieSerializer(serializers.ModelSerializer):
    plats = PlatSerializer(many=True, read_only=True)

    class Meta:
        model = Categorie
        fields = ["id", "nom", "ordre", "plats"]
