import { useEffect, useState } from "react";
import client from "../api/client";
import EmptyState from "./EmptyState";
import "./ClientsContenu.css";

export default function ClientsContenu() {
  const [clients, setClients] = useState([]);
  const [chargement, setChargement] = useState(true);

  useEffect(() => {
    client.get("caisse/clients/").then((res) => {
      setClients(res.data);
      setChargement(false);
    });
  }, []);

  if (chargement) return <p className="chargement-texte">Chargement...</p>;

  return (
    <div>
      <h3>Clients</h3>
      <p className="clients-note">
        Regroupés par numéro de téléphone, à partir des commandes en livraison (aucune fiche client dédiée).
      </p>
      {clients.length === 0 ? (
        <EmptyState
          icon="👥"
          title="Aucun client livraison pour le moment"
          subtitle="Les clients apparaîtront ici dès leur première commande en livraison."
        />
      ) : (
        <div className="clients-table-wrap">
          <table className="clients-table">
            <thead>
              <tr>
                <th>Téléphone</th>
                <th>Dernière adresse</th>
                <th>Commandes</th>
                <th>Total dépensé</th>
                <th>Dernière commande</th>
              </tr>
            </thead>
            <tbody>
              {clients.map((c) => (
                <tr key={c.telephone}>
                  <td>{c.telephone}</td>
                  <td>{c.derniere_adresse || "—"}</td>
                  <td>{c.nombre_commandes}</td>
                  <td>{Number(c.total_depense).toLocaleString("fr-FR")} F</td>
                  <td>{new Date(c.derniere_commande).toLocaleString("fr-FR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" })}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
