import { useEffect, useState } from "react";
import client from "../api/client";
import EmptyState from "./EmptyState";
import "./AdminContenus.css";

export default function ProduitsContenu() {
  const [plats, setPlats] = useState([]);
  const [categories, setCategories] = useState([]);
  const [chargement, setChargement] = useState(true);
  const [formulaireOuvert, setFormulaireOuvert] = useState(null);

  function charger() {
    setChargement(true);
    Promise.all([client.get("menu/plats/"), client.get("menu/categories/")]).then(([p, c]) => {
      setPlats(p.data);
      setCategories(c.data);
      setChargement(false);
    });
  }

  useEffect(() => { charger(); }, []);

  function nomCategorie(id) {
    return categories.find((c) => c.id === id)?.nom || "—";
  }

  async function basculerDisponibilite(plat) {
    await client.patch(`menu/plats/${plat.id}/`, { disponible: !plat.disponible });
    charger();
  }

  async function supprimer(plat) {
    if (!window.confirm(`Supprimer "${plat.nom}" ?`)) return;
    await client.delete(`menu/plats/${plat.id}/`);
    charger();
  }

  if (chargement) return <p className="chargement-texte">Chargement...</p>;

  return (
    <div>
      <div className="admin-contenu-header">
        <h3>Produits</h3>
        <button className="admin-btn-ajouter" onClick={() => setFormulaireOuvert("nouveau")}>+ Ajouter</button>
      </div>
      <p style={{ fontSize: 10.5, color: "var(--ink-soft)", marginTop: -8, marginBottom: 16, fontStyle: "italic" }}>
        ℹ️ La photo, les accompagnements et les formules composées se gèrent depuis l'admin Django (/admin/).
      </p>
      {plats.length === 0 ? (
        <EmptyState icon="🍔" title="Aucun plat" />
      ) : (
        <div className="admin-table-wrap">
          <table className="admin-table">
            <thead>
              <tr><th>Nom</th><th>Catégorie</th><th>Prix</th><th>Disponible</th><th>Actions</th></tr>
            </thead>
            <tbody>
              {plats.map((p) => (
                <tr key={p.id}>
                  <td>{p.nom}</td>
                  <td>{nomCategorie(p.categorie)}</td>
                  <td>{p.prix} F</td>
                  <td>
                    <span
                      className={p.disponible ? "admin-badge-actif" : "admin-badge-inactif"}
                      style={{ cursor: "pointer" }}
                      onClick={() => basculerDisponibilite(p)}
                    >
                      {p.disponible ? "Disponible" : "Indisponible"}
                    </span>
                  </td>
                  <td>
                    <button onClick={() => setFormulaireOuvert(p)}>✏️</button>
                    <button onClick={() => supprimer(p)}>🗑️</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {formulaireOuvert && (
        <FormulairePlat
          plat={formulaireOuvert === "nouveau" ? null : formulaireOuvert}
          categories={categories}
          onFermer={() => setFormulaireOuvert(null)}
          onEnregistre={() => { setFormulaireOuvert(null); charger(); }}
        />
      )}
    </div>
  );
}

function FormulairePlat({ plat, categories, onFermer, onEnregistre }) {
  const [nom, setNom] = useState(plat?.nom || "");
  const [description, setDescription] = useState(plat?.description || "");
  const [prix, setPrix] = useState(plat?.prix || "");
  const [tempsPreparation, setTempsPreparation] = useState(plat?.temps_preparation_min || 8);
  const [categorieId, setCategorieId] = useState(plat?.categorie || categories[0]?.id || "");
  const [disponible, setDisponible] = useState(plat?.disponible ?? true);
  const [erreur, setErreur] = useState(null);
  const [enCours, setEnCours] = useState(false);

  async function enregistrer() {
    setErreur(null);
    const prixNombre = parseFloat(String(prix).replace(",", "."));
    if (!nom.trim() || isNaN(prixNombre)) { setErreur("Nom et prix valides requis."); return; }

    setEnCours(true);
    try {
      const data = {
        nom: nom.trim(),
        description: description.trim(),
        prix: prixNombre,
        temps_preparation_min: parseInt(tempsPreparation, 10) || 8,
        categorie: Number(categorieId),
        disponible,
      };
      if (plat) {
        await client.patch(`menu/plats/${plat.id}/`, data);
      } else {
        await client.post("menu/plats/", data);
      }
      onEnregistre();
    } catch (e) {
      setErreur(e?.response?.data ? JSON.stringify(e.response.data) : "Une erreur est survenue.");
    } finally {
      setEnCours(false);
    }
  }

  return (
    <div className="admin-modal-overlay" onClick={onFermer}>
      <div className="admin-modal" onClick={(e) => e.stopPropagation()}>
        <h3>{plat ? "Modifier le plat" : "Nouveau plat"}</h3>

        <label>Nom du plat</label>
        <input value={nom} onChange={(e) => setNom(e.target.value)} placeholder="Nom du plat" />

        <label>Description (optionnel)</label>
        <input value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Description" />

        <label>Prix (FCFA)</label>
        <input value={prix} onChange={(e) => setPrix(e.target.value)} placeholder="Prix" inputMode="decimal" />

        <label>Temps de préparation (min)</label>
        <input value={tempsPreparation} onChange={(e) => setTempsPreparation(e.target.value)} placeholder="8" inputMode="numeric" />

        <label>Catégorie</label>
        <select value={categorieId} onChange={(e) => setCategorieId(e.target.value)}>
          {categories.map((c) => <option key={c.id} value={c.id}>{c.nom}</option>)}
        </select>

        <label className="admin-modal-checkbox">
          <input type="checkbox" checked={disponible} onChange={(e) => setDisponible(e.target.checked)} />
          Disponible à la vente
        </label>

        {erreur && <div className="admin-modal-erreur">{erreur}</div>}

        <div className="admin-modal-actions">
          <button className="admin-modal-annuler" onClick={onFermer}>Annuler</button>
          <button className="admin-modal-valider" onClick={enregistrer} disabled={enCours}>
            {enCours ? "Enregistrement..." : "Enregistrer"}
          </button>
        </div>
      </div>
    </div>
  );
}
