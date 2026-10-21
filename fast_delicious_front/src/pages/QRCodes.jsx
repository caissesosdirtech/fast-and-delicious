import { useEffect, useState } from "react";
import PageHero from "../components/PageHero";
import client from "../api/client";
import "./QRCodes.css";

const NOMS_PAR_DEFAUT = ["Stand 1", "Stand 2", "Stand 3", "Stand 4"];

// Construit l'URL que le client ouvrira : le lieu (id) et/ou la table sont pré-remplis.
function construireUrl({ table, lieuId }) {
  const params = new URLSearchParams();
  if (lieuId) params.set("lieu", lieuId);
  if (table) params.set("table", table);
  const q = params.toString();
  return `${window.location.origin}/${q ? "?" + q : ""}`;
}

function urlImageQRCode(contenu) {
  // Image du QR via une API publique gratuite (aucune dépendance à installer).
  return `https://api.qrserver.com/v1/create-qr-code/?size=260x260&margin=10&data=${encodeURIComponent(contenu)}`;
}

export default function QRCodes() {
  const [noms, setNoms] = useState(NOMS_PAR_DEFAUT);
  const [nouveauNom, setNouveauNom] = useState("");
  const [lieux, setLieux] = useState([]);
  const [lieuId, setLieuId] = useState("");

  useEffect(() => {
    client.get("menu/lieux/").then((res) => setLieux(res.data)).catch(() => {});
  }, []);

  const lieuNom = lieux.find((l) => String(l.id) === String(lieuId))?.nom;

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
        subtitle="À imprimer et coller sur place — le client scanne et le site (et la table) sont déjà remplis."
      />

      {lieux.length > 0 && (
        <div className="qr-lieu-select no-print">
          <label>📍 Site / Événement :</label>
          <select value={lieuId} onChange={(e) => setLieuId(e.target.value)}>
            <option value="">— Aucun (un seul site) —</option>
            {lieux.map((l) => (
              <option key={l.id} value={l.id}>{l.nom}</option>
            ))}
          </select>
          {lieuNom && (
            <span className="qr-lieu-actif">Les QR ci-dessous pointent vers <strong>{lieuNom}</strong></span>
          )}
        </div>
      )}

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
        {/* QR "entrée du site" : juste le lieu, sans table (pour l'accueil du site) */}
        {lieuId && (
          <div className="qr-card qr-card-site" key="__site__">
            <img src={urlImageQRCode(construireUrl({ lieuId }))} alt={`QR site ${lieuNom}`} />
            <div className="qr-label font-display">📍 {lieuNom}</div>
            <div className="qr-sous-label">Entrée du site</div>
            <div className="qr-url">{construireUrl({ lieuId })}</div>
          </div>
        )}

        {noms.map((nom) => {
          const url = construireUrl({ table: nom, lieuId });
          return (
            <div className="qr-card" key={nom}>
              <button className="qr-remove no-print" onClick={() => retirerTable(nom)} aria-label="Retirer">✕</button>
              <img src={urlImageQRCode(url)} alt={`QR code ${nom}`} />
              <div className="qr-label font-display">{nom}</div>
              {lieuNom && <div className="qr-lieu-badge">📍 {lieuNom}</div>}
              <div className="qr-url">{url}</div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
