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

const PAS_HISTORIQUE = 10; // nombre ajouté à chaque "Voir plus"

/**
 * Page "Commandes" de l'admin :
 *  - la liste des commandes EN COURS avec les actions (Valider → Prête → Terminer, Annuler, Reçu) ;
 *  - la liste des 10 dernières commandes TERMINÉES, avec un bouton "Voir plus".
 * L'admin a les mêmes droits que la caissière sur les endpoints caisse.
 */
export default function CommandesContenu() {
  const [commandes, setCommandes] = useState([]);
  const [charge, setCharge] = useState(false);
  const [enTraitement, setEnTraitement] = useState({});
  const [ticketOuvert, setTicketOuvert] = useState(null);

  const [historique, setHistorique] = useState([]);
  const [limiteHisto, setLimiteHisto] = useState(PAS_HISTORIQUE);

  const chargerEnCours = useCallback(() => {
    client.get("caisse/commandes/").then((r) => {
      setCommandes(r.data);
      setCharge(true);
    });
  }, []);

  const chargerHistorique = useCallback((limite) => {
    client.get(`caisse/historique-recent/?limite=${limite}`).then((r) => setHistorique(r.data));
  }, []);

  // Chargement initial + rafraîchissement périodique des commandes en cours.
  useEffect(() => {
    chargerEnCours();
    const id = setInterval(chargerEnCours, 20000);
    return () => clearInterval(id);
  }, [chargerEnCours]);

  // (Re)charge l'historique quand la limite change (dont "Voir plus").
  useEffect(() => {
    chargerHistorique(limiteHisto);
  }, [chargerHistorique, limiteHisto]);

  function rafraichir() {
    chargerEnCours();
    chargerHistorique(limiteHisto);
  }

  async function action(id, url) {
    setEnTraitement((p) => ({ ...p, [id]: true }));
    try {
      await client.patch(url);
      rafraichir();
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
      rafraichir();
    } finally {
      setEnTraitement((p) => ({ ...p, [id]: false }));
    }
  }

  if (!charge) return <p className="chargement-texte">Chargement...</p>;

  // S'il y a autant d'éléments que la limite demandée, il y en a probablement d'autres à charger.
  const peutVoirPlus = historique.length >= limiteHisto && limiteHisto < 100;

  return (
    <>
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
                  {cmd.lieu_nom && <span className="cmd-lieu">📍 {cmd.lieu_nom}</span>}
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
      </div>

      <div className="admin-panel admin-panel-wide">
        <h3>Dernières commandes terminées</h3>

        {historique.length === 0 ? (
          <EmptyState icon="🧾" title="Aucune commande terminée pour le moment" />
        ) : (
          <>
            <div className="histo-liste">
              {historique.map((cmd) => (
                <div className="histo-row" key={cmd.id} onClick={() => setTicketOuvert(cmd)}>
                  <span className="font-mono">#{cmd.id}</span>
                  <span className="histo-articles">
                    {Array.isArray(cmd.lignes) ? cmd.lignes.map((l) => `${l.quantite}x ${l.plat_nom}`).join(", ") : "—"}
                  </span>
                  <span className={`recent-badge statut-${COULEUR_STATUT[cmd.statut] || "ink"}`}>
                    {LABELS_STATUT[cmd.statut] || cmd.statut}
                  </span>
                  <span className="font-mono histo-total">{Number(cmd.total || 0).toLocaleString("fr-FR")} F</span>
                </div>
              ))}
            </div>

            {peutVoirPlus && (
              <button className="histo-voir-plus" onClick={() => setLimiteHisto((l) => l + PAS_HISTORIQUE)}>
                Voir plus
              </button>
            )}
          </>
        )}
      </div>

      {ticketOuvert && <TicketModal commande={ticketOuvert} onFermer={() => setTicketOuvert(null)} />}
    </>
  );
}
