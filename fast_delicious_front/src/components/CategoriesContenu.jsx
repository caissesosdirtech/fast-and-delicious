import { useEffect, useState } from "react";
import client from "../api/client";
import EmptyState from "./EmptyState";
import "./AdminContenus.css";

export default function CategoriesContenu() {
  const [categories, setCategories] = useState([]);
  const [chargement, setChargement] = useState(true);

  function charger() {
    setChargement(true);
    client.get("menu/categories/").then((res) => {
      setCategories(res.data);
      setChargement(false);
    });
  }

  useEffect(() => { charger(); }, []);

  async function ouvrirFormulaire(categorie) {
    const nom = window.prompt("Nom de la catégorie :", categorie?.nom || "");
    if (!nom) return;
    const ordre = window.prompt("Ordre d'affichage :", categorie?.ordre ?? 0);
    const data = { nom, ordre: parseInt(ordre, 10) || 0 };
    if (categorie) {
      await client.patch(`menu/categories/${categorie.id}/`, data);
    } else {
      await client.post("menu/categories/", data);
    }
    charger();
  }

  async function supprimer(categorie) {
    if (!window.confirm(`Supprimer "${categorie.nom}" ? Les plats de cette catégorie seront aussi supprimés.`)) return;
    await client.delete(`menu/categories/${categorie.id}/`);
    charger();
  }

  if (chargement) return <p className="chargement-texte">Chargement...</p>;

  return (
    <div>
      <div className="admin-contenu-header">
        <h3>Catégories</h3>
        <button className="admin-btn-ajouter" onClick={() => ouvrirFormulaire(null)}>+ Ajouter</button>
      </div>
      {categories.length === 0 ? (
        <EmptyState icon="🏷️" title="Aucune catégorie" />
      ) : (
        categories.map((c) => (
          <div className="admin-liste-item" key={c.id}>
            <div>
              <div className="admin-liste-titre">{c.nom}</div>
              <div className="admin-liste-sous">{c.plats.length} plat(s) · ordre {c.ordre}</div>
            </div>
            <div className="admin-liste-actions">
              <button onClick={() => ouvrirFormulaire(c)}>✏️</button>
              <button onClick={() => supprimer(c)}>🗑️</button>
            </div>
          </div>
        ))
      )}
    </div>
  );
}
