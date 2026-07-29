import { useState } from "react";
import client from "../api/client";
import { useAuth } from "../context/AuthContext";
import "./ParametresContenu.css";

export default function ParametresContenu() {
  const { utilisateur } = useAuth();
  const [ancien, setAncien] = useState("");
  const [nouveau, setNouveau] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [enCours, setEnCours] = useState(false);
  const [erreur, setErreur] = useState(null);
  const [succes, setSucces] = useState(null);

  async function changerMotDePasse() {
    setErreur(null);
    setSucces(null);

    if (nouveau !== confirmation) {
      setErreur("La confirmation ne correspond pas au nouveau mot de passe.");
      return;
    }
    if (nouveau.length < 6) {
      setErreur("Le nouveau mot de passe doit faire au moins 6 caractères.");
      return;
    }

    setEnCours(true);
    try {
      await client.post("comptes/changer-mot-de-passe/", {
        ancien_mot_de_passe: ancien,
        nouveau_mot_de_passe: nouveau,
      });
      setSucces("Mot de passe mis à jour avec succès.");
      setAncien(""); setNouveau(""); setConfirmation("");
    } catch (e) {
      setErreur(e?.response?.data?.ancien_mot_de_passe?.[0] || "Une erreur est survenue.");
    } finally {
      setEnCours(false);
    }
  }

  return (
    <div>
      <h3>Paramètres</h3>

      <div className="parametres-carte">
        <div className="parametres-label">MON COMPTE</div>
        <div className="parametres-username">{utilisateur?.username}</div>
        <div className="parametres-role">Rôle : {utilisateur?.role}</div>
      </div>

      <div className="parametres-carte parametres-form">
        <div className="parametres-label">CHANGER MON MOT DE PASSE</div>
        <input type="password" placeholder="Mot de passe actuel" value={ancien} onChange={(e) => setAncien(e.target.value)} />
        <input type="password" placeholder="Nouveau mot de passe" value={nouveau} onChange={(e) => setNouveau(e.target.value)} />
        <input type="password" placeholder="Confirmer le nouveau mot de passe" value={confirmation} onChange={(e) => setConfirmation(e.target.value)} />
        {erreur && <div className="parametres-erreur">{erreur}</div>}
        {succes && <div className="parametres-succes">{succes}</div>}
        <button onClick={changerMotDePasse} disabled={enCours}>
          {enCours ? "Mise à jour..." : "Mettre à jour"}
        </button>
      </div>
    </div>
  );
}
