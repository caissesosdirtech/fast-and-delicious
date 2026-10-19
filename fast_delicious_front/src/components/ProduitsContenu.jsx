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

    Promise.all([
      client.get("menu/plats/"),
      client.get("menu/categories/")
    ])
      .then(([p, c]) => {
        setPlats(p.data);
        setCategories(c.data);
      })
      .catch((e) => {
        console.error("Erreur chargement produits :", e);
      })
      .finally(() => {
        setChargement(false);
      });
  }

  useEffect(() => {
    charger();
  }, []);

  function nomCategorie(id) {
    return categories.find((c) => c.id === id)?.nom || "—";
  }

  async function basculerDisponibilite(plat) {
    try {
      await client.patch(`menu/plats/${plat.id}/`, {
        disponible: !plat.disponible
      });
      charger();
    } catch (e) {
      console.error(e);
      alert("Impossible de modifier la disponibilité.");
    }
  }

  async function supprimer(plat) {
    if (!window.confirm(`Supprimer "${plat.nom}" ?`)) return;

    try {
      await client.delete(`menu/plats/${plat.id}/`);
      charger();
    } catch (e) {
      console.error(e);
      alert("Impossible de supprimer ce plat.");
    }
  }

  if (chargement) {
    return <p className="chargement-texte">Chargement...</p>;
  }

  return (
    <div>
      <div className="admin-contenu-header">
        <h3>Produits</h3>

        <button
          className="admin-btn-ajouter"
          onClick={() => setFormulaireOuvert("nouveau")}
        >
          + Ajouter
        </button>
      </div>

      {plats.length === 0 ? (
        <EmptyState icon="🍔" title="Aucun plat" />
      ) : (
        <div className="admin-table-wrap">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Photo</th>
                <th>Nom</th>
                <th>Catégorie</th>
                <th>Prix</th>
                <th>Disponible</th>
                <th>Actions</th>
              </tr>
            </thead>

            <tbody>
              {plats.map((p) => (
                <tr key={p.id}>
                  <td>
                    {p.image ? (
                      <img
                        src={p.image}
                        alt={p.nom}
                        style={{
                          width: 58,
                          height: 58,
                          objectFit: "cover",
                          borderRadius: 10,
                          display: "block"
                        }}
                      />
                    ) : (
                      <div
                        style={{
                          width: 58,
                          height: 58,
                          borderRadius: 10,
                          background: "#f2f2f2",
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "center",
                          fontSize: 24
                        }}
                        title="Aucune photo"
                      >
                        🍔
                      </div>
                    )}
                  </td>

                  <td>{p.nom}</td>

                  <td>{nomCategorie(p.categorie)}</td>

                  <td>{p.prix} F</td>

                  <td>
                    <span
                      className={
                        p.disponible
                          ? "admin-badge-actif"
                          : "admin-badge-inactif"
                      }
                      style={{ cursor: "pointer" }}
                      onClick={() => basculerDisponibilite(p)}
                    >
                      {p.disponible ? "Disponible" : "Indisponible"}
                    </span>
                  </td>

                  <td>
                    <button
                      onClick={() => setFormulaireOuvert(p)}
                      title="Modifier"
                    >
                      ✏️
                    </button>

                    <button
                      onClick={() => supprimer(p)}
                      title="Supprimer"
                    >
                      🗑️
                    </button>
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
          onEnregistre={() => {
            setFormulaireOuvert(null);
            charger();
          }}
        />
      )}
    </div>
  );
}


function FormulairePlat({
  plat,
  categories,
  onFermer,
  onEnregistre
}) {
  const [nom, setNom] = useState(plat?.nom || "");
  const [description, setDescription] = useState(plat?.description || "");
  const [prix, setPrix] = useState(plat?.prix || "");
  const [tempsPreparation, setTempsPreparation] = useState(
    plat?.temps_preparation_min || 8
  );
  const [categorieId, setCategorieId] = useState(
    plat?.categorie || categories[0]?.id || ""
  );
  const [disponible, setDisponible] = useState(
    plat?.disponible ?? true
  );

  const [image, setImage] = useState(null);
  const [aperçuImage, setAperçuImage] = useState(plat?.image || "");
  const [supprimerImage, setSupprimerImage] = useState(false);

  const [erreur, setErreur] = useState(null);
  const [enCours, setEnCours] = useState(false);

  function choisirImage(e) {
    const fichier = e.target.files?.[0];

    if (!fichier) return;

    // Vérification du type
    if (!fichier.type.startsWith("image/")) {
      setErreur("Veuillez sélectionner une image.");
      e.target.value = "";
      return;
    }

    // Limite de 5 Mo
    if (fichier.size > 5 * 1024 * 1024) {
      setErreur("La photo ne doit pas dépasser 5 Mo.");
      e.target.value = "";
      return;
    }

    setErreur(null);
    setImage(fichier);
    setSupprimerImage(false);

    const url = URL.createObjectURL(fichier);
    setAperçuImage(url);
  }

  function retirerImage() {
    setImage(null);
    setSupprimerImage(true);
    setAperçuImage("");
  }

  async function enregistrer() {
    setErreur(null);

    const prixNombre = parseFloat(
      String(prix).replace(",", ".")
    );

    if (!nom.trim() || isNaN(prixNombre)) {
      setErreur("Nom et prix valides requis.");
      return;
    }

    if (!categorieId) {
      setErreur("Veuillez sélectionner une catégorie.");
      return;
    }

    setEnCours(true);

    try {
      const formData = new FormData();

      formData.append("nom", nom.trim());
      formData.append("description", description.trim());
      formData.append("prix", prixNombre);
      formData.append(
        "temps_preparation_min",
        parseInt(tempsPreparation, 10) || 8
      );
      formData.append("categorie", Number(categorieId));
      formData.append("disponible", disponible ? "true" : "false");

      // Nouvelle photo
      if (image) {
        formData.append("image", image);
      }

      // Suppression de la photo existante
      if (plat && supprimerImage && !image) {
        formData.append("image", "");
      }

      if (plat) {
        await client.patch(
          `menu/plats/${plat.id}/`,
          formData
        );
      } else {
        await client.post(
          "menu/plats/",
          formData
        );
      }

      onEnregistre();

    } catch (e) {
      console.error("Erreur enregistrement plat :", e);

      const data = e?.response?.data;

      if (data) {
        setErreur(
          typeof data === "object"
            ? Object.entries(data)
                .map(([champ, messages]) =>
                  `${champ}: ${
                    Array.isArray(messages)
                      ? messages.join(", ")
                      : messages
                  }`
                )
                .join(" | ")
            : String(data)
        );
      } else {
        setErreur(
          "Une erreur est survenue lors de l'enregistrement."
        );
      }
    } finally {
      setEnCours(false);
    }
  }

  return (
    <div
      className="admin-modal-overlay"
      onClick={onFermer}
    >
      <div
        className="admin-modal"
        onClick={(e) => e.stopPropagation()}
      >
        <h3>
          {plat ? "Modifier le plat" : "Nouveau plat"}
        </h3>

        <label>Nom du plat</label>

        <input
          value={nom}
          onChange={(e) => setNom(e.target.value)}
          placeholder="Nom du plat"
        />

        <label>Description (optionnel)</label>

        <input
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Description"
        />

        <label>Prix (FCFA)</label>

        <input
          value={prix}
          onChange={(e) => setPrix(e.target.value)}
          placeholder="Prix"
          inputMode="decimal"
        />

        <label>Temps de préparation (min)</label>

        <input
          value={tempsPreparation}
          onChange={(e) =>
            setTempsPreparation(e.target.value)
          }
          placeholder="8"
          inputMode="numeric"
        />

        <label>Catégorie</label>

        <select
          value={categorieId}
          onChange={(e) =>
            setCategorieId(e.target.value)
          }
        >
          {categories.map((c) => (
            <option key={c.id} value={c.id}>
              {c.nom}
            </option>
          ))}
        </select>

        {/* PHOTO */}
        <div style={{ marginTop: 16 }}>
          <label>📷 Photo du plat</label>

          {aperçuImage && (
            <div
              style={{
                marginTop: 10,
                marginBottom: 10,
                position: "relative"
              }}
            >
              <img
                src={aperçuImage}
                alt="Aperçu du plat"
                style={{
                  width: "100%",
                  maxWidth: 260,
                  height: 170,
                  objectFit: "cover",
                  borderRadius: 12,
                  display: "block"
                }}
              />
            </div>
          )}

          <input
            type="file"
            accept="image/jpeg,image/png,image/webp,image/gif"
            onChange={choisirImage}
          />

          <small
            style={{
              display: "block",
              marginTop: 6,
              color: "var(--ink-soft)"
            }}
          >
            JPG, PNG, WEBP ou GIF — 5 Mo maximum
          </small>

          {plat?.image && !image && !supprimerImage && (
            <button
              type="button"
              onClick={retirerImage}
              style={{
                marginTop: 10,
                border: "none",
                background: "transparent",
                color: "#c62828",
                cursor: "pointer"
              }}
            >
              🗑️ Supprimer la photo actuelle
            </button>
          )}

          {supprimerImage && !image && (
            <div
              style={{
                marginTop: 8,
                color: "#c62828",
                fontSize: 13
              }}
            >
              Photo supprimée lors de l'enregistrement.
            </div>
          )}
        </div>

        <label
          className="admin-modal-checkbox"
          style={{ marginTop: 16 }}
        >
          <input
            type="checkbox"
            checked={disponible}
            onChange={(e) =>
              setDisponible(e.target.checked)
            }
          />

          Disponible à la vente
        </label>

        {erreur && (
          <div className="admin-modal-erreur">
            {erreur}
          </div>
        )}

        <div className="admin-modal-actions">
          <button
            className="admin-modal-annuler"
            onClick={onFermer}
            disabled={enCours}
          >
            Annuler
          </button>

          <button
            className="admin-modal-valider"
            onClick={enregistrer}
            disabled={enCours}
          >
            {enCours
              ? "Enregistrement..."
              : "Enregistrer"}
          </button>
        </div>
      </div>
    </div>
  );
}