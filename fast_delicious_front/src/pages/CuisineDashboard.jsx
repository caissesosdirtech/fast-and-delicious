import { useCallback, useEffect, useState } from "react";
import client from "../api/client";
import { useDashboardSocket } from "../hooks/useDashboardSocket";
import PageHero from "../components/PageHero";
import EmptyState from "../components/EmptyState";
import { detailsLigne } from "../utils/ligne";
import { jouerNotification } from "../utils/son";
import "./CuisineDashboard.css";

function minutesDepuis(dateIso) {
  return Math.floor((Date.now() - new Date(dateIso).getTime()) / 60000);
}

export default function CuisineDashboard() {
  const [commandes, setCommandes] = useState([]);
  const [enTraitement, setEnTraitement] = useState({});
  const [, forceRender] = useState(0);

  const chargerFile = useCallback(() => {
    client.get("cuisine/commandes/").then((res) => setCommandes(res.data));
  }, []);

  useEffect(() => {
    chargerFile();
    const idFile = setInterval(chargerFile, 15000); // resynchro légère en filet de sécurité
    const idHorloge = setInterval(() => forceRender((n) => n + 1), 20000); // rafraîchit les "il y a X min"
    return () => { clearInterval(idFile); clearInterval(idHorloge); };
  }, [chargerFile]);

  const { connecte } = useDashboardSocket("cuisine", (data) => {
    if (data.evenement === "commande_validee") {
      jouerNotification();
    }
    chargerFile();
  });

  async function demarrerPreparation(commandeId) {
    setEnTraitement((p) => ({ ...p, [commandeId]: true }));
    try {
      await client.patch(`cuisine/commandes/${commandeId}/preparer/`);
      chargerFile();
    } finally {
      setEnTraitement((p) => ({ ...p, [commandeId]: false }));
    }
  }

  async function marquerPrete(commandeId) {
    setEnTraitement((p) => ({ ...p, [commandeId]: true }));
    try {
      await client.patch(`cuisine/commandes/${commandeId}/prete/`);
      chargerFile();
    } finally {
      setEnTraitement((p) => ({ ...p, [commandeId]: false }));
    }
  }

  async function marquerServie(commandeId) {
    setEnTraitement((p) => ({ ...p, [commandeId]: true }));
    try {
      await client.patch(`commandes/${commandeId}/servie/`);
      setCommandes((prev) => prev.filter((c) => c.id !== commandeId));
    } finally {
      setEnTraitement((p) => ({ ...p, [commandeId]: false }));
    }
  }

  return (
    <div className="cuisine-dashboard">
      <PageHero
        icon="👨‍🍳"
        title="Rail de préparation — Cuisine"
        subtitle="Triées par ordre d'arrivée. En rouge : attente prolongée (+10 min)."
        live={connecte}
      />

      {commandes.length === 0 ? (
        <EmptyState
          icon="🍲"
          title="Rien à préparer pour le moment"
          subtitle="Les commandes validées par la caisse arriveront ici automatiquement."
        />
      ) : (
        <div className="rail">
          {commandes.map((cmd) => {
            const attente = minutesDepuis(cmd.date_validation || cmd.date_creation);
            const urgent = attente >= 10;
            const enPreparation = cmd.statut === "EN_PREPARATION";

            return (
              <div className={`k-ticket${urgent ? " urgent" : ""}${enPreparation ? " active" : ""}`} key={cmd.id}>
                <div className="k-ticket-top">
                  <span className="kid font-display">#{cmd.id}</span>
                  {enPreparation && <span className="k-tag">En cours</span>}
                  {cmd.statut === "PRETE" && <span className="k-tag k-tag-prete">Prête</span>}
                </div>

                <div className={`kwait${urgent ? " urgent-text" : ""}`}>
                  <span aria-hidden="true">{urgent ? "🔥" : "⏱️"}</span>
                  en attente depuis {attente} min
                </div>

                <ul className="font-mono">
                  {cmd.lignes.map((l) => (
                    <li key={l.id}>{l.quantite}x {l.plat_nom}{detailsLigne(l)}</li>
                  ))}
                </ul>

                {cmd.mode_commande === "SUR_PLACE" && (
                  cmd.numero_table?.trim() ? (
                    <div className="k-consigne k-consigne-livrer">
                      🚶 À apporter : <strong>{cmd.numero_table}</strong>
                    </div>
                  ) : (
                    <div className="k-consigne k-consigne-retrait">
                      🙋 Client viendra chercher lui-même
                    </div>
                  )
                )}

                {enPreparation ? (
                  <button
                    className="ready-btn"
                    onClick={() => marquerPrete(cmd.id)}
                    disabled={enTraitement[cmd.id]}
                  >
                    ✓ 
                    {enTraitement[cmd.id] ? "..." : "Marquer prête"}
                  </button>
                ) : cmd.statut === "PRETE" ? (
                  <button
                    className="ready-btn servie-btn"
                    onClick={() => marquerServie(cmd.id)}
                    disabled={enTraitement[cmd.id]}
                  >
                    {enTraitement[cmd.id] ? "..." : "✓ Marquer comme servie"}
                  </button>
                ) : (
                  <button
                    className="ready-btn start-btn"
                    onClick={() => demarrerPreparation(cmd.id)}
                    disabled={enTraitement[cmd.id]}
                  >
                    {enTraitement[cmd.id] ? "..." : "Démarrer la préparation"}
                  </button>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
