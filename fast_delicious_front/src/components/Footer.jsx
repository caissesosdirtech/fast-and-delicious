import "./Footer.css";

export default function Footer() {
  const annee = new Date().getFullYear();

  return (
    <footer className="app-footer">
      <div className="app-footer-inner">

        <div className="app-footer-copyright">
          <span>© {annee} · Fast &amp; Delicious</span>
        </div>

      </div>
    </footer>
  );
}
