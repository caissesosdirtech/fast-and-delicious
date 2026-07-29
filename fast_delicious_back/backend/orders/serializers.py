from rest_framework import serializers

from menu.models import GroupeChoix, OptionAccompagnement, OptionChoix, Plat

from .models import Commande, LigneCommande, SelectionChoix


class SelectionEcritureSerializer(serializers.Serializer):
    """Une sélection envoyée par le client pour un groupe de choix donné."""

    groupe_id = serializers.PrimaryKeyRelatedField(queryset=GroupeChoix.objects.all(), source="groupe")
    option_id = serializers.PrimaryKeyRelatedField(queryset=OptionChoix.objects.all(), source="option")


class LigneCommandeEcritureSerializer(serializers.Serializer):
    """Utilisé uniquement pour la création d'une commande par le client."""

    plat_id = serializers.PrimaryKeyRelatedField(queryset=Plat.objects.all(), source="plat")
    quantite = serializers.IntegerField(min_value=1)
    accompagnement_id = serializers.PrimaryKeyRelatedField(
        queryset=OptionAccompagnement.objects.all(), source="accompagnement",
        required=False, allow_null=True,
    )
    selections = SelectionEcritureSerializer(many=True, required=False)

    def validate(self, data):
        plat = data["plat"]
        accompagnement = data.get("accompagnement")
        selections = data.get("selections") or []

        # Système simple : un seul accompagnement optionnel/obligatoire directement sur le plat.
        if plat.accompagnement_obligatoire and not accompagnement:
            raise serializers.ValidationError(
                f"Merci de choisir un accompagnement pour « {plat.nom} »."
            )
        if accompagnement and not plat.accompagnements.filter(pk=accompagnement.pk).exists():
            raise serializers.ValidationError(
                f"Cet accompagnement n'est pas proposé pour « {plat.nom} »."
            )

        # Système des formules composées (plusieurs groupes de choix).
        groupes_du_plat = list(plat.groupes_choix.all())
        if groupes_du_plat:
            selection_par_groupe = {s["groupe"].id: s["option"] for s in selections}
            for groupe in groupes_du_plat:
                option_choisie = selection_par_groupe.get(groupe.id)
                if groupe.obligatoire and option_choisie is None:
                    raise serializers.ValidationError(
                        f"Merci de choisir une option pour « {groupe.nom} » ({plat.nom})."
                    )
                if option_choisie and option_choisie.groupe_id != groupe.id:
                    raise serializers.ValidationError(
                        f"Sélection invalide pour « {groupe.nom} »."
                    )

        return data


class SelectionLectureSerializer(serializers.ModelSerializer):
    groupe_nom = serializers.CharField(source="groupe.nom", read_only=True)
    option_nom = serializers.CharField(source="option.nom", read_only=True)

    class Meta:
        model = SelectionChoix
        fields = ["groupe_nom", "option_nom"]


class LigneCommandeSerializer(serializers.ModelSerializer):
    plat_nom = serializers.CharField(source="plat.nom", read_only=True)
    prix_unitaire = serializers.DecimalField(source="plat.prix", max_digits=8, decimal_places=2, read_only=True)
    sous_total = serializers.DecimalField(max_digits=8, decimal_places=2, read_only=True)
    accompagnement_nom = serializers.CharField(source="accompagnement.nom", read_only=True, default=None)
    selections = SelectionLectureSerializer(many=True, read_only=True)

    class Meta:
        model = LigneCommande
        fields = [
            "id", "plat", "plat_nom", "quantite", "prix_unitaire",
            "sous_total", "accompagnement_nom", "selections",
        ]


class CommandeSerializer(serializers.ModelSerializer):
    lignes = LigneCommandeSerializer(many=True, read_only=True)
    total = serializers.DecimalField(max_digits=8, decimal_places=2, read_only=True)
    temps_restant_estime_min = serializers.IntegerField(read_only=True)

    class Meta:
        model = Commande
        fields = [
            "id", "client", "numero_table", "statut",
            "date_creation", "date_validation", "date_debut_preparation",
            "date_prete", "date_servie",
            "lignes", "total", "temps_restant_estime_min",
        ]
        read_only_fields = [
            "statut", "date_creation", "date_validation",
            "date_debut_preparation", "date_prete", "date_servie",
        ]


class CommandeCreationSerializer(serializers.ModelSerializer):
    """POST — le client envoie son numéro de table et la liste des lignes."""

    lignes = LigneCommandeEcritureSerializer(many=True)

    class Meta:
        model = Commande
        fields = ["id", "numero_table", "lignes"]

    def validate_lignes(self, value):
        if not value:
            raise serializers.ValidationError("La commande doit contenir au moins un article.")
        return value

    def create(self, validated_data):
        lignes_data = validated_data.pop("lignes")
        request = self.context["request"]
        client = request.user if request.user.is_authenticated else None

        commande = Commande.objects.create(client=client, **validated_data)
        for ligne_data in lignes_data:
            selections_data = ligne_data.pop("selections", [])
            ligne = LigneCommande.objects.create(commande=commande, **ligne_data)
            for selection in selections_data:
                SelectionChoix.objects.create(
                    ligne=ligne, groupe=selection["groupe"], option=selection["option"],
                )
        commande.enregistrer_historique()
        return commande
