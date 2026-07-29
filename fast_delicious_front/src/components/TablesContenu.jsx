import { useEffect, useState } from "react";
import client from "../api/client";
import EmptyState from "./EmptyState";
import "./AdminContenus.css";

export default function TablesContenu() {
  const [tables, setTables] = useState([]);
  const [chargement, setChargement] = useState(true);
  const [nouveauNom, setNouveauNom] = useState("");

  function charger() {
    setChargement(true);
    client.get("menu/tables/").then((res) => {
      setTables(res.data);
      setChargement(false);
    });
  }

  useEffect(() => { charger(); }, []);

  async function ajouter() {
    const nom = nouveauNom.trim();
    if (!nom) return;
    await client.post("menu/tables/", { nom });
    setNouveauNom("");
    charger();
  }

  async function supprimer(table) {
    if (!window.confirm(`Supprimer "${table.nom}" ?`)) return;
    await client.delete(`menu/tables/${table.id}/`);
    charger();
  }

  if (chargement) return <p className="chargement-texte">Chargement...</p>;

  return (
    <div>
      <div className="admin-contenu-header">
        <h3>Tables / Stands</h3>
      </div>
      <div style={{ display: "flex", gap: 8, marginBottom: 16, maxWidth: 380 }}>
        <input
          placeholder="Ex : Stand 5, Table 12..."
          value={nouveauNom}
          onChange={(e) => setNouveauNom(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && ajouter()}
          style={{ flex: 1, padding: "9px 12px", borderRadius: 8, border: "1.5px solid var(--line)" }}
        />
        <button className="admin-btn-ajouter" onClick={ajouter}>+ Ajouter</button>
      </div>
      {tables.length === 0 ? (
        <EmptyState icon="🍽️" title="Aucune table enregistrée" />
      ) : (
        <div className="admin-tags-wrap">
          {tables.map((t) => (
            <div className="admin-tag" key={t.id}>
              {t.nom}
              <button onClick={() => supprimer(t)}>✕</button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
