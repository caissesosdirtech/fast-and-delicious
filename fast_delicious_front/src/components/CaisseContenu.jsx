import { useEffect, useState } from "react";
import client, { API_BASE_URL } from "../api/client";
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

const AUJOURDHUI = new Date().toISOString().slice(0, 10);

export default function CaisseContenu() {
  const [periode, setPeriode] = useState("jour");
  const [dateJour, setDateJour] = useState(""); // "" = pas de date précise (on suit la période)
  const [stats, setStats] = useState(null);
  const [chargement, setChargement] = useState(true);
  const [erreur, setErreur] = useState(null);

  useEffect(() => {
    charger();
  }, [periode, dateJour]);

  async function charger() {
    setChargement(true);
    setErreur(null);

    try {
      // Une date précise est prioritaire sur la période.
      const url = dateJour
        ? `admin/caisse/?date=${dateJour}`
        : `admin/caisse/?periode=${periode}`;

      const res = await client.get(url);

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

  async function telecharger(format) {
    try {
      // On exporte la même période/date que celle affichée.
      // Le paramètre _t (horodatage) force une requête unique → jamais servie depuis le cache.
      const params = dateJour ? `date=${dateJour}` : `periode=${periode}`;
      // Pas d'en-tête personnalisé (ex. Cache-Control) : il déclencherait un preflight CORS
      // que le backend n'autorise pas. Le paramètre _t suffit à éviter le cache.
      const res = await client.get(
        `admin/caisse/export/?${params}&fmt=${format}&_t=${Date.now()}`,
        { responseType: "blob" }
      );
      const url = URL.createObjectURL(res.data);
      const a = document.createElement("a");
      a.href = url;
      a.download = `caisse.${format === "xlsx" ? "xlsx" : "pdf"}`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
    } catch (error) {
      console.error("Export caisse:", error);
      const st = error?.response?.status;
      let detail = "";
      // Si le serveur a renvoyé une erreur JSON dans un blob, on la lit.
      try {
        if (error?.response?.data instanceof Blob) {
          const texte = await error.response.data.text();
          detail = texte.slice(0, 160);
        }
      } catch (_) {
        /* ignore */
      }
      const urlAppel = `${API_BASE_URL}/api/admin/caisse/export/`;
      alert(
        "Téléchargement impossible.\n" +
          (st ? `Code : ${st}\n` : `Erreur réseau : ${error?.message || "inconnue"}\n`) +
          (detail ? `Détail : ${detail}\n` : "") +
          `URL appelée : ${urlAppel}`
      );
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

        <div className="caisse-actions">
          <button className="refresh-btn" onClick={() => telecharger("pdf")}>
            📄 PDF
          </button>
          <button className="refresh-btn" onClick={() => telecharger("xlsx")}>
            📊 Excel
          </button>
          <button className="refresh-btn" onClick={charger}>
            🔄 Actualiser
          </button>
        </div>
      </div>

      {/* BOUTONS DES PÉRIODES */}

      <div className="caisse-periodes">

        {PERIODES.map((p) => (

          <button
            key={p.valeur}
            className={
              !dateJour && periode === p.valeur
                ? "caisse-periode-active"
                : "caisse-periode-btn"
            }
            onClick={() => {
              setDateJour("");
              setPeriode(p.valeur);
            }}
          >
            <span>{p.icone}</span>

            {p.label}
          </button>

        ))}

        {/* Sélecteur de date précise (comme sur mobile) */}
        <input
          type="date"
          className="caisse-date-input"
          value={dateJour}
          max={AUJOURDHUI}
          onChange={(e) => setDateJour(e.target.value)}
          title="Choisir une date précise"
        />

        {dateJour && (
          <button
            className="caisse-periode-btn"
            onClick={() => setDateJour("")}
          >
            <span>↩</span>
            Aujourd'hui
          </button>
        )}

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