import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import "./StaffSidebar.css";
import "./StaffDark.css";

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

  function seDeconnecter() {
    deconnexion();
    navigate("/");
  }

  return (
    <div className="staff-layout">
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
        <div className="staff-contenu">{enfant}</div>
      </div>
    </div>
  );
}
