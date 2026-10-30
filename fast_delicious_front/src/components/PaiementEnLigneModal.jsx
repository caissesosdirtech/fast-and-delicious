import { useEffect, useRef, useState } from "react";
import { QRCodeSVG } from "qrcode.react";
import client from "../api/client";
import "./PaiementEnLigneModal.css";

const PROVIDERS = [
  { v: "WAVE", t: "🌊 Wave", couleur: "#1Dc8f2" },
  { v: "ORANGE_MONEY", t: "🟠 Orange Money", couleur: "#ff7900" },
];

/**
 * Demande un paiement en ligne (Wave / Orange Money) pour une commande, affiche
 * le QR code + le lien à présenter au client, et détecte automatiquement quand
 * la commande est payée (le backend la confirme via le webhook du fournisseur).
 *
 * props :
 *   commande    : la commande concernée
 *   onFermer()  : ferme la fenêtre
 *   onPaye()    : appelé quand le paiement est confirmé (pour rafraîchir la liste)
 */
export default function PaiementEnLigneModal({ commande, onFermer, onPaye }) {
  const [etape, setEtape] = useState("choix"); // choix | chargement | qr | paye | erreur
  const [provider, setProvider] = useState(null);
  const [paiement, setPaiement] = useState(null); // { payment_url, session_id }
  const [erreur, setErreur] = useState(null);
  const sondageRef = useRef(null);

  // Sonde l'état de la commande pour détecter la confirmation automatique.
  useEffect(() => {
    if (etape !== "qr") return;
    sondageRef.current = setInterval(async () => {
      try {
        const { data } = await client.get(`commandes/${commande.id}/`);
        if (data?.paiement_confirme) {
          clearInterval(sondageRef.current);
          setEtape("paye");
          if (onPaye) onPaye();
        }
      } catch {
        /* on réessaiera au prochain tour */
      }
    }, 4000);
    return () => clearInterval(sondageRef.current);
  }, [etape, commande.id, onPaye]);

  async function demander(prov) {
    setProvider(prov);
    setEtape("chargement");
    setErreur(null);
    try {
      const { data } = await client.post(`caisse/commandes/${commande.id}/paiement/`, {
        provider: prov,
      });
      if (!data?.payment_url) {
        throw new Error("Le fournisseur n'a pas renvoyé de lien de paiement.");
      }
      setPaiement(data);
      setEtape("qr");
    } catch (e) {
      const detail = e?.response?.data?.detail || e.message || "Erreur de paiement.";
      setErreur(detail);
      setEtape("erreur");
    }
  }

  return (
    <div className="pay-overlay" onClick={onFermer}>
      <div className="pay-modal" onClick={(e) => e.stopPropagation()}>
        <button className="pay-close" onClick={onFermer} aria-label="Fermer">✕</button>

        <h3>Paiement en ligne</h3>
        <p className="pay-sous">
          Commande <strong>#{commande.id}</strong> ·{" "}
          <strong>{Number(commande.total).toLocaleString("fr-FR")} F</strong>
        </p>

        {etape === "choix" && (
          <div className="pay-choix">
            <p className="pay-hint">Choisissez le moyen de paiement du client :</p>
            {PROVIDERS.map((p) => (
              <button
                key={p.v}
                className="pay-provider"
                style={{ borderColor: p.couleur }}
                onClick={() => demander(p.v)}
              >
                <span>{p.t}</span>
                <span className="pay-provider-fl">→</span>
              </button>
            ))}
          </div>
        )}

        {etape === "chargement" && (
          <div className="pay-centre">
            <div className="pay-spinner" />
            <p>Création de la demande de paiement…</p>
          </div>
        )}

        {etape === "qr" && paiement && (
          <div className="pay-centre">
            <p className="pay-hint">
              Le client scanne ce QR code avec{" "}
              {provider === "WAVE" ? "Wave" : "Orange Money"} :
            </p>
            <div className="pay-qr">
              <QRCodeSVG value={paiement.payment_url} size={220} level="M" includeMargin />
            </div>
            <a className="pay-lien" href={paiement.payment_url} target="_blank" rel="noreferrer">
              Ouvrir le lien de paiement
            </a>
            <div className="pay-attente">
              <div className="pay-dot" /> En attente du paiement du client…
            </div>
          </div>
        )}

        {etape === "paye" && (
          <div className="pay-centre">
            <div className="pay-ok">✅</div>
            <h4>Paiement reçu !</h4>
            <p className="pay-hint">La commande est maintenant marquée comme payée.</p>
            <button className="pay-btn" onClick={onFermer}>Terminer</button>
          </div>
        )}

        {etape === "erreur" && (
          <div className="pay-centre">
            <div className="pay-err">⚠️</div>
            <p className="pay-erreur-txt">{erreur}</p>
            <button className="pay-btn" onClick={() => setEtape("choix")}>Réessayer</button>
          </div>
        )}
      </div>
    </div>
  );
}
