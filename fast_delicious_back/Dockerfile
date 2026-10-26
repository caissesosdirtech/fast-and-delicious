# Image de build fiable pour Railway (Builder = Dockerfile / BuildKit).
# IMPORTANT : on copie TOUT le code AVANT le pip install, pour qu'un changement
# de code (ou de requirements) invalide le cache et force une reconstruction
# complète — sinon Railway réutilise une ancienne image en cache.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Tout le code d'abord (casse le cache à chaque changement de code).
COPY . .

# Dépendances. On force aussi openpyxl + reportlab explicitement (export PDF/Excel),
# au cas où un requirements.txt en double ne les contiendrait pas.
RUN pip install -r requirements.txt \
    && pip install "openpyxl==3.1.5" "reportlab==4.2.5"

# Fichiers statiques (whitenoise).
RUN python manage.py collectstatic --noinput

# Railway fournit $PORT. On migre puis on lance daphne (ASGI, websockets).
CMD python manage.py migrate --noinput && daphne -b 0.0.0.0 -p ${PORT:-8000} backend.asgi:application
