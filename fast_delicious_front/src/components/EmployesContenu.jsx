import { useEffect, useState } from "react";
import client from "../api/client";
import EmptyState from "./EmptyState";
import "./AdminContenus.css";

const LABELS_ROLE = { caissiere: "Caissière", cuisine: "Cuisinier", livreur: "Livreur", admin: "Admin" };
const ROLES_DISPONIBLES = ["caissiere", "cuisine", "livreur", "admin"];

export default function EmployesContenu() {
  const [employes, setEmployes] = useState([]);
  const [lieux, setLieux] = useState([]);
  const [chargement, setChargement] = useState(true);
  const [formulaireOuvert, setFormulaireOuvert] = useState(null); // null | "nouveau" | employe

  function charger() {
    setChargement(true);
    Promise.all([client.get("comptes/employes/"), client.get("menu/lieux/")]).then(([e, l]) => {
      setEmployes(e.data);
      setLieux(l.data);
      setChargement(false);
    });
  }

  useEffect(() => { charger(); }, []);

  async function basculerActif(employe) {
    await client.patch(`comptes/employes/${employe.id}/`, { is_active: !employe.is_active });
    charger();
  }

  async function supprimer(employe) {
    if (!window.confirm(`Supprimer le compte "${employe.username}" ?`)) return;
    await client.delete(`comptes/employes/${employe.id}/`);
    charger();
  }

  if (chargement) return <p className="chargement-texte">Chargement...</p>;

  return (
    <div>
      <div className="admin-contenu-header">
        <h3>Employés</h3>
        <button className="admin-btn-ajouter" onClick={() => setFormulaireOuvert("nouveau")}>+ Ajouter</button>
      </div>
      {employes.length === 0 ? (
        <EmptyState icon="👤" title="Aucun employé pour le moment" />
      ) : (
        <div className="admin-table-wrap">
          <table className="admin-table">
            <thead>
              <tr><th>Identifiant</th><th>Rôle</th><th>Lieu</th><th>Statut</th><th>Actions</th></tr>
            </thead>
            <tbody>
              {employes.map((e) => (
                <tr key={e.id}>
                  <td>{e.username}</td>
                  <td>{LABELS_ROLE[e.role] || e.role}</td>
                  <td>{e.lieu_nom || "— (tous)"}</td>
                  <td>
                    <span
                      className={e.is_active ? "admin-badge-actif" : "admin-badge-inactif"}
                      style={{ cursor: "pointer" }}
                      onClick={() => basculerActif(e)}
                    >
                      {e.is_active ? "Actif" : "Inactif"}
                    </span>
                  </td>
                  <td>
                    <button onClick={() => setFormulaireOuvert(e)}>✏️</button>
                    <button onClick={() => supprimer(e)}>🗑️</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {formulaireOuvert && (
        <FormulaireEmploye
          employe={formulaireOuvert === "nouveau" ? null : formulaireOuvert}
          lieux={lieux}
          onFermer={() => setFormulaireOuvert(null)}
          onEnregistre={() => { setFormulaireOuvert(null); charger(); }}
        />
      )}
    </div>
  );
}

function FormulaireEmploye({ employe, lieux, onFermer, onEnregistre }) {
  const [username, setUsername] = useState(employe?.username || "");
  const [role, setRole] = useState(employe?.role || "caissiere");
  const [lieuId, setLieuId] = useState(employe?.lieu ?? "");
  const [password, setPassword] = useState("");
  const [actif, setActif] = useState(employe?.is_active ?? true);
  const [erreur, setErreur] = useState(null);
  const [enCours, setEnCours] = useState(false);

  async function enregistrer() {
    setErreur(null);
    if (!username.trim()) { setErreur("Identifiant requis."); return; }
    if (!employe && !password) { setErreur("Mot de passe requis à la création."); return; }

    setEnCours(true);
    try {
      const data = {
        username: username.trim(),
        role,
        is_active: actif,
        lieu: lieuId === "" ? null : Number(lieuId),
        ...(password ? { password } : {}),
      };
      if (employe) {
        await client.patch(`comptes/employes/${employe.id}/`, data);
      } else {
        await client.post("comptes/employes/", data);
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
        <h3>{employe ? `Modifier ${employe.username}` : "Nouvel employé"}</h3>

        <label>Identifiant</label>
        <input value={username} onChange={(e) => setUsername(e.target.value)} placeholder="Identifiant" />

        <label>{employe ? "Nouveau mot de passe (optionnel)" : "Mot de passe"}</label>
        <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} placeholder={employe ? "Laisser vide pour ne pas changer" : "Mot de passe"} />

        <label>Rôle</label>
        <select value={role} onChange={(e) => setRole(e.target.value)}>
          {ROLES_DISPONIBLES.map((r) => <option key={r} value={r}>{LABELS_ROLE[r]}</option>)}
        </select>

        {lieux.length > 0 && (
          <>
            <label>Lieu affecté</label>
            <select value={lieuId} onChange={(e) => setLieuId(e.target.value)}>
              <option value="">Aucun (voit tout)</option>
              {lieux.map((l) => <option key={l.id} value={l.id}>📍 {l.nom}</option>)}
            </select>
          </>
        )}

        {employe && (
          <label className="admin-modal-checkbox">
            <input type="checkbox" checked={actif} onChange={(e) => setActif(e.target.checked)} />
            Compte actif
          </label>
        )}

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
