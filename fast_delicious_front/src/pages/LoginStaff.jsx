import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import "./LoginStaff.css";

export default function LoginStaff() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [erreur, setErreur] = useState(null);
  const [enCours, setEnCours] = useState(false);
  const { connexion } = useAuth();
  const navigate = useNavigate();

  async function onSubmit(e) {
    e.preventDefault();
    setErreur(null);
    setEnCours(true);
    try {
      const profil = await connexion(username, password);
      if (profil.role === "caissiere" || profil.role === "admin") {
        navigate("/caisse");
      } else if (profil.role === "cuisine") {
        navigate("/cuisine");
      } else if (profil.role === "livreur") {
        navigate("/livraison");
      } else {
        navigate("/");
      }
    } catch {
      setErreur("Identifiant ou mot de passe incorrect.");
    } finally {
      setEnCours(false);
    }
  }

  return (
    <div className="login-page">
      <div className="login-shell">

        {/* Panneau de marque */}
        <div className="login-brand">
          <div className="login-brand-logo">
            <img src="/logo-fast-delicious.jpg" alt="Fast & Delicious" />
          </div>
          <h1 className="font-display">Fast &amp; Delicious</h1>
          <p>Espace réservé à l'équipe caisse et cuisine. Suivez les commandes et gérez la file en direct.</p>

          <div className="login-brand-tags">
            <span>Caissière</span>
            <span>Cuisine</span>
            <span>Livreur</span>
            <span>Admin</span>
          </div>
        </div>

        {/* Formulaire */}
        <form className="login-form" onSubmit={onSubmit}>
          <div className="login-form-head">
            <h2>Connexion</h2>
            <p>Entrez vos identifiants pour accéder à votre tableau de bord.</p>
          </div>

          <label htmlFor="username">Identifiant</label>
          <div className="input-wrap">
            <span className="input-icon" aria-hidden="true">👤</span>
            <input
              id="username"
              autoComplete="username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="ex. caissiere1"
              required
            />
          </div>

          <label htmlFor="password">Mot de passe</label>
          <div className="input-wrap">
            <span className="input-icon" aria-hidden="true">🔒</span>
            <input
              id="password"
              type={showPassword ? "text" : "password"}
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              required
            />
            <button
              type="button"
              className="toggle-visibility"
              onClick={() => setShowPassword((v) => !v)}
              aria-label={showPassword ? "Masquer le mot de passe" : "Afficher le mot de passe"}
            >
              {showPassword ? "🙈" : "👁️"}
            </button>
          </div>

          {erreur && (
            <div className="login-erreur">
              <span aria-hidden="true">⚠️</span>
              <span>{erreur}</span>
            </div>
          )}

          <button type="submit" className="submit-btn" disabled={enCours}>
            {enCours ? "Connexion..." : "Se connecter"}
          </button>
        </form>

      </div>
    </div>
  );
}
