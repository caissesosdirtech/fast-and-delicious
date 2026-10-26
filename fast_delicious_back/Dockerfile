# Image de build fiable pour Railway (contourne l'auto-détection Railpack/Nixpacks).
# À utiliser avec Root Directory = fast_delicious_back dans les réglages du service.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Dépendances Python
COPY requirements.txt .
RUN pip install -r requirements.txt

# Code de l'application
COPY . .

# Fichiers statiques (servis par whitenoise). Ne touche pas la base de données.
RUN python manage.py collectstatic --noinput

# Railway fournit $PORT. On applique les migrations puis on lance daphne (ASGI,
# nécessaire pour les websockets temps réel).
CMD python manage.py migrate --noinput && daphne -b 0.0.0.0 -p ${PORT:-8000} backend.asgi:application
