import { useEffect, useState } from "react";
import client from "../api/client";
import EmptyState from "./EmptyState";
import "./AdminContenus.css";

export default function LieuxContenu() {
  const [lieux, setLieux] = useState([]);
  const [chargement, setChargement] = useState(true);
  const [nouveauNom, setNouveauNom] = useState("");

  function charger() {
    setChargement(true);
    client.get("menu/lieux/").then((res) => {
      setLieux(res.data);
      setChargement(false);
    });
  }

  useEffect(() => { charger(); }, []);

  async function ajouter() {
    const nom = nouveauNom.trim();
    if (!nom) return;
    try {
      await client.post("menu/lieux/", { nom });
      setNouveauNom("");
      charger();
    } catch (e) {
      const msg = e?.response?.status === 403
        ? "Action réservée à l'administrateur."
        : (e?.response?.data?.nom?.[0] || "Impossible d'ajouter ce lieu. Réessaie.");
      window.alert(msg);
    }
  }

  async function supprimer(lieu) {
    if (!window.confirm(`Supprimer "${lieu.nom}" ? Le personnel affecté à ce lieu devra être réaffecté.`)) return;
    try {
      await client.delete(`menu/lieux/${lieu.id}/`);
      charger();
    } catch (e) {
      window.alert(e?.response?.status === 403 ? "Action réservée à l'administrateur." : "Suppression impossible.");
    }
  }

  if (chargement) return <p className="chargement-texte">Chargement...</p>;

  return (
    <div>
      <div className="admin-contenu-header">
        <h3>Lieux / Événements</h3>
      </div>
      <p style={{ fontSize: 11.5, color: "var(--ink-soft)", marginTop: -8, marginBottom: 16 }}>
        Utile si l'équipe organise deux kermesses en même temps, dans deux endroits différents :
        crée un lieu par site, puis affecte chaque membre du staff à son lieu (page Employés).
        Chaque caissier/cuisinier ne verra alors que les commandes de son propre lieu.
        Si un seul lieu existe (ou aucun), rien ne change dans le fonctionnement habituel.
      </p>
      <div style={{ display: "flex", gap: 8, marginBottom: 16, maxWidth: 380 }}>
        <input
          placeholder="Ex : Kermesse Paroisse A"
          value={nouveauNom}
          onChange={(e) => setNouveauNom(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && ajouter()}
          style={{ flex: 1, padding: "9px 12px", borderRadius: 8, border: "1.5px solid var(--line)" }}
        />
        <button className="admin-btn-ajouter" onClick={ajouter}>+ Ajouter</button>
      </div>
      {lieux.length === 0 ? (
        <EmptyState icon="📍" title="Aucun lieu configuré" subtitle="Un seul événement en cours — c'est le fonctionnement normal par défaut." />
      ) : (
        <div className="admin-tags-wrap">
          {lieux.map((l) => (
            <div className="admin-tag" key={l.id}>
              📍 {l.nom}
              <button onClick={() => supprimer(l)}>✕</button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
