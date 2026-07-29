# Fast & Delicious — Frontend React

Application cliente + dashboards (caissière/cuisine) branchée sur l'API Django.

## Installation

```bash
npm install
npm run dev
```

Ouvre `http://localhost:5173/`.

⚠️ Le backend Django doit tourner en parallèle sur `http://127.0.0.1:8000/`
(voir le README du backend). Les URLs de l'API sont centralisées dans
`src/api/client.js` (`API_BASE_URL`, `WS_BASE_URL`) — à modifier si besoin.

## Pages

| Route | Page | Accès |
|---|---|---|
| `/` | Menu client — composer et envoyer une commande | public |
| `/suivi/:id` | Suivi de commande en direct (WebSocket) | public |
| `/staff/login` | Connexion caissière / cuisine | public |
| `/caisse` | Dashboard caissière (valider les commandes) | rôle caissiere/admin |
| `/cuisine` | Dashboard cuisine (préparer, marquer prête) | rôle cuisine/admin |

## Comptes de test (créés par `seed_demo` côté backend)

- Caissière : `caissiere1` / `caisse123`
- Cuisinier : `cuisinier1` / `cuisine123`

## Structure

```
src/
├── api/client.js              axios + JWT (refresh automatique)
├── context/AuthContext.jsx    connexion/déconnexion, utilisateur courant
├── hooks/
│   ├── useCommandeSocket.js   suivi WebSocket d'une commande
│   └── useDashboardSocket.js  écoute WebSocket caisse/cuisine
├── components/
│   ├── TopBar.jsx
│   ├── Stepper.jsx
│   ├── TimerRestant.jsx
│   └── RouteProtegee.jsx      garde d'accès par rôle
└── pages/
    ├── ClientMenu.jsx
    ├── ClientSuivi.jsx
    ├── LoginStaff.jsx
    ├── CaissiereDashboard.jsx
    └── CuisineDashboard.jsx
```

## Build de production

```bash
npm run build
```
