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
    lieu_nom = serializers.CharField(source="lieu.nom", read_only=True, default=None)

    class Meta:
        model = Commande
        fields = [
            "id", "client", "numero_table", "statut", "remarque", "motif_annulation",
            "mode_commande", "adresse_livraison", "telephone_client",
            "mode_paiement", "reference_paiement", "paiement_confirme",
            "lieu", "lieu_nom",
            "date_creation", "date_validation", "date_debut_preparation",
            "date_prete", "date_debut_livraison", "date_servie",
            "lignes", "total", "temps_restant_estime_min",
        ]
        read_only_fields = [
            "statut", "date_creation", "date_validation",
            "date_debut_preparation", "date_prete", "date_debut_livraison", "date_servie",
        ]


class CommandeCreationSerializer(serializers.ModelSerializer):
    """POST — le client envoie son numéro de table (ou son adresse) et la liste des lignes."""

    lignes = LigneCommandeEcritureSerializer(many=True)

    class Meta:
        model = Commande
        fields = [
            "id", "numero_table", "remarque", "mode_commande", "adresse_livraison", "telephone_client",
            "mode_paiement", "reference_paiement", "lieu", "lignes",
        ]

    def validate_lignes(self, value):
        if not value:
            raise serializers.ValidationError("La commande doit contenir au moins un article.")
        return value

    def validate(self, data):
        if data.get("mode_commande") == Commande.ModeCommande.LIVRAISON:
            if not data.get("adresse_livraison", "").strip():
                raise serializers.ValidationError(
                    {"adresse_livraison": "L'adresse de livraison est obligatoire pour une livraison."}
                )
            if not data.get("telephone_client", "").strip():
                raise serializers.ValidationError(
                    {"telephone_client": "Un numéro de téléphone est obligatoire pour une livraison."}
                )

        mode_paiement = data.get("mode_paiement", Commande.ModePaiement.ESPECES)
        reference = data.get("reference_paiement", "").strip()
        if mode_paiement != Commande.ModePaiement.ESPECES:
            if not reference:
                raise serializers.ValidationError(
                    {"reference_paiement": "Merci d'indiquer la référence de ta transaction Wave/Orange Money."}
                )
            # Anti-fraude : une référence de transaction ne peut être utilisée que par une seule
            # commande à la fois. Une commande annulée libère la référence (elle n'a pas abouti).
            deja_utilisee = Commande.objects.filter(
                reference_paiement__iexact=reference,
            ).exclude(statut=Commande.Statut.ANNULEE).exists()
            if deja_utilisee:
                raise serializers.ValidationError(
                    {"reference_paiement": "Cette référence de transaction a déjà été utilisée pour une autre "
                                            "commande. Vérifie ta référence ou contacte la caisse."}
                )
        return data

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


class VenteDirecteSerializer(serializers.Serializer):
    """Vente au comptoir (POS) : crée une commande déjà encaissée ET servie, en un seul appel.
    Utilisée quand un client achète directement à la caisse, sans passer par la commande en ligne.
    """

    lignes = LigneCommandeEcritureSerializer(many=True)
    numero_table = serializers.CharField(required=False, allow_blank=True, default="")
    mode_paiement = serializers.ChoiceField(
        choices=Commande.ModePaiement.choices,
        required=False,
        default=Commande.ModePaiement.ESPECES,
    )
    reference_paiement = serializers.CharField(required=False, allow_blank=True, default="")

    def validate_lignes(self, value):
        if not value:
            raise serializers.ValidationError("La vente doit contenir au moins un article.")
        return value

    def create(self, validated_data):
        from django.utils import timezone

        request = self.context["request"]
        utilisateur = request.user if request.user.is_authenticated else None
        lignes_data = validated_data.pop("lignes")
        maintenant = timezone.now()

        commande = Commande.objects.create(
            caissiere=utilisateur,
            numero_table=(validated_data.get("numero_table") or "Comptoir")[:10],
            mode_commande=Commande.ModeCommande.SUR_PLACE,
            mode_paiement=validated_data.get("mode_paiement") or Commande.ModePaiement.ESPECES,
            reference_paiement=validated_data.get("reference_paiement", ""),
            paiement_confirme=True,
            statut=Commande.Statut.SERVIE,
            date_validation=maintenant,
            date_prete=maintenant,
            date_servie=maintenant,
        )

        for ligne_data in lignes_data:
            selections_data = ligne_data.pop("selections", [])
            ligne = LigneCommande.objects.create(commande=commande, **ligne_data)
            for selection in selections_data:
                SelectionChoix.objects.create(
                    ligne=ligne,
                    groupe=selection["groupe"],
                    option=selection["option"],
                )

        commande.enregistrer_historique()
        return commande
