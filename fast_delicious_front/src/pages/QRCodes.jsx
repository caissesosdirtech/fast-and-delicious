import { useState } from "react";
import PageHero from "../components/PageHero";
import "./QRCodes.css";

const NOMS_PAR_DEFAUT = ["Stand 1", "Stand 2", "Stand 3", "Stand 4"];

function urlPourTable(nomTable) {
  const base = `${window.location.origin}/`;
  return `${base}?table=${encodeURIComponent(nomTable)}`;
}

function urlImageQRCode(contenu) {
  // Génère l'image du QR code via une API publique gratuite (aucune dépendance à installer).
  return `https://api.qrserver.com/v1/create-qr-code/?size=260x260&margin=10&data=${encodeURIComponent(contenu)}`;
}

export default function QRCodes() {
  const [noms, setNoms] = useState(NOMS_PAR_DEFAUT);
  const [nouveauNom, setNouveauNom] = useState("");

  function ajouterTable() {
    const nom = nouveauNom.trim();
    if (!nom || noms.includes(nom)) return;
    setNoms((prev) => [...prev, nom]);
    setNouveauNom("");
  }

  function retirerTable(nom) {
    setNoms((prev) => prev.filter((n) => n !== nom));
  }

  return (
    <div className="qr-page">
      <PageHero
        icon="🔗"
        title="QR codes par table / stand"
        subtitle="À imprimer et coller sur chaque table — le client scanne et le numéro est déjà rempli."
      />

      <div className="qr-toolbar">
        <input
          placeholder="Nom du stand (ex: Stand 5, Table 12...)"
          value={nouveauNom}
          onChange={(e) => setNouveauNom(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && ajouterTable()}
        />
        <button onClick={ajouterTable}>+ Ajouter</button>
        <button className="print-btn" onClick={() => window.print()}>🖨️ Imprimer tout</button>
      </div>

      <div className="qr-grid">
        {noms.map((nom) => (
          <div className="qr-card" key={nom}>
            <button className="qr-remove no-print" onClick={() => retirerTable(nom)} aria-label="Retirer">✕</button>
            <img src={urlImageQRCode(urlPourTable(nom))} alt={`QR code ${nom}`} />
            <div className="qr-label font-display">{nom}</div>
            <div className="qr-url">{urlPourTable(nom)}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
