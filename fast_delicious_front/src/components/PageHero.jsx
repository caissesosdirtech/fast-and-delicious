import "./PageHero.css";

/**
 * En-tête réutilisé sur toutes les pages : icône, titre, sous-titre,
 * et éventuellement un badge "en direct" (statut de connexion WebSocket).
 */
export default function PageHero({ icon, title, subtitle, live }) {
  return (
    <div className="page-hero">
      <div className="page-hero-icon">{icon}</div>
      <h1 className="font-display">{title}</h1>
      <p>{subtitle}</p>
      {live !== undefined && (
        <div className={`live-badge${live ? "" : " offline"}`}>
          <span className="live-dot" />
          {live ? "En direct" : "Connexion..."}
        </div>
      )}
    </div>
  );
}
