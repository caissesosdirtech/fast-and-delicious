import { useEffect, useState } from "react";
import client from "../api/client";
import EmptyState from "./EmptyState";
import "./AdminContenus.css";

const PERIODES = [
  {
    valeur: "jour",
    label: "Aujourd'hui",
    icone: "📅",
  },
  {
    valeur: "semaine",
    label: "Semaine",
    icone: "📆",
  },
  {
    valeur: "mois",
    label: "Mois",
    icone: "🗓️",
  },
  {
    valeur: "annee",
    label: "Année",
    icone: "📊",
  },
];

export default function CaisseContenu() {
  const [periode, setPeriode] = useState("jour");
  const [stats, setStats] = useState(null);
  const [chargement, setChargement] = useState(true);
  const [erreur, setErreur] = useState(null);

  useEffect(() => {
    charger();
  }, [periode]);

  async function charger() {
    setChargement(true);
    setErreur(null);

    try {
      const res = await client.get(
        `admin/caisse/?periode=${periode}`
      );

      setStats(res.data);
    } catch (error) {
      console.error(error);

      setErreur(
        "Impossible de charger les données de la caisse."
      );
    } finally {
      setChargement(false);
    }
  }

  if (chargement) {
    return (
      <p className="chargement-texte">
        Chargement de la caisse...
      </p>
    );
  }

  if (erreur) {
    return (
      <div className="admin-etat">
        <span>⚠️</span>
        <p>{erreur}</p>

        <button
          className="refresh-btn"
          onClick={charger}
        >
          🔄 Réessayer
        </button>
      </div>
    );
  }

  if (!stats) return null;

  return (
    <div className="admin-dashboard">

      <div className="admin-contenu-header">
        <div>
          <h3>💰 État de la caisse</h3>

          <p
            style={{
              color: "var(--ink-soft)",
              marginTop: 4,
            }}
          >
            {stats.libelle_periode}
          </p>
        </div>

        <button
          className="refresh-btn"
          onClick={charger}
        >
          🔄 Actualiser
        </button>
      </div>

      {/* BOUTONS DES PÉRIODES */}

      <div className="caisse-periodes">

        {PERIODES.map((p) => (

          <button
            key={p.valeur}
            className={
              periode === p.valeur
                ? "caisse-periode-active"
                : "caisse-periode-btn"
            }
            onClick={() => setPeriode(p.valeur)}
          >
            <span>{p.icone}</span>

            {p.label}
          </button>

        ))}

      </div>


      {/* KPIs */}

      <div className="kpi-grid">

        <div className="kpi-card kpi-accent">

          <div className="kpi-label">
            Total encaissé
          </div>

          <div className="kpi-value font-display">

            {Number(
              stats.chiffre_affaires
            ).toLocaleString("fr-FR")}

            <span> FCFA</span>

          </div>

        </div>


        <div className="kpi-card">

          <div className="kpi-label">
            Nombre de ventes
          </div>

          <div className="kpi-value font-display">
            {stats.nombre_commandes}
          </div>

        </div>


        <div className="kpi-card">

          <div className="kpi-label">
            Panier moyen
          </div>

          <div className="kpi-value font-display">

            {Number(
              stats.panier_moyen
            ).toLocaleString("fr-FR")}

            <span> FCFA</span>

          </div>

        </div>

      </div>


      {/* ÉVOLUTION */}

      <div className="admin-panel admin-panel-wide">

        <h3>
          📈 Évolution des ventes
        </h3>

        {!stats.evolution ||
        stats.evolution.length === 0 ? (

          <EmptyState
            icon="📭"
            title="Aucune vente pour cette période"
          />

        ) : (

          <div className="caisse-evolution">

            {stats.evolution.map((item) => (

              <div
                className="caisse-evolution-row"
                key={item.date}
              >

                <span className="caisse-date">

                  {item.label}

                </span>

                <div className="caisse-evolution-montant">

                  {Number(
                    item.total
                  ).toLocaleString("fr-FR")} FCFA

                </div>

                <div className="caisse-commandes">

                  {item.commandes} vente
                  {item.commandes > 1 ? "s" : ""}

                </div>

              </div>

            ))}

          </div>

        )}

      </div>


      {/* DERNIÈRES COMMANDES */}

      <div className="admin-panel admin-panel-wide">

        <h3>
          🧾 Dernières ventes
        </h3>

        {stats.commandes.length === 0 ? (

          <EmptyState
            icon="🧾"
            title="Aucune vente"
          />

        ) : (

          <div className="recent-table">

            <div className="recent-head">

              <span>N°</span>
              <span>Table</span>
              <span>Articles</span>
              <span>Total</span>
              <span>Statut</span>
              <span>Date</span>

            </div>


            {stats.commandes.map((cmd) => (

              <div
                className="recent-row"
                key={cmd.id}
              >

                <span className="font-mono">

                  #{cmd.id}

                </span>

                <span>

                  {cmd.numero_table || "—"}

                </span>


                <span className="recent-lignes">

                  {cmd.lignes
                    ?.map(
                      (l) =>
                        `${l.quantite}x ${l.plat_nom}`
                    )
                    .join(", ")}

                </span>


                <span className="font-mono">

                  {Number(
                    cmd.total
                  ).toLocaleString("fr-FR")} F

                </span>


                <span>

                  {cmd.statut}

                </span>


                <span>

                  {new Date(
                    cmd.date_creation
                  ).toLocaleString("fr-FR")}

                </span>

              </div>

            ))}

          </div>

        )}

      </div>

    </div>
  );
}