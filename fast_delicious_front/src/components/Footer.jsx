import "./Footer.css";

export default function Footer() {
  const annee = new Date().getFullYear();

  return (
    <footer className="app-footer">
      <div className="app-footer-inner">

        <div className="app-footer-copyright">
          <span>© {annee} · JOJ Dakar 2026</span>
        </div>

      </div>
    </footer>
  );
}
