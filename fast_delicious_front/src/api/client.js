import axios from "axios";

// En local (npm run dev), pas besoin de fichier .env : ça pointe vers le backend en localhost.
// En production (Vercel), défini via la variable d'environnement VITE_API_BASE_URL
// (ex: https://ton-projet.up.railway.app), et le WebSocket en est déduit automatiquement.
export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || "http://127.0.0.1:8000";
export const WS_BASE_URL = API_BASE_URL.replace(/^http/, "ws");

const client = axios.create({ baseURL: `${API_BASE_URL}/api/` });

// Attache le token d'accès sur chaque requête si l'utilisateur est connecté.
client.interceptors.request.use((config) => {
  const token = localStorage.getItem("access_token");
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Si le token a expiré (401), on tente un rafraîchissement une seule fois puis on rejoue la requête.
client.interceptors.response.use(
  (response) => response,
  async (error) => {
    const original = error.config;
    if (error.response?.status === 401 && !original._retry) {
      original._retry = true;
      const refresh = localStorage.getItem("refresh_token");
      if (refresh) {
        try {
          const { data } = await axios.post(`${API_BASE_URL}/api/auth/token/refresh/`, {
            refresh,
          });
          localStorage.setItem("access_token", data.access);
          original.headers.Authorization = `Bearer ${data.access}`;
          return client(original);
        } catch {
          localStorage.removeItem("access_token");
          localStorage.removeItem("refresh_token");
        }
      }
    }
    return Promise.reject(error);
  }
);

export default client;
