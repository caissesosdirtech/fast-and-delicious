import { Link, useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext";
import { useCart } from "../context/CartContext";
import "./TopBar.css";

export default function TopBar() {
  const { utilisateur, deconnexion } = useAuth();
  const { totalArticles, setPanierOuvert } = useCart();
  const location = useLocation();

  return (
    <header className="topbar">
      <Link to="/" className="brand">
        <span className="brand-text font-display">Menu</span>
      </Link>

      <div className="topbar-right">
        {!utilisateur && (
          <Link to="/" className="topbar-vitrine-link">🛍️ Commander</Link>
        )}
        {!utilisateur && (
          <button className="cart-btn" onClick={() => setPanierOuvert(true)} aria-label="Ouvrir le panier">
            🛍️
            {totalArticles > 0 && <span className="cart-btn-badge">{totalArticles}</span>}
          </button>
        )}

        {utilisateur ? (
          <>
            {utilisateur.role === "admin" && (
              <Link to="/admin" className="topbar-admin-link">📊 Tableau de bord</Link>
            )}
            {(utilisateur.role === "caissiere" || utilisateur.role === "admin") && (
              <Link to="/staff/qr-codes" className="topbar-admin-link">🔗 QR codes</Link>
            )}
            <span className="topbar-role">{utilisateur.username} · {utilisateur.role}</span>
            <button className="topbar-logout" onClick={deconnexion}>Déconnexion</button>
          </>
        ) : (
          !location.pathname.startsWith("/staff/login") && (
            <Link to="/staff/login" className="topbar-login">Espace staff</Link>
          )
        )}
      </div>
    </header>
  );
}
