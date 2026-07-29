# Autoriser le trafic non chiffré (http/ws) sous Android

Depuis Android 9 (API 28+), le trafic non chiffré (`http://`, `ws://`) est bloqué par défaut.
Comme ton backend Django tourne en local sans HTTPS, il faut l'autoriser explicitement.

## 1. Copier le fichier de config réseau

Copie `app/src/main/res/xml/network_security_config.xml` (à côté de ce fichier) dans ton vrai
projet Flutter, au même chemin : `android/app/src/main/res/xml/network_security_config.xml`.

## 2. Modifier `android/app/src/main/AndroidManifest.xml`

Ajoute l'attribut `android:networkSecurityConfig` sur la balise `<application>` :

```xml
<application
    android:label="fast_delicious_mobile"
    android:networkSecurityConfig="@xml/network_security_config"
    android:icon="@mipmap/ic_launcher">
```

## 3. Si tu testes sur un téléphone physique (pas l'émulateur)

- Remplace `10.0.2.2` par l'adresse IP locale de ton PC dans `network_security_config.xml`
  (trouve-la avec `ipconfig` sous Windows, cherche "Adresse IPv4")
- Mets à jour `lib/config/api_config.dart` avec cette même IP

## 4. Reconstruire

```bash
flutter clean
flutter pub get
flutter run
```

⚠️ Cette configuration est **pour le développement uniquement**. Une fois le backend déployé
en HTTPS (voir GUIDE_DEPLOIEMENT.md), retire cette exception et utilise `https://`/`wss://`
dans `api_config.dart` — le trafic sera alors chiffré et cette config ne sera plus nécessaire.
