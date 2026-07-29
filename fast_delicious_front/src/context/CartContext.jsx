import { createContext, useContext, useMemo, useState } from "react";
import client from "../api/client";

const CartContext = createContext(null);

function cleLigne(platId, accompagnementId, selections = []) {
  const selKey = [...selections]
    .sort((a, b) => a.groupeId - b.groupeId)
    .map((s) => `${s.groupeId}:${s.optionId}`)
    .join(",");
  return `${platId}::${accompagnementId ?? "none"}::${selKey}`;
}

export function CartProvider({ children }) {
  // panier : { [cle]: { plat, quantite, accompagnementId, accompagnementNom, selections } }
  const [panier, setPanier] = useState({});
  const [numeroTable, setNumeroTable] = useState("");
  const [modeCommande, setModeCommande] = useState("SUR_PLACE"); // "SUR_PLACE" | "LIVRAISON"
  const [lieu, setLieu] = useState(""); // id du lieu choisi, "" si un seul lieu (ou aucun) configuré
  const [adresseLivraison, setAdresseLivraison] = useState("");
  const [telephoneClient, setTelephoneClient] = useState("");
  const [modePaiement, setModePaiement] = useState("ESPECES"); // "ESPECES" | "WAVE" | "ORANGE_MONEY"
  const [referencePaiement, setReferencePaiement] = useState("");
  const [panierOuvert, setPanierOuvert] = useState(false);
  const [envoiEnCours, setEnvoiEnCours] = useState(false);
  const [erreurCommande, setErreurCommande] = useState(null);

  /**
   * Ajoute/retire une unité d'un plat.
   * `options.accompagnement` : { id, nom } | null — système simple (un seul accompagnement).
   * `options.selections` : [{ groupeId, groupeNom, optionId, optionNom }] — système des formules composées.
   */
  function modifierQuantite(plat, delta, options = {}) {
    const { accompagnement = null, selections = [] } = options;
    const cle = cleLigne(plat.id, accompagnement?.id, selections);
    setPanier((prev) => {
      const existant = prev[cle];
      const nouvelleQuantite = (existant?.quantite || 0) + delta;
      if (nouvelleQuantite <= 0) {
        const { [cle]: _, ...reste } = prev;
        return reste;
      }
      return {
        ...prev,
        [cle]: {
          plat,
          quantite: nouvelleQuantite,
          accompagnementId: accompagnement?.id ?? null,
          accompagnementNom: accompagnement?.nom ?? null,
          selections,
        },
      };
    });
  }

  function quantitePourPlat(platId) {
    return Object.values(panier)
      .filter((l) => l.plat.id === platId)
      .reduce((acc, l) => acc + l.quantite, 0);
  }

  function viderPanier() {
    setPanier({});
  }

  const lignes = useMemo(
    () => Object.entries(panier).map(([cle, l]) => ({ cle, ...l })),
    [panier]
  );
  const totalArticles = lignes.reduce((acc, l) => acc + l.quantite, 0);
  const totalPrix = lignes.reduce((acc, l) => acc + l.quantite * Number(l.plat.prix), 0);

  async function passerCommande() {
    setErreurCommande(null);
    if (lignes.length === 0) return null;

    if (modeCommande === "LIVRAISON") {
      if (!adresseLivraison.trim()) {
        setErreurCommande("Merci d'indiquer une adresse de livraison.");
        return null;
      }
      if (!telephoneClient.trim()) {
        setErreurCommande("Merci d'indiquer un numéro de téléphone.");
        return null;
      }
    }

    if (modePaiement !== "ESPECES" && !referencePaiement.trim()) {
      setErreurCommande("Merci d'indiquer la référence de ta transaction Wave/Orange Money.");
      return null;
    }

    setEnvoiEnCours(true);
    try {
      const { data } = await client.post("commandes/", {
        numero_table: numeroTable,
        mode_commande: modeCommande,
        ...(lieu ? { lieu } : {}),
        mode_paiement: modePaiement,
        ...(modePaiement !== "ESPECES" ? { reference_paiement: referencePaiement } : {}),
        ...(modeCommande === "LIVRAISON"
          ? { adresse_livraison: adresseLivraison, telephone_client: telephoneClient }
          : {}),
        lignes: lignes.map((l) => ({
          plat_id: l.plat.id,
          quantite: l.quantite,
          ...(l.accompagnementId ? { accompagnement_id: l.accompagnementId } : {}),
          ...(l.selections?.length
            ? { selections: l.selections.map((s) => ({ groupe_id: s.groupeId, option_id: s.optionId })) }
            : {}),
        })),
      });
      viderPanier();
      setReferencePaiement("");
      setPanierOuvert(false);
      return data;
    } catch (e) {
      const reponse = e?.response?.data;
      const detail =
        reponse?.lignes?.[0]?.non_field_errors?.[0] ||
        reponse?.adresse_livraison?.[0] ||
        reponse?.telephone_client?.[0] ||
        reponse?.reference_paiement?.[0];
      setErreurCommande(detail || "La commande n'a pas pu être envoyée. Réessayez.");
      return null;
    } finally {
      setEnvoiEnCours(false);
    }
  }

  return (
    <CartContext.Provider
      value={{
        panier, lignes, totalArticles, totalPrix,
        numeroTable, setNumeroTable,
        modeCommande, setModeCommande,
        lieu, setLieu,
        adresseLivraison, setAdresseLivraison,
        telephoneClient, setTelephoneClient,
        modePaiement, setModePaiement,
        referencePaiement, setReferencePaiement,
        panierOuvert, setPanierOuvert,
        modifierQuantite, quantitePourPlat, viderPanier,
        passerCommande, envoiEnCours, erreurCommande,
      }}
    >
      {children}
    </CartContext.Provider>
  );
}

export function useCart() {
  return useContext(CartContext);
}
