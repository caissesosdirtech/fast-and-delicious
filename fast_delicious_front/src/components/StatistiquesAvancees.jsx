import { useEffect, useState } from "react";
import client from "../api/client";
import "./StatistiquesAvancees.css";

const PERIODES = [
  { v: "jour", t: "Jour" },
  { v: "semaine", t: "7 jours" },
  { v: "mois", t: "Ce mois" },
  { v: "annee", t: "Cette année" },
];

function fmt(n) {
  return (Number(n) || 0).toLocaleString("fr-FR");
}

export default function StatistiquesAvancees() {
  const [periode, setPeriode] = useState("jour");
  const [data, setData] = useState(null);
  const [chargement, setChargement] = useState(true);
  const [erreur, setErreur] = useState(null);

  useEffect(() => {
    let actif = true;
    setChargement(true);
    setErreur(null);
    client
      .get(`admin/statistiques/avancees/?periode=${periode}`)
      .then((r) => {
        if (actif) setData(r.data);
      })
      .catch(() => {
        if (actif) setErreur("Impossible de charger les statistiques détaillées.");
      })
      .finally(() => {
        if (actif) setChargement(false);
      });
    return () => {
      actif = false;
    };
  }, [periode]);

  // Heures où il s'est passé quelque chose (sinon le graphe est vide sur 24h)
  const heuresActives = (data?.par_heure || []).filter((h) => h.nombre > 0);
  const maxHeure = Math.max(1, ...heuresActives.map((h) => h.nombre));
  const maxProduit = Math.max(1, ...(data?.top_produits || []).map((p) => p.quantite));
  const maxCaCaissiere = Math.max(1, ...(data?.par_caissiere || []).map((c) => c.ca));
  const maxCaLieu = Math.max(1, ...(data?.par_lieu || []).map((l) => l.ca));

  return (
    <div className="stats-av">
      <div className="stats-av-tete">
        <h3>📊 Statistiques détaillées</h3>
        <div className="stats-av-periodes">
          {PERIODES.map((p) => (
            <button
              key={p.v}
              className={periode === p.v ? "actif" : ""}
              onClick={() => setPeriode(p.v)}
            >
              {p.t}
            </button>
          ))}
        </div>
      </div>

      {chargement ? (
        <p className="chargement-texte">Chargement...</p>
      ) : erreur ? (
        <p className="stats-av-erreur">{erreur}</p>
      ) : (
        <>
          {/* Totaux */}
          <div className="stats-av-totaux">
            <div className="stats-av-kpi">
              <span>Chiffre d'affaires</span>
              <strong>{fmt(data.totaux.ca)} F</strong>
            </div>
            <div className="stats-av-kpi">
              <span>Commandes</span>
              <strong>{fmt(data.totaux.nombre)}</strong>
            </div>
          </div>

          <div className="stats-av-grid">
            {/* Produits les plus vendus */}
            <div className="stats-av-carte">
              <h4>🏆 Produits les plus vendus</h4>
              {data.top_produits.length === 0 ? (
                <p className="stats-av-vide">Aucune vente sur la période.</p>
              ) : (
                <div className="stats-av-barres">
                  {data.top_produits.map((p) => (
                    <div className="stats-av-ligne" key={p.nom}>
                      <div className="stats-av-ligne-h">
                        <span className="stats-av-nom">{p.nom}</span>
                        <span className="stats-av-val">
                          {fmt(p.quantite)} vendu{p.quantite > 1 ? "s" : ""} · {fmt(p.ca)} F
                        </span>
                      </div>
                      <div className="stats-av-track">
                        <div
                          className="stats-av-fill"
                          style={{ width: `${Math.round((p.quantite / maxProduit) * 100)}%` }}
                        />
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Heures de pointe */}
            <div className="stats-av-carte">
              <h4>⏰ Heures de pointe</h4>
              {heuresActives.length === 0 ? (
                <p className="stats-av-vide">Aucune vente sur la période.</p>
              ) : (
                <div className="stats-av-heures">
                  {heuresActives.map((h) => (
                    <div className="stats-av-heure" key={h.heure}>
                      <div className="stats-av-heure-val">{h.nombre}</div>
                      <div className="stats-av-heure-barwrap">
                        <div
                          className="stats-av-heure-bar"
                          style={{ height: `${Math.round((h.nombre / maxHeure) * 100)}%` }}
                          title={`${fmt(h.ca)} F`}
                        />
                      </div>
                      <div className="stats-av-heure-lab">{String(h.heure).padStart(2, "0")}h</div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* CA par caissière */}
            <div className="stats-av-carte">
              <h4>👤 Chiffre d'affaires par caissière</h4>
              {data.par_caissiere.length === 0 ? (
                <p className="stats-av-vide">Aucune donnée.</p>
              ) : (
                <div className="stats-av-barres">
                  {data.par_caissiere.map((c) => (
                    <div className="stats-av-ligne" key={c.nom}>
                      <div className="stats-av-ligne-h">
                        <span className="stats-av-nom">{c.nom}</span>
                        <span className="stats-av-val">
                          {fmt(c.ca)} F · {fmt(c.nombre)} cmd
                        </span>
                      </div>
                      <div className="stats-av-track">
                        <div
                          className="stats-av-fill gold"
                          style={{ width: `${Math.round((c.ca / maxCaCaissiere) * 100)}%` }}
                        />
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* CA par lieu */}
            <div className="stats-av-carte">
              <h4>📍 Chiffre d'affaires par stand / lieu</h4>
              {data.par_lieu.length === 0 ? (
                <p className="stats-av-vide">Aucune donnée.</p>
              ) : (
                <div className="stats-av-barres">
                  {data.par_lieu.map((l) => (
                    <div className="stats-av-ligne" key={l.nom}>
                      <div className="stats-av-ligne-h">
                        <span className="stats-av-nom">{l.nom}</span>
                        <span className="stats-av-val">
                          {fmt(l.ca)} F · {fmt(l.nombre)} cmd
                        </span>
                      </div>
                      <div className="stats-av-track">
                        <div
                          className="stats-av-fill teal"
                          style={{ width: `${Math.round((l.ca / maxCaLieu) * 100)}%` }}
                        />
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
