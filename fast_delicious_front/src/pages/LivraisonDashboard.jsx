import { useCallback, useEffect, useState } from "react";
import client from "../api/client";
import { useDashboardSocket } from "../hooks/useDashboardSocket";
import PageHero from "../components/PageHero";
import EmptyState from "../components/EmptyState";
import { detailsLigne } from "../utils/ligne";
import { jouerNotification } from "../utils/son";
import "./LivraisonDashboard.css";

function minutesDepuis(dateIso) {
  return Math.floor((Date.now() - new Date(dateIso).getTime()) / 60000);
}

export default function LivraisonDashboard() {
  const [commandes, setCommandes] = useState([]);
  const [enTraitement, setEnTraitement] = useState({});

  const chargerFile = useCallback(() => {
    client.get("livraison/commandes/").then((res) => setCommandes(res.data));
  }, []);

  useEffect(() => {
    chargerFile();
    const id = setInterval(chargerFile, 15000);
    return () => clearInterval(id);
  }, [chargerFile]);

  const { connecte } = useDashboardSocket("livraison", (data) => {
    if (data.evenement === "commande_prete") {
      jouerNotification();
    }
    chargerFile();
  });

  async function prendreEnCharge(commandeId) {
    setEnTraitement((p) => ({ ...p, [commandeId]: true }));
    try {
      await client.patch(`livraison/commandes/${commandeId}/prendre/`);
      chargerFile();
    } finally {
      setEnTraitement((p) => ({ ...p, [commandeId]: false }));
    }
  }

  async function marquerLivree(commandeId) {
    setEnTraitement((p) => ({ ...p, [commandeId]: true }));
    try {
      await client.patch(`livraison/commandes/${commandeId}/livree/`);
      setCommandes((prev) => prev.filter((c) => c.id !== commandeId));
    } finally {
      setEnTraitement((p) => ({ ...p, [commandeId]: false }));
    }
  }

  const aLivrer = commandes.filter((c) => c.statut === "PRETE");
  const enCours = commandes.filter((c) => c.statut === "EN_LIVRAISON");

  return (
    <div className="livraison-dashboard">
      <PageHero
        icon="🛵"
        title="Livraisons"
        subtitle="Commandes prêtes à livrer, et celles déjà en route."
        live={connecte}
      />

      {commandes.length === 0 ? (
        <EmptyState
          icon="📦"
          title="Aucune livraison pour le moment"
          subtitle="Les commandes prêtes en mode livraison apparaîtront ici automatiquement."
        />
      ) : (
        <>
          {enCours.length > 0 && (
            <div className="livraison-section">
              <h3>En cours de livraison</h3>
              <div className="livraison-grid">
                {enCours.map((cmd) => (
                  <div className="livraison-card active" key={cmd.id}>
                    <div className="lc-top">
                      <span className="lc-id font-mono">#{cmd.id}</span>
                      <span className="lc-tag">En route</span>
                    </div>
                    <div className="lc-adresse">📍 {cmd.adresse_livraison}</div>
                    <div className="lc-tel">📞 {cmd.telephone_client}</div>
                    <ul className="font-mono">
                      {cmd.lignes.map((l) => (
                        <li key={l.id}>{l.quantite}x {l.plat_nom}{detailsLigne(l)}</li>
                      ))}
                    </ul>
                    <div className="lc-total font-mono">{Number(cmd.total).toLocaleString("fr-FR")} F</div>
                    <button
                      className="lc-btn done"
                      onClick={() => marquerLivree(cmd.id)}
                      disabled={enTraitement[cmd.id]}
                    >
                      {enTraitement[cmd.id] ? "..." : "✓ Marquer livrée"}
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}

          {aLivrer.length > 0 && (
            <div className="livraison-section">
              <h3>Prêtes à livrer</h3>
              <div className="livraison-grid">
                {aLivrer.map((cmd) => {
                  const attente = minutesDepuis(cmd.date_prete);
                  return (
                    <div className={`livraison-card${attente >= 10 ? " urgent" : ""}`} key={cmd.id}>
                      <div className="lc-top">
                        <span className="lc-id font-mono">#{cmd.id}</span>
                        <span className="lc-wait">⏱ prête depuis {attente} min</span>
                      </div>
                      <div className="lc-adresse">📍 {cmd.adresse_livraison}</div>
                      <div className="lc-tel">📞 {cmd.telephone_client}</div>
                      <ul className="font-mono">
                        {cmd.lignes.map((l) => (
                          <li key={l.id}>{l.quantite}x {l.plat_nom}{detailsLigne(l)}</li>
                        ))}
                      </ul>
                      <div className="lc-total font-mono">{Number(cmd.total).toLocaleString("fr-FR")} F</div>
                      <button
                        className="lc-btn"
                        onClick={() => prendreEnCharge(cmd.id)}
                        disabled={enTraitement[cmd.id]}
                      >
                        {enTraitement[cmd.id] ? "..." : "🛵 Je prends cette livraison"}
                      </button>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
