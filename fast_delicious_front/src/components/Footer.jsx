import "./Footer.css";

export default function Footer() {
  const annee = new Date().getFullYear();

  return (
    <footer className="app-footer">
      <div className="app-footer-inner">

        <div className="app-footer-brand">
          <img src="/logo-fast-delicious.jpg" alt="Fast & Delicious" className="app-footer-logo" />
          <span className="font-display">Fast &amp; Delicious</span>
        </div>

        <div className="app-footer-copyright">
          <span>© {annee} <strong>Deep Mind Technologie (DMT)</strong> — Tous droits réservés</span>
          <span className="footer-sep" aria-hidden="true">·</span>
          <a href="tel:+221775470087" className="app-footer-link">📞 77 547 00 87</a>
          <span className="footer-sep" aria-hidden="true">·</span>
          <a href="mailto:cissemadamel86@gmail.com" className="app-footer-link">✉️ cissemadamel86@gmail.com</a>
        </div>

      </div>
    </footer>
  );
}
