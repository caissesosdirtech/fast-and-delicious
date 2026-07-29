# Fast & Delicious — Application mobile Flutter

⚠️ **Important** : ce code a été écrit sans pouvoir être compilé ni testé (pas d'accès au SDK Flutter/pub.dev
dans l'environnement où il a été généré). Contrairement au backend Django et au frontend React, il est possible
qu'il reste des erreurs de compilation à corriger. Lance `flutter pub get` puis `flutter run` et **envoie-moi le
message d'erreur exact** si quelque chose ne compile pas — on corrigera ensemble comme on l'a fait pour le
backend au début.

## Ce qui est fait à cette étape

- Structure du projet, thème visuel (mêmes couleurs que le web)
- Modèles de données (Commande, Plat, Catégorie, groupes de choix, etc.)
- Client API avec rafraîchissement JWT automatique
- Connexion WebSocket temps réel
- Panier (gestion des accompagnements, formules composées, mode livraison, mode de paiement)
- Écran menu client (recherche, formules mises en avant, rubriques, message incitatif table/stand)
- Écran de suivi de commande (temps réel, son de notification, annulation)
- Écran de connexion staff

## Ce qui reste à faire (prochaines étapes)

- Tableau de bord caissière
- Tableau de bord cuisine
- Tableau de bord livraison
- Tableau de bord admin (statistiques)
- Page de génération des QR codes par table
- Pied de page / à propos

## Installation

```bash
cd fast_delicious_mobile
flutter pub get
```

### Configurer l'adresse du backend

Ouvre `lib/config/api_config.dart` :

- **Émulateur Android** : `http://10.0.2.2:8000` (déjà configuré, pointe vers le localhost de ta machine)
- **iPhone/Android physique sur le même Wi-Fi** : remplace par l'adresse IP locale de ton PC, ex.
  `http://192.168.1.10:8000` (trouve-la avec `ipconfig` sous Windows)
- **Backend déployé en ligne** : mets l'URL de production (voir GUIDE_DEPLOIEMENT.md du backend)

⚠️ N'oublie pas d'autoriser cette origine côté Django (`CORS_ALLOWED_ORIGINS` dans `settings.py`) si nécessaire —
en réalité pour une app mobile native (pas un navigateur), CORS ne s'applique pas, donc pas de configuration
supplémentaire à faire côté backend pour ça.

### Lancer l'app

```bash
flutter run
```

## Comptes de test (identiques au web)

| Rôle | Identifiant | Mot de passe |
|---|---|---|
| Admin | admin | admin123 |
| Caissière | caissiere1 | caisse123 |
| Cuisinier | cuisinier1 | cuisine123 |
| Livreur | livreur1 | livreur123 |

## Assets

Le logo et les 3 QR codes de paiement (Wave, Orange Money, PI Mix/YAS) sont déjà copiés dans `assets/`
et déclarés dans `pubspec.yaml`. Remplace-les si tu changes de QR plus tard.

## Structure du projet

```
lib/
├── main.dart
├── config/          (URL API, thème, config paiement)
├── models/          (Commande, Plat, Categorie, Utilisateur...)
├── services/        (client API, WebSocket, son)
├── providers/        (AuthProvider, CartProvider — état global de l'app)
├── widgets/         (composants réutilisables : stepper, tiroir panier, barre du haut...)
└── screens/
    ├── client/      (menu, suivi)
    └── staff/       (connexion — les dashboards arrivent à la prochaine étape)
```
