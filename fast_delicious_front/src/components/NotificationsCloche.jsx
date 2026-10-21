import { useState } from "react";
import client from "../api/client";
import { useDashboardSocket } from "../hooks/useDashboardSocket";

/**
 * Cloche de notifications pour la caissière et l'admin.
 * Écoute le groupe temps réel "caisse" : à chaque NOUVELLE commande, incrémente le compteur
 * (pastille rouge) et ajoute une entrée à la liste déroulante. Ouvrir la cloche marque tout
 * comme lu. Un clic sur une notification ouvre l'onglet Commandes (si câblé).
 */
export default function NotificationsCloche({ onVoirCommandes }) {
  const [notifs, setNotifs] = useState([]);
  const [nonLues, setNonLues] = useState(0);
  const [ouvert, setOuvert] = useState(false);

  useDashboardSocket("caisse", (data) => {
    if (data?.evenement !== "nouvelle_commande" || !data.commande_id) return;
    const id = data.commande_id;
    const entree = { cle: `${id}-${Date.now()}`, commande_id: id, heure: new Date(), table: null, total: null };
    setNotifs((prev) => [entree, ...prev].slice(0, 20));
    setNonLues((n) => Math.min(n + 1, 99));

    client
      .get(`commandes/${id}/`)
      .then((r) => {
        const d = r.data;
        const table = d.mode_commande === "LIVRAISON" ? "🛵 Livraison" : (d.numero_table ? `Table ${d.numero_table}` : "Sur place");
        setNotifs((prev) => prev.map((x) => (x.cle === entree.cle ? { ...x, table, total: d.total } : x)));
      })
      .catch(() => {});
  });

  function basculer() {
    setOuvert((v) => {
      const suivant = !v;
      if (suivant) setNonLues(0);
      return suivant;
    });
  }

  return (
    <div className="cloche-wrap">
      <button className={`cloche-btn${nonLues > 0 ? " sonne" : ""}`} onClick={basculer} aria-label="Notifications">
        🔔
        {nonLues > 0 && <span className="cloche-badge">{nonLues > 9 ? "9+" : nonLues}</span>}
      </button>

      {ouvert && (
        <>
          <div className="cloche-overlay" onClick={() => setOuvert(false)} />
          <div className="cloche-menu">
            <div className="cloche-menu-tete">
              <span>🔔 Notifications</span>
              {notifs.length > 0 && (
                <button className="cloche-vider" onClick={() => setNotifs([])}>Tout effacer</button>
              )}
            </div>

            {notifs.length === 0 ? (
              <div className="cloche-vide">Aucune nouvelle commande</div>
            ) : (
              <div className="cloche-liste">
                {notifs.map((n) => (
                  <button
                    className="cloche-item"
                    key={n.cle}
                    onClick={() => {
                      setOuvert(false);
                      onVoirCommandes?.();
                    }}
                  >
                    <span className="cloche-item-icone">🧾</span>
                    <span className="cloche-item-txt">
                      <strong>Nouvelle commande #{n.commande_id}</strong>
                      <span className="cloche-item-sub">
                        {n.table || "…"}
                        {n.total != null ? ` · ${Number(n.total).toLocaleString("fr-FR")} F` : ""}
                      </span>
                    </span>
                    <span className="cloche-item-heure">
                      {n.heure.toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" })}
                    </span>
                  </button>
                ))}
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}
