"""
Réglages Django pour le projet Fast & Delicious.
"""

import os
from datetime import timedelta
from pathlib import Path

import dj_database_url

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get(
    "SECRET_KEY", "django-insecure-i!pvs6uh-)yf0$x7*=jn@ymb#t)0qi6&jv_k0$1473wxo7tb7m"
)

# DEBUG=True par défaut en local ; en production, on définit DEBUG=False dans les variables d'environnement.
DEBUG = os.environ.get("DEBUG", "True") == "True"

ALLOWED_HOSTS = os.environ.get("ALLOWED_HOSTS", "*").split(",")


# Application definition

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',

    'rest_framework',
    'corsheaders',
    'channels',

    'accounts',
    'menu',
    'orders',
    'realtime',
]

AUTH_USER_MODEL = 'accounts.Utilisateur'

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',  # Indispensable pour les fichiers statiques sur Render
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'backend.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'backend.wsgi.application'
ASGI_APPLICATION = 'backend.asgi.application'


# Base de données.
# En local : SQLite.
# Sur Render / Production : PostgreSQL via DATABASE_URL.
DATABASE_URL = os.environ.get("DATABASE_URL")
if DATABASE_URL:
    DATABASES = {
        "default": dj_database_url.parse(DATABASE_URL, conn_max_age=600)
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }


# Channels : couche de communication temps réel.
REDIS_URL = os.environ.get("REDIS_URL")
if REDIS_URL:
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels_redis.core.RedisChannelLayer",
            "CONFIG": {"hosts": [REDIS_URL]},
        }
    }
else:
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels.layers.InMemoryChannelLayer",
        }
    }


AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]


LANGUAGE_CODE = 'fr-fr'
TIME_ZONE = 'Africa/Dakar'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STORAGES = {
    "default": {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
    },
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
    },
}

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'


# --- Django REST Framework ---
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
        'rest_framework.authentication.SessionAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(hours=8),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
}

# --- CORS & Sécurité ---
CORS_ALLOWED_ORIGINS = [
    "http://localhost:5173",
    "http://127.0.0.1:5173",
]

_frontend_url = os.environ.get("FRONTEND_URL")
if _frontend_url:
    CORS_ALLOWED_ORIGINS.append(_frontend_url)

CORS_ALLOW_CREDENTIALS = True

# Prise en charge automatique des domaines Render pour le HTTPS et les requêtes sécurisées
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

CSRF_TRUSTED_ORIGINS = [
    "https://*.onrender.com",
]
if _frontend_url:
    CSRF_TRUSTED_ORIGINS.append(_frontend_url)

# ============================================================
# Paiement en ligne — Wave & Orange Money (confirmation auto)
# ============================================================
# Toutes ces valeurs se règlent par variables d'environnement (Railway →
# Variables). Tant qu'elles sont vides, les endpoints de paiement répondent
# « non configuré » : le reste de l'application n'est pas affecté.

# URL publique du frontend (déjà utilisée plus haut) pour les pages de retour.
PAIEMENT_RETOUR_URL = _frontend_url or "https://www.menu-concession5.com"

# --- Wave Business (https://api.wave.com) ---
WAVE_API_KEY = os.environ.get("WAVE_API_KEY", "")
WAVE_API_BASE = os.environ.get("WAVE_API_BASE", "https://api.wave.com")
# Secret du webhook Wave, pour vérifier la signature des notifications.
WAVE_WEBHOOK_SECRET = os.environ.get("WAVE_WEBHOOK_SECRET", "")

# --- Orange Money (Orange Developer / Sonatel) ---
ORANGE_CLIENT_ID = os.environ.get("ORANGE_CLIENT_ID", "")
ORANGE_CLIENT_SECRET = os.environ.get("ORANGE_CLIENT_SECRET", "")
ORANGE_MERCHANT_KEY = os.environ.get("ORANGE_MERCHANT_KEY", "")
ORANGE_API_BASE = os.environ.get("ORANGE_API_BASE", "https://api.orange.com")
# Pays de l'API Web Payment Orange (ex: "cisenegal" / "sn" selon ton contrat).
ORANGE_PAYS = os.environ.get("ORANGE_PAYS", "cisenegal")
# Devise : "OUV" en test, "XOF" en production (selon Orange).
ORANGE_DEVISE = os.environ.get("ORANGE_DEVISE", "XOF")
