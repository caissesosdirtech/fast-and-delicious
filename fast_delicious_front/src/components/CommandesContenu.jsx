import { useCallback, useEffect, useState } from "react";
import client from "../api/client";
import EmptyState from "./EmptyState";
import TicketModal from "./TicketModal";

const LABELS_STATUT = {
  EN_ATTENTE: "En attente", VALIDEE: "Validée", EN_PREPARATION: "En préparation",
  PRETE: "Prête", EN_LIVRAISON: "En livraison", SERVIE: "Servie", ANNULEE: "Annulée",
};
const COULEUR_STATUT = {
  EN_ATTENTE: "gold", VALIDEE: "gold", EN_PREPARATION: "gold",
  PRETE: "green", EN_LIVRAISON: "green", SERVIE: "ink", ANNULEE: "red",
};

/**
 * Page "Commandes" de l'admin : la liste des commandes en cours avec les actions du
 * parcours simplifié (Valider → Prête → Terminer), l'annulation et le reçu de paiement.
 * L'admin a les mêmes droits que la caissière sur les endpoints caisse.
 */
export default function CommandesContenu() {
  const [commandes, setCommandes] = useState([]);
  const [charge, setCharge] = useState(false);
  const [enTraitement, setEnTraitement] = useState({});
  const [ticketOuvert, setTicketOuvert] = useState(null);

  const charger = useCallback(() => {
    client.get("caisse/commandes/").then((r) => {
      setCommandes(r.data);
      setCharge(true);
    });
  }, []);

  useEffect(() => {
    charger();
    const id = setInterval(charger, 20000);
    return () => clearInterval(id);
  }, [charger]);

  async function action(id, url) {
    setEnTraitement((p) => ({ ...p, [id]: true }));
    try {
      await client.patch(url);
      charger();
    } finally {
      setEnTraitement((p) => ({ ...p, [id]: false }));
    }
  }

  const valider = (id) => action(id, `caisse/commandes/${id}/valider/`);
  const prete = (id) => action(id, `caisse/commandes/${id}/prete/`);
  const terminer = (id) => action(id, `caisse/commandes/${id}/terminer/`);

  async function annuler(id) {
    const motif = window.prompt("Motif de l'annulation (ex: Référence de paiement invalide) :");
    if (motif === null) return;
    setEnTraitement((p) => ({ ...p, [id]: true }));
    try {
      await client.patch(`commandes/${id}/annuler/`, { motif });
      charger();
    } finally {
      setEnTraitement((p) => ({ ...p, [id]: false }));
    }
  }

  if (!charge) return <p className="chargement-texte">Chargement...</p>;

  return (
    <div className="admin-panel admin-panel-wide">
      <h3>Commandes en cours</h3>

      {commandes.length === 0 ? (
        <EmptyState icon="📥" title="Aucune commande en cours" />
      ) : (
        <div className="cmd-liste">
          {commandes.map((cmd) => (
            <div className="cmd-carte" key={cmd.id}>
              <div className="cmd-carte-tete">
                <span className="font-mono cmd-num">#{cmd.id}</span>
                <span className="cmd-table">
                  {cmd.mode_commande === "LIVRAISON"
                    ? "🛵 Livraison"
                    : (cmd.numero_table ? `Table ${cmd.numero_table}` : "Sur place")}
                </span>
                <span className={`recent-badge statut-${COULEUR_STATUT[cmd.statut]}`}>
                  {LABELS_STATUT[cmd.statut] || cmd.statut}
                </span>
                <span className="font-mono cmd-total">
                  {Number(cmd.total).toLocaleString("fr-FR")} F
                </span>
              </div>

              <div className="cmd-articles">
                {cmd.lignes.map((l) => `${l.quantite}x ${l.plat_nom}`).join(", ")}
              </div>

              <div className="cmd-actions">
                {cmd.statut === "EN_ATTENTE" && (
                  <button className="cmd-btn cmd-btn-vert" disabled={enTraitement[cmd.id]} onClick={() => valider(cmd.id)}>✓ Valider</button>
                )}
                {cmd.statut === "VALIDEE" && (
                  <button className="cmd-btn cmd-btn-vert" disabled={enTraitement[cmd.id]} onClick={() => prete(cmd.id)}>▶ Marquer prête</button>
                )}
                {cmd.statut === "PRETE" && (
                  <button className="cmd-btn cmd-btn-vert" disabled={enTraitement[cmd.id]} onClick={() => terminer(cmd.id)}>✔ Terminer</button>
                )}
                {(cmd.paiement_confirme || cmd.statut === "SERVIE") && (
                  <button className="cmd-btn cmd-btn-recu" onClick={() => setTicketOuvert(cmd)}>🧾 Reçu</button>
                )}
                {cmd.statut !== "SERVIE" && cmd.statut !== "ANNULEE" && (
                  <button className="cmd-btn cmd-btn-rouge" disabled={enTraitement[cmd.id]} onClick={() => annuler(cmd.id)}>✕ Annuler</button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {ticketOuvert && <TicketModal commande={ticketOuvert} onFermer={() => setTicketOuvert(null)} />}
    </div>
  );
}
