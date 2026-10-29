import { useEffect, useMemo, useState } from "react";
import client from "../api/client";
import EmptyState from "./EmptyState";
import { photoLocalePlat } from "../data/photosPlats";
import "./AdminContenus.css";
import "./VenteDirecteContenu.css";

/**
 * Vente directe (caisse au comptoir).
 *
 * La caissière ouvre cette rubrique quand un client se présente à la boutique :
 * elle cherche les produits (recherche intelligente + filtre catégorie), les
 * ajoute au panier, choisit le mode de paiement, encaisse l'argent, puis valide.
 * La commande est alors enregistrée automatiquement comme déjà payée et servie
 * via POST /api/caisse/vente-directe/.
 */
export default function VenteDirecteContenu() {
  const [plats, setPlats] = useState([]);
  const [categories, setCategories] = useState([]);
  const [chargement, setChargement] = useState(true);

  const [recherche, setRecherche] = useState("");
  const [filtreCategorie, setFiltreCategorie] = useState("toutes");

  // Panier : liste de lignes { cle, plat, quantite, accompagnement, selections }
  const [panier, setPanier] = useState([]);

  // Produit en cours de configuration (accompagnement / groupes de choix) avant ajout
  const [platAConfigurer, setPlatAConfigurer] = useState(null);

  const [modePaiement, setModePaiement] = useState("ESPECES");
  const [referencePaiement, setReferencePaiement] = useState("");
  const [numeroTable, setNumeroTable] = useState("");

  const [envoiEnCours, setEnvoiEnCours] = useState(false);
  const [erreur, setErreur] = useState(null);
  const [confirmation, setConfirmation] = useState(null); // commande créée

  function charger() {
    setChargement(true);
    Promise.all([client.get("menu/plats/"), client.get("menu/categories/")])
      .then(([p, c]) => {
        setPlats(p.data);
        setCategories(c.data);
      })
      .catch((e) => console.error("Erreur chargement vente directe :", e))
      .finally(() => setChargement(false));
  }

  useEffect(() => {
    charger();
  }, []);

  function nomCategorie(id) {
    return categories.find((c) => c.id === id)?.nom || "—";
  }

  // Recherche tolérante aux accents / casse.
  function normaliser(t) {
    return (t || "")
      .toString()
      .toLowerCase()
      .normalize("NFD")
      .replace(/[̀-ͯ]/g, "");
  }

  const texteRecherche = normaliser(recherche).trim();
  const platsFiltres = plats.filter((p) => {
    if (!p.disponible) return false;
    const matchCat =
      filtreCategorie === "toutes" ||
      String(p.categorie) === String(filtreCategorie);
    if (!matchCat) return false;
    if (!texteRecherche) return true;
    const cible = normaliser(
      `${p.nom} ${p.description || ""} ${nomCategorie(p.categorie)}`
    );
    return cible.includes(texteRecherche);
  });

  // Un plat a-t-il besoin d'une configuration avant ajout ?
  function necessiteConfiguration(plat) {
    return (
      (plat.accompagnements && plat.accompagnements.length > 0) ||
      (plat.groupes_choix && plat.groupes_choix.length > 0)
    );
  }

  // Clé unique représentant une ligne (plat + options choisies), pour fusionner les doublons.
  function cleLigne(platId, accompagnementId, selections) {
    const sel = [...(selections || [])]
      .map((s) => `${s.groupe_id}:${s.option_id}`)
      .sort()
      .join(",");
    return `${platId}|a${accompagnementId || 0}|${sel}`;
  }

  function ajouterAuPanier(plat, accompagnement, selections) {
    const cle = cleLigne(plat.id, accompagnement?.id, selections);
    setPanier((prev) => {
      const existante = prev.find((l) => l.cle === cle);
      if (existante) {
        return prev.map((l) =>
          l.cle === cle ? { ...l, quantite: l.quantite + 1 } : l
        );
      }
      return [
        ...prev,
        {
          cle,
          plat,
          quantite: 1,
          accompagnement: accompagnement || null,
          selections: selections || [],
        },
      ];
    });
  }

  function cliquerProduit(plat) {
    setErreur(null);
    if (necessiteConfiguration(plat)) {
      setPlatAConfigurer(plat);
    } else {
      ajouterAuPanier(plat, null, []);
    }
  }

  function changerQuantite(cle, delta) {
    setPanier((prev) =>
      prev
        .map((l) =>
          l.cle === cle ? { ...l, quantite: l.quantite + delta } : l
        )
        .filter((l) => l.quantite > 0)
    );
  }

  function retirerLigne(cle) {
    setPanier((prev) => prev.filter((l) => l.cle !== cle));
  }

  function viderPanier() {
    setPanier([]);
    setReferencePaiement("");
    setNumeroTable("");
    setModePaiement("ESPECES");
  }

  const total = useMemo(
    () =>
      panier.reduce(
        (somme, l) => somme + Number(l.plat.prix) * l.quantite,
        0
      ),
    [panier]
  );
  const nombreArticles = useMemo(
    () => panier.reduce((n, l) => n + l.quantite, 0),
    [panier]
  );

  async function encaisser() {
    if (panier.length === 0) return;
    setErreur(null);
    setEnvoiEnCours(true);

    const lignes = panier.map((l) => {
      const ligne = { plat_id: l.plat.id, quantite: l.quantite };
      if (l.accompagnement) ligne.accompagnement_id = l.accompagnement.id;
      if (l.selections && l.selections.length > 0) {
        ligne.selections = l.selections.map((s) => ({
          groupe_id: s.groupe_id,
          option_id: s.option_id,
        }));
      }
      return ligne;
    });

    const payload = {
      lignes,
      mode_paiement: modePaiement,
      numero_table: numeroTable.trim(),
      reference_paiement: referencePaiement.trim(),
    };

    try {
      const { data } = await client.post("caisse/vente-directe/", payload);
      setConfirmation(data);
      viderPanier();
    } catch (e) {
      console.error("Erreur vente directe :", e);
      const data = e?.response?.data;
      if (data) {
        setErreur(
          typeof data === "object"
            ? Object.entries(data)
                .map(
                  ([champ, messages]) =>
                    `${champ}: ${
                      Array.isArray(messages) ? messages.join(", ") : messages
                    }`
                )
                .join(" | ")
            : String(data)
        );
      } else {
        setErreur("La vente n'a pas pu être enregistrée. Réessayez.");
      }
    } finally {
      setEnvoiEnCours(false);
    }
  }

  if (chargement) {
    return <p className="chargement-texte">Chargement...</p>;
  }

  return (
    <div className="vd-wrap">
      {/* ===================== COLONNE PRODUITS ===================== */}
      <div className="vd-produits">
        <div className="admin-contenu-header">
          <h3>🛒 Vente directe</h3>
        </div>

        <p className="vd-aide">
          Sélectionnez les produits, encaissez l'argent du client, puis validez.
          La commande sera enregistrée automatiquement (payée et servie).
        </p>

        <div className="produits-toolbar">
          <div className="produits-search">
            <span className="produits-search-icone" aria-hidden="true">
              🔍
            </span>
            <input
              type="text"
              value={recherche}
              onChange={(e) => setRecherche(e.target.value)}
              placeholder="Rechercher un produit..."
              autoFocus
            />
            {recherche && (
              <button
                className="produits-search-clear"
                onClick={() => setRecherche("")}
                title="Effacer la recherche"
              >
                ✕
              </button>
            )}
          </div>

          <select
            className="produits-filtre-cat"
            value={filtreCategorie}
            onChange={(e) => setFiltreCategorie(e.target.value)}
          >
            <option value="toutes">Toutes les catégories</option>
            {categories.map((c) => (
              <option key={c.id} value={c.id}>
                {c.nom}
              </option>
            ))}
          </select>
        </div>

        {platsFiltres.length === 0 ? (
          <EmptyState
            icon="🍔"
            title={plats.length === 0 ? "Aucun produit" : "Aucun résultat"}
          />
        ) : (
          <div className="vd-grid">
            {platsFiltres.map((p) => {
              const img = photoLocalePlat(p.nom) || p.image;
              return (
                <button
                  type="button"
                  className="vd-produit"
                  key={p.id}
                  onClick={() => cliquerProduit(p)}
                  title={`Ajouter ${p.nom}`}
                >
                  <div className="vd-produit-img">
                    {img ? (
                      <img src={img} alt={p.nom} loading="lazy" />
                    ) : (
                      <span aria-hidden="true">🍔</span>
                    )}
                    {necessiteConfiguration(p) && (
                      <span className="vd-produit-options" title="Choix à définir">
                        ⚙️
                      </span>
                    )}
                  </div>
                  <div className="vd-produit-nom">{p.nom}</div>
                  <div className="vd-produit-prix">{p.prix} F</div>
                </button>
              );
            })}
          </div>
        )}
      </div>

      {/* ===================== COLONNE PANIER ===================== */}
      <div className="vd-panier">
        <div className="vd-panier-tete">
          <h3>Panier</h3>
          <span className="vd-panier-compteur">{nombreArticles}</span>
        </div>

        {panier.length === 0 ? (
          <div className="vd-panier-vide">
            <span aria-hidden="true">🧾</span>
            <p>Aucun article.<br />Cliquez sur un produit pour l'ajouter.</p>
          </div>
        ) : (
          <div className="vd-panier-lignes">
            {panier.map((l) => (
              <div className="vd-ligne" key={l.cle}>
                <div className="vd-ligne-info">
                  <div className="vd-ligne-nom">{l.plat.nom}</div>
                  {l.accompagnement && (
                    <div className="vd-ligne-opt">+ {l.accompagnement.nom}</div>
                  )}
                  {l.selections && l.selections.length > 0 && (
                    <div className="vd-ligne-opt">
                      {l.selections.map((s) => s.option_nom).join(" · ")}
                    </div>
                  )}
                  <div className="vd-ligne-prix">
                    {Number(l.plat.prix) * l.quantite} F
                  </div>
                </div>
                <div className="vd-ligne-actions">
                  <div className="vd-stepper">
                    <button onClick={() => changerQuantite(l.cle, -1)}>−</button>
                    <span>{l.quantite}</span>
                    <button onClick={() => changerQuantite(l.cle, +1)}>+</button>
                  </div>
                  <button
                    className="vd-ligne-suppr"
                    onClick={() => retirerLigne(l.cle)}
                    title="Retirer"
                  >
                    🗑️
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}

        <div className="vd-total">
          <span>Total</span>
          <strong>{total} F</strong>
        </div>

        {/* Paiement */}
        <div className="vd-paiement">
          <label className="vd-label">Mode de paiement</label>
          <div className="vd-modes">
            {[
              { v: "ESPECES", t: "💵 Espèces" },
              { v: "WAVE", t: "🌊 Wave" },
              { v: "ORANGE_MONEY", t: "🟠 Orange Money" },
            ].map((m) => (
              <button
                key={m.v}
                type="button"
                className={modePaiement === m.v ? "actif" : ""}
                onClick={() => setModePaiement(m.v)}
              >
                {m.t}
              </button>
            ))}
          </div>

          {modePaiement !== "ESPECES" && (
            <input
              className="vd-input"
              type="text"
              value={referencePaiement}
              onChange={(e) => setReferencePaiement(e.target.value)}
              placeholder="Référence de paiement (facultatif)"
            />
          )}

          <input
            className="vd-input"
            type="text"
            value={numeroTable}
            onChange={(e) => setNumeroTable(e.target.value)}
            placeholder="Table / repère (facultatif)"
            maxLength={10}
          />
        </div>

        {erreur && <div className="admin-modal-erreur">{erreur}</div>}

        <button
          className="vd-encaisser"
          onClick={encaisser}
          disabled={panier.length === 0 || envoiEnCours}
        >
          {envoiEnCours
            ? "Enregistrement..."
            : `✅ Encaisser ${total} F`}
        </button>
        {panier.length > 0 && (
          <button className="vd-vider" onClick={viderPanier} disabled={envoiEnCours}>
            Vider le panier
          </button>
        )}
      </div>

      {/* ===================== MODALE OPTIONS ===================== */}
      {platAConfigurer && (
        <ConfigurationPlat
          plat={platAConfigurer}
          onFermer={() => setPlatAConfigurer(null)}
          onValider={(accompagnement, selections) => {
            ajouterAuPanier(platAConfigurer, accompagnement, selections);
            setPlatAConfigurer(null);
          }}
        />
      )}

      {/* ===================== MODALE CONFIRMATION ===================== */}
      {confirmation && (
        <div className="admin-modal-overlay" onClick={() => setConfirmation(null)}>
          <div className="admin-modal vd-confirm" onClick={(e) => e.stopPropagation()}>
            <div className="vd-confirm-icone">✅</div>
            <h3>Vente enregistrée</h3>
            <p>
              Commande <strong>#{confirmation.id}</strong> encaissée et servie.
            </p>
            {confirmation.total != null && (
              <div className="vd-confirm-total">{confirmation.total} F</div>
            )}
            <div className="admin-modal-actions">
              <button
                className="admin-modal-valider"
                onClick={() => setConfirmation(null)}
              >
                Nouvelle vente
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

/* ====================================================================== */
/* Modale de configuration d'un plat (accompagnement + groupes de choix). */
/* ====================================================================== */
function ConfigurationPlat({ plat, onFermer, onValider }) {
  const [accompagnementId, setAccompagnementId] = useState(
    plat.accompagnement_obligatoire && plat.accompagnements?.length
      ? plat.accompagnements[0].id
      : null
  );
  // selections par groupe : { [groupeId]: optionId }
  const [choixParGroupe, setChoixParGroupe] = useState(() => {
    const init = {};
    (plat.groupes_choix || []).forEach((g) => {
      if (g.obligatoire && g.options?.length) init[g.id] = g.options[0].id;
    });
    return init;
  });
  const [erreur, setErreur] = useState(null);

  const aAccompagnements = plat.accompagnements && plat.accompagnements.length > 0;

  function valider() {
    // Accompagnement obligatoire
    if (plat.accompagnement_obligatoire && !accompagnementId) {
      setErreur("Veuillez choisir un accompagnement.");
      return;
    }
    // Groupes obligatoires
    for (const g of plat.groupes_choix || []) {
      if (g.obligatoire && !choixParGroupe[g.id]) {
        setErreur(`Veuillez choisir une option pour « ${g.nom} ».`);
        return;
      }
    }

    const accompagnement = aAccompagnements
      ? plat.accompagnements.find((a) => a.id === Number(accompagnementId)) || null
      : null;

    const selections = [];
    (plat.groupes_choix || []).forEach((g) => {
      const optId = choixParGroupe[g.id];
      if (optId) {
        const opt = g.options.find((o) => o.id === Number(optId));
        selections.push({
          groupe_id: g.id,
          option_id: Number(optId),
          option_nom: opt?.nom || "",
        });
      }
    });

    onValider(accompagnement, selections);
  }

  return (
    <div className="admin-modal-overlay" onClick={onFermer}>
      <div className="admin-modal" onClick={(e) => e.stopPropagation()}>
        <h3>{plat.nom}</h3>
        <p className="vd-config-prix">{plat.prix} F</p>

        {aAccompagnements && (
          <div className="vd-config-groupe">
            <label className="vd-label">
              Accompagnement{plat.accompagnement_obligatoire ? " *" : " (facultatif)"}
            </label>
            {!plat.accompagnement_obligatoire && (
              <label className="vd-radio">
                <input
                  type="radio"
                  name="accomp"
                  checked={!accompagnementId}
                  onChange={() => setAccompagnementId(null)}
                />
                Sans accompagnement
              </label>
            )}
            {plat.accompagnements.map((a) => (
              <label className="vd-radio" key={a.id}>
                <input
                  type="radio"
                  name="accomp"
                  checked={Number(accompagnementId) === a.id}
                  onChange={() => setAccompagnementId(a.id)}
                />
                {a.nom}
              </label>
            ))}
          </div>
        )}

        {(plat.groupes_choix || []).map((g) => (
          <div className="vd-config-groupe" key={g.id}>
            <label className="vd-label">
              {g.nom}
              {g.obligatoire ? " *" : " (facultatif)"}
            </label>
            {!g.obligatoire && (
              <label className="vd-radio">
                <input
                  type="radio"
                  name={`groupe-${g.id}`}
                  checked={!choixParGroupe[g.id]}
                  onChange={() =>
                    setChoixParGroupe((prev) => {
                      const n = { ...prev };
                      delete n[g.id];
                      return n;
                    })
                  }
                />
                Aucun
              </label>
            )}
            {(g.options || []).map((o) => (
              <label className="vd-radio" key={o.id}>
                <input
                  type="radio"
                  name={`groupe-${g.id}`}
                  checked={Number(choixParGroupe[g.id]) === o.id}
                  onChange={() =>
                    setChoixParGroupe((prev) => ({ ...prev, [g.id]: o.id }))
                  }
                />
                {o.nom}
              </label>
            ))}
          </div>
        ))}

        {erreur && <div className="admin-modal-erreur">{erreur}</div>}

        <div className="admin-modal-actions">
          <button className="admin-modal-annuler" onClick={onFermer}>
            Annuler
          </button>
          <button className="admin-modal-valider" onClick={valider}>
            Ajouter au panier
          </button>
        </div>
      </div>
    </div>
  );
}
