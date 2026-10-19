import { useNavigate } from "react-router-dom";
import { useCart } from "../context/CartContext";
import { CODE_MARCHAND_ORANGE_MONEY, LIEN_PAIEMENT_PAR_MODE, QR_PAR_MODE } from "../config/paiement";
import "./CartDrawer.css";

export default function CartDrawer() {
  const {
    lignes, totalPrix, modifierQuantite,
    panierOuvert, setPanierOuvert,
    modePaiement, setModePaiement,
    referencePaiement, setReferencePaiement,
    passerCommande, envoiEnCours, erreurCommande,
  } = useCart();
  const navigate = useNavigate();

  if (!panierOuvert) return null;

  async function confirmer() {
    const commande = await passerCommande();
    if (commande) navigate(`/suivi/${commande.id}`);
  }

  function copierCodeMarchand() {
    navigator.clipboard?.writeText(CODE_MARCHAND_ORANGE_MONEY);
  }

  return (
    <div className="cart-overlay" onClick={() => setPanierOuvert(false)}>
      <div className="cart-drawer" onClick={(e) => e.stopPropagation()}>
        <div className="cart-drawer-head">
          <h2 className="font-display">Votre panier</h2>
          <button className="cart-close" onClick={() => setPanierOuvert(false)} aria-label="Fermer">✕</button>
        </div>

        {lignes.length === 0 ? (
          <div className="cart-drawer-empty">Votre panier est vide pour le moment.</div>
        ) : (
          <div className="cart-drawer-list">
            {lignes.map(({ cle, plat, quantite, accompagnementId, accompagnementNom, selections }) => (
              <div className="cart-drawer-item" key={cle}>
                <div className="cart-drawer-item-info">
                  <div className="cdi-name">{plat.nom}</div>
                  {accompagnementNom && (
                    <div className="cdi-accompagnement">+ {accompagnementNom}</div>
                  )}
                  {selections?.length > 0 && (
                    <div className="cdi-selections">
                      {selections.map((s) => `${s.groupeNom} : ${s.optionNom}`).join(" · ")}
                    </div>
                  )}
                  <div className="cdi-price font-mono">{Number(plat.prix).toLocaleString("fr-FR")} F</div>
                </div>
                <div className="qty-stepper">
                  <button
                    onClick={() => modifierQuantite(plat, -1, {
                      accompagnement: accompagnementId ? { id: accompagnementId } : null,
                      selections,
                    })}
                    aria-label="Retirer un"
                  >−</button>
                  <span className="font-mono">{quantite}</span>
                  <button
                    onClick={() => modifierQuantite(plat, 1, {
                      accompagnement: accompagnementId ? { id: accompagnementId, nom: accompagnementNom } : null,
                      selections,
                    })}
                    aria-label="Ajouter un"
                  >+</button>
                </div>
              </div>
            ))}
          </div>
        )}

        {erreurCommande && <div className="cart-drawer-erreur">{erreurCommande}</div>}

        {lignes.length > 0 && (
          <div className="paiement-section">
            <label className="paiement-titre">Mode de paiement</label>
            <div className="paiement-toggle paiement-toggle-4">
              <button
                className={modePaiement === "ESPECES" ? "active" : ""}
                onClick={() => setModePaiement("ESPECES")}
              >
                💵 Espèces
              </button>
              <button
                className={modePaiement === "PI_MIX" ? "active" : ""}
                onClick={() => setModePaiement("PI_MIX")}
              >
                🔷 QR universel
              </button>
              <button
                className={modePaiement === "WAVE" ? "active" : ""}
                onClick={() => setModePaiement("WAVE")}
              >
                🌊 Wave
              </button>
              <button
                className={modePaiement === "ORANGE_MONEY" ? "active" : ""}
                onClick={() => setModePaiement("ORANGE_MONEY")}
              >
                🟠 Orange Money
              </button>
            </div>

            {modePaiement === "PI_MIX" && (
              <div className="paiement-mobile-money">
                <div className="pmm-conseil">
                  ✨ Recommandé : scanne avec n'importe quelle app (Wave, Orange Money, ta banque...)
                </div>
                <img className="pmm-qr" src={QR_PAR_MODE.PI_MIX} alt="QR code de paiement universel" />
                <div className="pmm-note-scan">
                  📷 Ce QR doit être scanné à la caméra — si tu commandes depuis ce même téléphone,
                  demande à quelqu'un d'autre de le scanner, ou choisis Wave/Orange Money ci-dessus
                  pour ouvrir l'app directement.
                </div>
                <div className="pmm-montant-a-payer">
                  Montant à envoyer : <strong>{totalPrix.toLocaleString("fr-FR")} FCFA</strong>
                </div>
                <input
                  className="pmm-reference-input"
                  placeholder="Référence de la transaction *"
                  value={referencePaiement}
                  onChange={(e) => setReferencePaiement(e.target.value)}
                />
                <div className="pmm-note">
                  La caissière vérifiera la réception avant de valider ta commande.
                </div>
              </div>
            )}

            {modePaiement === "WAVE" && (
              <div className="paiement-mobile-money">
                <a
                  className="pmm-ouvrir-app"
                  href={LIEN_PAIEMENT_PAR_MODE.WAVE}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  📱 Ouvrir directement dans l'app Wave
                </a>
                <div className="pmm-ou">— ou scanne le QR —</div>
                <img className="pmm-qr" src={QR_PAR_MODE.WAVE} alt="QR code Wave" />
                <div className="pmm-montant-a-payer">
                  Montant à envoyer : <strong>{totalPrix.toLocaleString("fr-FR")} FCFA</strong>
                </div>
                <input
                  className="pmm-reference-input"
                  placeholder="Référence de la transaction *"
                  value={referencePaiement}
                  onChange={(e) => setReferencePaiement(e.target.value)}
                />
                <div className="pmm-note">
                  La caissière vérifiera la réception avant de valider ta commande.
                </div>
              </div>
            )}

            {modePaiement === "ORANGE_MONEY" && (
              <div className="paiement-mobile-money">
                <a
                  className="pmm-ouvrir-app pmm-ouvrir-app-om"
                  href={LIEN_PAIEMENT_PAR_MODE.ORANGE_MONEY}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  📱 Ouvrir directement dans l'app Orange Money
                </a>
                <div className="pmm-ou">— ou scanne le QR, ou entre le code marchand —</div>
                <img className="pmm-qr" src={QR_PAR_MODE.ORANGE_MONEY} alt="QR code Orange Money" />
                <div className="pmm-numero-row">
                  <div>
                    <div className="pmm-label">Code marchand :</div>
                    <div className="pmm-numero font-mono">{CODE_MARCHAND_ORANGE_MONEY}</div>
                  </div>
                  <button className="pmm-copy" onClick={copierCodeMarchand}>📋 Copier</button>
                </div>
                <div className="pmm-montant-a-payer">
                  Montant à envoyer : <strong>{totalPrix.toLocaleString("fr-FR")} FCFA</strong>
                </div>
                <input
                  className="pmm-reference-input"
                  placeholder="Référence de la transaction *"
                  value={referencePaiement}
                  onChange={(e) => setReferencePaiement(e.target.value)}
                />
                <div className="pmm-note">
                  La caissière vérifiera la réception avant de valider ta commande.
                </div>
              </div>
            )}
          </div>
        )}

        {lignes.length > 0 && (
          <div className="cart-drawer-footer">
            <div className="cart-drawer-total">
              <span>Total</span>
              <span className="font-mono">{totalPrix.toLocaleString("fr-FR")} FCFA</span>
            </div>
            <button className="order-btn" onClick={confirmer} disabled={envoiEnCours}>
              {envoiEnCours ? "Envoi..." : "Confirmer la commande →"}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
