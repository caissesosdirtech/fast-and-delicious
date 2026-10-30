# Confirmation automatique des paiements — Wave & Orange Money

Ce guide explique comment activer la **confirmation automatique** des paiements :
le client paie par Wave ou Orange Money, et la commande passe toute seule en
« payée » — sans que la caissière saisisse une référence à la main.

> ⚠️ **Important** : ce code suit la documentation publique de Wave et d'Orange
> Money, mais il n'a **pas pu être testé contre les vraies API** depuis l'atelier.
> Avant d'encaisser de vrais clients, teste chaque fournisseur en bac à sable.
> Les détails exacts d'Orange Money peuvent varier selon ton compte : vérifie-les
> dans ton espace Orange Developer et ajuste si besoin.

---

## 1. Comment ça marche

1. La caisse demande un paiement pour une commande →
   `POST /api/caisse/commandes/<id>/paiement/` avec `{"provider": "WAVE"}` ou `{"provider": "ORANGE_MONEY"}`.
2. Le backend crée une session chez le fournisseur et renvoie une **URL / QR de paiement**.
3. Le client paie.
4. Le fournisseur appelle un **webhook** sur ton backend :
   - Wave → `POST /api/webhooks/wave/`
   - Orange Money → `POST /api/webhooks/orange-money/`
5. Le backend vérifie le paiement et marque la commande **payée** automatiquement
   (`paiement_confirme = True`), puis prévient la caisse en temps réel.

---

## 2. Variables d'environnement (Railway → Variables)

Tant qu'elles sont vides, les endpoints répondent « non configuré » et **rien
d'autre dans l'app n'est affecté**.

### Wave
| Variable | Description |
|----------|-------------|
| `WAVE_API_KEY` | Clé API de ton compte Wave Business. |
| `WAVE_WEBHOOK_SECRET` | Secret du webhook (fourni par Wave) pour vérifier la signature. **Obligatoire** : sans lui, les webhooks sont refusés. |
| `WAVE_API_BASE` | (optionnel) par défaut `https://api.wave.com`. |

### Orange Money
| Variable | Description |
|----------|-------------|
| `ORANGE_CLIENT_ID` | Client ID de ton application Orange Developer. |
| `ORANGE_CLIENT_SECRET` | Client Secret. |
| `ORANGE_MERCHANT_KEY` | Clé marchand Web Payment. |
| `ORANGE_PAYS` | (optionnel) segment pays de l'API, ex. `cisenegal`. |
| `ORANGE_DEVISE` | (optionnel) `OUV` en test, `XOF` en production. |
| `ORANGE_API_BASE` | (optionnel) par défaut `https://api.orange.com`. |

### Commun
| Variable | Description |
|----------|-------------|
| `FRONTEND_URL` | Déjà configurée : sert aux pages de retour (succès/échec). |

---

## 3. Enregistrer les URL de webhook

Dans tes tableaux de bord marchands, déclare l'URL publique de **ton backend** :

- **Wave** → URL de notification : `https://TON-BACKEND/api/webhooks/wave/`
- **Orange Money** → `notif_url` : `https://TON-BACKEND/api/webhooks/orange-money/`

> Remplace `TON-BACKEND` par l'URL Railway de ton backend (ex.
> `https://fast-and-delicious-production.up.railway.app`).
> ⚠️ Pour Orange Money, le champ `notif_url` est construit dans
> `orders/paiements.py` : vérifie qu'il pointe bien vers ton **backend** (et non
> le frontend). Ajuste-le selon ton déploiement.

---

## 4. Tester

1. Mets les clés de **test / bac à sable** dans Railway.
2. Depuis la caisse, déclenche un paiement (ou appelle l'endpoint à la main avec
   un outil comme Postman).
3. Paie avec un compte de test.
4. Vérifie que la commande passe en « payée » automatiquement dans la caisse.
5. Une fois que tout marche, bascule sur les **clés de production**.

---

## 5. Déploiement

Aucune migration de base de données n'est nécessaire (on réutilise les champs
`mode_paiement`, `reference_paiement` et `paiement_confirme` existants).

```bash
git add fast_delicious_back
git commit -m "Paiement en ligne : confirmation auto Wave & Orange Money"
git push
```

`requests` a été ajouté à `requirements.txt` — Railway l'installera au redéploiement.

---

## 6. Prochaine étape (interface caisse)

Le bouton « Demander le paiement Wave / Orange Money » dans l'interface caisse
(qui affiche le QR au client) est prêt à être ajouté. On le branche dès que tu
as confirmé que le backend fonctionne avec tes clés — comme ça, on ajuste
l'interface en fonction du comportement réel des API.
