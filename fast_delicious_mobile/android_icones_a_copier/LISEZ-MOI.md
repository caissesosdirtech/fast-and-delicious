# Changer l'icône de l'application (Android)

## 1. Copier les icônes

Copie **le contenu** du dossier `android_icones_a_copier/` (5 sous-dossiers `mipmap-*`) dans
ton vrai projet, à l'emplacement :

```
android/app/src/main/res/
```

Ça va **remplacer** les fichiers `ic_launcher.png` et `ic_launcher_round.png` existants dans
chacun des 5 dossiers `mipmap-mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi`.

## 2. (Optionnel) Renommer l'application

Le nom affiché sous l'icône ("fast_delicious_mobile" par défaut) se change dans
`android/app/src/main/AndroidManifest.xml` :

```xml
<application
    android:label="Fast &amp; Delicious"
    ...
```

(Remarque le `&amp;` à la place de `&` — obligatoire dans un fichier XML.)

## 3. Reconstruire

```powershell
flutter clean
flutter pub get
flutter run
```

Ou directement l'APK (voir GUIDE_DEPLOIEMENT_MOBILE.md) — la nouvelle icône sera incluse.

## Note technique

Ce sont des icônes "classiques" (carrées avec un léger fond crème autour du logo), compatibles
avec toutes les versions d'Android. Elles ne profitent pas du système d'icônes adaptatives
(masque rond/carré/goutte selon le launkey) introduit avec Android 8 — mais elles s'afficheront
correctement partout. Si tu veux ce rendu plus moderne plus tard, Android Studio propose un
outil "Image Asset" qui génère automatiquement les calques adaptatifs à partir de la même image.
