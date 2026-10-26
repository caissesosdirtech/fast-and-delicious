import { useEffect, useState } from "react";
import { useParams } from "react-router-dom";
import client from "../api/client";
import { useCommandeSocket } from "../hooks/useCommandeSocket";
import Stepper from "../components/Stepper";
import TimerRestant from "../components/TimerRestant";
import PageHero from "../components/PageHero";
import { detailsLigne } from "../utils/ligne";
import { jouerNotification } from "../utils/son";
import "./ClientSuivi.css";

const INFOS_STATUT = {
  EN_ATTENTE: { label: "En attente de validation", couleur: "gold" },
  VALIDEE: { label: "Validée, en attente de préparation", couleur: "gold" },
  EN_PREPARATION: { label: "En préparation", couleur: "gold" },
  EN_LIVRAISON: { label: "En route vers chez vous 🛵", couleur: "green" },
  SERVIE: { label: "Livrée — merci et bon appétit", couleur: "green" },
  ANNULEE: { label: "Commande annulée", couleur: "red" },
};

const STATUTS_SONORES = ["PRETE", "EN_LIVRAISON", "SERVIE"];

export default function ClientSuivi() {
  const { id } = useParams();
  const [commande, setCommande] = useState(null);
  const [erreur, setErreur] = useState(null);
  const [annulationEnCours, setAnnulationEnCours] = useState(false);

  useEffect(() => {
    client
      .get(`commandes/${id}/`)
      .then((res) => setCommande(res.data))
      .catch(() => setErreur("Commande introuvable."));
  }, [id]);

  // Se resynchronise en direct via WebSocket dès qu'un changement de statut survient.
  const { donnees, connecte } = useCommandeSocket(id);

  useEffect(() => {
    if (donnees) {
      setCommande((prev) => (prev ? { ...prev, ...donnees } : prev));
      if (STATUTS_SONORES.includes(donnees.statut)) {
        jouerNotification();
      }
    }
  }, [donnees]);

  async function annulerCommande() {
    if (!window.confirm("Es-tu sûr de vouloir annuler cette commande ?")) return;
    setAnnulationEnCours(true);
    try {
      const { data } = await client.patch(`commandes/${id}/annuler/`);
      setCommande(data);
    } catch {
      window.alert("Impossible d'annuler : la commande a peut-être déjà été prise en charge.");
    } finally {
      setAnnulationEnCours(false);
    }
  }

  if (erreur) {
    return (
      <div className="suivi-etat">
        <span style={{ fontSize: 28 }} aria-hidden="true">⚠️</span>
        <p>{erreur}</p>
      </div>
    );
  }

  if (!commande) {
    return <div className="suivi-etat">Chargement...</div>;
  }

  const enLivraison = commande.mode_commande === "LIVRAISON";
  const aTable = !enLivraison && commande.numero_table && commande.numero_table.trim();

  let infoStatut;
  if (commande.statut === "PRETE" && enLivraison) {
    // Pour une livraison, on saute l'étape "venez récupérer" : dès que c'est prêt,
    // le client doit comprendre que ça part en livraison, pas qu'il doit venir le chercher.
    infoStatut = { label: "En route vers chez vous 🛵", couleur: "green" };
  } else if (commande.statut === "PRETE") {
    infoStatut = aTable
      ? { label: `Votre commande sera livrée à ${commande.numero_table} 🚶`, couleur: "green" }
      : { label: "Prête ! Venez la récupérer", couleur: "green" };
  } else {
    infoStatut = INFOS_STATUT[commande.statut] || { label: commande.statut, couleur: "gold" };
  }

  return (
    <div className="client-suivi">
      <div className="no-print">
        <PageHero
          icon="📋"
          title="Suivi de commande"
          subtitle="Mise à jour en direct — pas besoin de rafraîchir."
          live={connecte}
        />
      </div>

      <div className="ticket-wrap">
        <div className="ticket">
          <div className="ticket-head">
            <h2 className="font-display">TICKET N°{commande.id}</h2>
            <div className="sub font-mono">
              {enLivraison
                ? "🛵 Livraison"
                : (commande.numero_table && `${commande.numero_table} — `)}
              {new Date(commande.date_creation).toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" })}
            </div>
            {enLivraison && (
              <div className="sub font-mono" style={{ marginTop: 4 }}>
                📍 {commande.adresse_livraison} · 📞 {commande.telephone_client}
              </div>
            )}
            {commande.mode_paiement !== "ESPECES" && (
              <div className="sub font-mono" style={{ marginTop: 4 }}>
                {commande.mode_paiement === "WAVE" ? "🌊 Wave" : "🟠 Orange Money"} · réf. {commande.reference_paiement}
              </div>
            )}
            {!enLivraison && !aTable && ["EN_ATTENTE", "VALIDEE", "EN_PREPARATION"].includes(commande.statut) && (
              <div className="ticket-rappel-table">
                💡 Pas de table indiquée — tu devras venir récupérer ta commande toi-même.
              </div>
            )}
          </div>

          <div className="ticket-lines">
            {commande.lignes.map((ligne) => (
              <div className="ticket-line font-mono" key={ligne.id}>
                <span>{ligne.quantite}x {ligne.plat_nom}{detailsLigne(ligne)}</span>
                <span>{Number(ligne.sous_total).toLocaleString("fr-FR")} F</span>
              </div>
            ))}
          </div>

          <div className="divider" />
          <div className="ticket-line font-mono ticket-total">
            <span>TOTAL</span>
            <span>{Number(commande.total).toLocaleString("fr-FR")} F</span>
          </div>

          <Stepper statutActuel={commande.statut} modeCommande={commande.mode_commande} />

          <div className={`stamp font-display stamp-${infoStatut.couleur}`}>
            {infoStatut.label}
          </div>
        </div>
      </div>

      {["VALIDEE", "EN_PREPARATION"].includes(commande.statut) && (
        <div className="no-print">
          <TimerRestant minutesRestantes={commande.temps_restant_estime_min} />
        </div>
      )}

      <div className="imprimer-wrap no-print">
        <button className="imprimer-btn" onClick={() => window.print()}>
          💾 Enregistrer le ticket
        </button>
      </div>

      {commande.statut === "EN_ATTENTE" && (
        <div className="annulation-wrap no-print">
          <button className="annulation-btn" onClick={annulerCommande} disabled={annulationEnCours}>
            {annulationEnCours ? "Annulation..." : "Annuler ma commande"}
          </button>
        </div>
      )}
    </div>
  );
}
