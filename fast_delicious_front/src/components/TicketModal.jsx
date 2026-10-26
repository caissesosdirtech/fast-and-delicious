import { useAuth } from "../context/AuthContext";
import { detailsLigne } from "../utils/ligne";
import "./TicketModal.css";

const LABELS_STATUT = {
  EN_ATTENTE: "En attente", VALIDEE: "Validée", EN_PREPARATION: "En préparation",
  PRETE: "Prête", EN_LIVRAISON: "En livraison", SERVIE: "Servie", ANNULEE: "Annulée",
};

/**
 * Ticket complet en lecture seule, accessible à l'admin et à la caissière depuis n'importe
 * quelle liste de commandes (historique, paiements, commandes récentes...).
 * Le bouton d'impression n'apparaît que pour la caissière, et seulement une fois la commande servie.
 */
export default function TicketModal({ commande, onFermer }) {
  const { utilisateur } = useAuth();
  const estStaff = utilisateur?.role === "caissiere" || utilisateur?.role === "admin";
  const peutImprimer = estStaff && (commande.statut === "SERVIE" || commande.paiement_confirme);

  return (
    <div className="ticket-modal-overlay" onClick={onFermer}>
      <div className="ticket-modal" onClick={(e) => e.stopPropagation()}>
        <button className="ticket-modal-fermer" onClick={onFermer}>✕</button>

        <div id="ticket-a-imprimer">
          <h3 className="ticket-modal-titre">Reçu de paiement #{commande.id}</h3>
          <div className="ticket-modal-sub">
            {commande.mode_commande === "LIVRAISON" ? "🛵 Livraison" : (commande.numero_table ? `Table ${commande.numero_table}` : "Retrait sur place")}
            {" — "}
            {new Date(commande.date_creation).toLocaleString("fr-FR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" })}
          </div>

          {commande.lieu_nom && (
            <div className="ticket-modal-sub">📍 {commande.lieu_nom}</div>
          )}

          {commande.mode_commande === "LIVRAISON" && (
            <div className="ticket-modal-sub">📍 {commande.adresse_livraison} · 📞 {commande.telephone_client}</div>
          )}

          <div className="ticket-modal-lignes">
            {commande.lignes.map((l) => (
              <div className="ticket-modal-ligne" key={l.id}>
                <span>{l.quantite}x {l.plat_nom}{detailsLigne(l)}</span>
                <span>{Number(l.sous_total).toLocaleString("fr-FR")} F</span>
              </div>
            ))}
          </div>

          {commande.remarque && <div className="ticket-modal-remarque">Remarque client : {commande.remarque}</div>}

          {commande.mode_paiement !== "ESPECES" && (
            <div className="ticket-modal-paiement">
              {commande.mode_paiement === "WAVE" ? "🌊 Wave" : commande.mode_paiement === "ORANGE_MONEY" ? "🟠 Orange Money" : "🔷 QR universel"}
              {" · réf. "}{commande.reference_paiement}
            </div>
          )}

          {commande.statut === "ANNULEE" && commande.motif_annulation && (
            <div className="ticket-modal-motif">Motif d'annulation : {commande.motif_annulation}</div>
          )}

          <div className="ticket-modal-divider" />
          <div className="ticket-modal-total">
            <span>TOTAL</span>
            <span>{Number(commande.total).toLocaleString("fr-FR")} FCFA</span>
          </div>

          <div className={`ticket-modal-statut statut-${commande.statut.toLowerCase()}`}>
            {LABELS_STATUT[commande.statut] || commande.statut}
          </div>

          <div className="ticket-modal-footer">
            <div className="ticket-modal-merci">Merci de votre visite 🙏</div>
            <div className="ticket-modal-infos ticket-modal-event">JOJ Dakar 2026</div>
          </div>
        </div>

        {peutImprimer && (
          <button className="ticket-modal-imprimer" onClick={() => window.print()}>
            🖨️ Imprimer le reçu
          </button>
        )}
      </div>
    </div>
  );
}
