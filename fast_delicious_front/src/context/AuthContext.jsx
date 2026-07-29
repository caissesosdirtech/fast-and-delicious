import { createContext, useContext, useEffect, useState } from "react";
import client from "../api/client";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [utilisateur, setUtilisateur] = useState(null);
  const [chargement, setChargement] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem("access_token");
    if (!token) {
      setChargement(false);
      return;
    }
    client
      .get("comptes/moi/")
      .then((res) => setUtilisateur(res.data))
      .catch(() => {
        localStorage.removeItem("access_token");
        localStorage.removeItem("refresh_token");
      })
      .finally(() => setChargement(false));
  }, []);

  async function connexion(username, password) {
    const { data } = await client.post("auth/token/", { username, password });
    localStorage.setItem("access_token", data.access);
    localStorage.setItem("refresh_token", data.refresh);
    const profil = await client.get("comptes/moi/");
    setUtilisateur(profil.data);
    return profil.data;
  }

  function deconnexion() {
    localStorage.removeItem("access_token");
    localStorage.removeItem("refresh_token");
    setUtilisateur(null);
  }

  return (
    <AuthContext.Provider value={{ utilisateur, chargement, connexion, deconnexion }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
