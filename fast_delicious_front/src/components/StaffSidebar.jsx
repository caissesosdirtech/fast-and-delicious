import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import NotificationsCloche from "./NotificationsCloche";
import "./StaffSidebar.css";
import "./StaffDark.css";

// Lit le thème mémorisé (par défaut sombre). localStorage protégé pour les navigateurs stricts.
function themeInitial() {
  try {
    return localStorage.getItem("staff_theme") !== "clair"; // true = sombre
  } catch {
    return true;
  }
}

/**
 * items: [{ icone: "📊", label: "Tableau de bord" }, ...]
 * rubriqueActive: index
 * onChangerRubrique: (index) => void
 * enfant: contenu principal affiché à droite
 */
export default function StaffSidebar({ items, rubriqueActive, onChangerRubrique, enfant }) {
  const { utilisateur, deconnexion } = useAuth();
  const navigate = useNavigate();
  const [menuOuvert, setMenuOuvert] = useState(false);
  const [sombre, setSombre] = useState(themeInitial);

  const estStaff = utilisateur?.role === "caissiere" || utilisateur?.role === "admin";
  const indexCommandes = items.findIndex((it) => (it.label || "").toLowerCase().includes("commande"));
  const allerCommandes = () => {
    if (indexCommandes >= 0) onChangerRubrique(indexCommandes);
  };

  useEffect(() => {
    try {
      localStorage.setItem("staff_theme", sombre ? "sombre" : "clair");
    } catch {
      /* ignore */
    }
  }, [sombre]);

  function seDeconnecter() {
    deconnexion();
    navigate("/");
  }

  return (
    <div className={`staff-layout${sombre ? " theme-sombre" : ""}`}>
      <aside className="staff-sidebar">
        <div className="staff-sidebar-logo">
          <span>ESPACE STAFF</span>
        </div>
        <nav className="staff-sidebar-nav">
          {items.map((item, i) => (
            <button
              key={item.label}
              className={`staff-sidebar-item${i === rubriqueActive ? " actif" : ""}`}
              onClick={() => onChangerRubrique(i)}
            >
              <span className="staff-sidebar-icone">{item.icone}</span>
              {item.label}
            </button>
          ))}
        </nav>
        <button className="staff-sidebar-deconnexion" onClick={seDeconnecter}>
          ⏻ Déconnexion ({utilisateur?.username})
        </button>
      </aside>

      <div className="staff-main">
        <div className="staff-topbar">
          <h2>{items[rubriqueActive]?.label}</h2>
          <div className="staff-topbar-droite">
            <button
              className="theme-toggle"
              onClick={() => setSombre((v) => !v)}
              aria-label={sombre ? "Passer en thème clair" : "Passer en thème sombre"}
              title={sombre ? "Thème clair" : "Thème sombre"}
            >
              {sombre ? "☀️" : "🌙"}
            </button>

            {estStaff && <NotificationsCloche onVoirCommandes={allerCommandes} />}

            <div className="staff-topbar-user" onClick={() => setMenuOuvert((v) => !v)}>
              <div className="staff-avatar">{utilisateur?.username?.[0]?.toUpperCase()}</div>
              <div>
                <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
                  <span>{utilisateur?.username}</span>
                  <span className="staff-chevron">▾</span>
                </div>
                {utilisateur?.lieu_nom && <div className="staff-lieu-badge">📍 {utilisateur.lieu_nom}</div>}
              </div>
              {menuOuvert && (
                <div className="staff-user-menu" onClick={(e) => e.stopPropagation()}>
                  <button onClick={seDeconnecter}>Déconnexion</button>
                </div>
              )}
            </div>
          </div>
        </div>
        <div className="staff-contenu">{enfant}</div>
      </div>
    </div>
  );
}
