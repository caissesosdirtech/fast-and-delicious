import { useCallback, useEffect, useState } from "react";
import client from "../api/client";
import StaffSidebar from "../components/StaffSidebar";
import EmptyState from "../components/EmptyState";
import TicketModal from "../components/TicketModal";
import ProduitsContenu from "../components/ProduitsContenu";
import CategoriesContenu from "../components/CategoriesContenu";
import TablesContenu from "../components/TablesContenu";
import LieuxContenu from "../components/LieuxContenu";
import EmployesContenu from "../components/EmployesContenu";
import ParametresContenu from "../components/ParametresContenu";
import { useDashboardSocket } from "../hooks/useDashboardSocket";
import { jouerNotification } from "../utils/son";
import "./AdminDashboard.css";

const LABELS_STATUT = {
  EN_ATTENTE: "En attente", VALIDEE: "Validée", EN_PREPARATION: "En préparation",
  PRETE: "Prête", EN_LIVRAISON: "En livraison", SERVIE: "Servie", ANNULEE: "Annulée",
};
const COULEUR_STATUT = {
  EN_ATTENTE: "gold", VALIDEE: "gold", EN_PREPARATION: "gold",
  PRETE: "green", EN_LIVRAISON: "green", SERVIE: "ink", ANNULEE: "red",
};

const ITEMS_SIDEBAR = [
  { icone: "📊", label: "Dashboard" },
  { icone: "🍔", label: "Produits" },
  { icone: "🏷️", label: "Catégories" },
  { icone: "🍽️", label: "Tables" },
  { icone: "📍", label: "Lieux" },
  { icone: "👤", label: "Employés" },
  { icone: "🧾", label: "Commandes" },
  { icone: "📈", label: "Statistiques" },
  { icone: "⚙️", label: "Paramètres" },
];

export default function AdminDashboard() {
  const [rubrique, setRubrique] = useState(0);
  const [stats, setStats] = useState(null);
  const [erreur, setErreur] = useState(null);
  const [actualisation, setActualisation] = useState(false);
  const [ticketOuvert, setTicketOuvert] = useState(null);
  const [lieux, setLieux] = useState([]);
  const [lieuFiltre, setLieuFiltre] = useState(""); // "" = tous les lieux
  const [dateFiltre, setDateFiltre] = useState(""); // "" = aujourd'hui

  const charger = useCallback((silencieux = false) => {
    if (!silencieux) setActualisation(true);
    const params = new URLSearchParams();
    if (lieuFiltre) params.set("lieu", lieuFiltre);
    if (dateFiltre) params.set("date", dateFiltre);
    const requete = params.toString() ? `?${params.toString()}` : "";
    client
      .get(`admin/statistiques/${requete}`)
      .then((res) => setStats(res.data))
      .catch(() => setErreur("Impossible de charger les statistiques."))
      .finally(() => setActualisation(false));
  }, [lieuFiltre, dateFiltre]);

  useEffect(() => {
    client.get("menu/lieux/").then((res) => setLieux(res.data));
  }, []);

  useEffect(() => {
    charger();
    if (dateFiltre) return; // pas de rafraîchissement auto sur un historique figé
    const id = setInterval(() => charger(true), 20000);
    return () => clearInterval(id);
  }, [charger, dateFiltre]);

  const surEvenement = () => {
    if (dateFiltre) return; // événements temps réel ignorés hors de "aujourd'hui"
    jouerNotification();
    charger(true);
  };
  const { connecte: connecteCaisse } = useDashboardSocket("caisse", surEvenement);
  const { connecte: connecteCuisine } = useDashboardSocket("cuisine", surEvenement);
  const { connecte: connecteLivraison } = useDashboardSocket("livraison", surEvenement);
  const connecte = connecteCaisse && connecteCuisine && connecteLivraison;

  function contenuTableauDeBord() {
    if (erreur) {
      return (
        <div className="admin-etat">
          <span aria-hidden="true">⚠️</span>
          <p>{erreur}</p>
        </div>
      );
    }
    if (!stats) return <p className="chargement-texte">Chargement des statistiques...</p>;

    const maxTopPlat = Math.max(...stats.top_plats.map((p) => p.quantite), 1);
    const totalCommandesStatut = Object.values(stats.commandes_par_statut).reduce((a, b) => a + b, 0) || 1;

    return (
      <div className="admin-dashboard">
        <div className="admin-toolbar">
          {lieux.length > 1 && (
            <select className="lieu-select" value={lieuFiltre} onChange={(e) => setLieuFiltre(e.target.value)}>
              <option value="">📍 Tous les lieux</option>
              {lieux.map((l) => (
                <option key={l.id} value={l.id}>📍 {l.nom}</option>
              ))}
            </select>
          )}
          <input
            type="date"
            className="date-select"
            value={dateFiltre}
            max={new Date().toISOString().slice(0, 10)}
            onChange={(e) => setDateFiltre(e.target.value)}
          />
          {dateFiltre && (
            <button className="date-reset-btn" onClick={() => setDateFiltre("")}>
              ↩ Aujourd'hui
            </button>
          )}
          <button className="refresh-btn" onClick={() => charger()} disabled={actualisation}>
            {actualisation ? "Actualisation..." : "🔄 Actualiser"}
          </button>
        </div>

        {!stats.est_aujourdhui && (
          <div className="historique-bandeau">
            🕓 Historique du {new Date(stats.date).toLocaleDateString("fr-FR", { day: "2-digit", month: "long", year: "numeric" })}
          </div>
        )}

        <div className="kpi-grid">
          <div className="kpi-card">
            <div className="kpi-label">Commandes aujourd'hui</div>
            <div className="kpi-value font-display">{stats.nombre_commandes}</div>
          </div>
          <div className="kpi-card kpi-accent">
            <div className="kpi-label">Chiffre d'affaires</div>
            <div className="kpi-value font-display">
              {Number(stats.chiffre_affaires).toLocaleString("fr-FR")} <span>FCFA</span>
            </div>
          </div>
          <div className="kpi-card">
            <div className="kpi-label">Panier moyen</div>
            <div className="kpi-value font-display">
              {Number(stats.panier_moyen).toLocaleString("fr-FR")} <span>FCFA</span>
            </div>
          </div>
        </div>

        <div className="admin-columns">
          <div className="admin-panel">
            <h3>Commandes par statut</h3>
            {Object.entries(stats.commandes_par_statut).every(([, n]) => n === 0) ? (
              <EmptyState icon="📭" title="Aucune commande aujourd'hui" />
            ) : (
              <div className="statut-bars">
                {Object.entries(stats.commandes_par_statut).map(([statut, n]) => (
                  <div className="statut-row" key={statut}>
                    <span className="statut-label">{LABELS_STATUT[statut]}</span>
                    <div className="statut-track">
                      <div
                        className={`statut-fill statut-${COULEUR_STATUT[statut]}`}
                        style={{ width: `${(n / totalCommandesStatut) * 100}%` }}
                      />
                    </div>
                    <span className="statut-count font-mono">{n}</span>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="admin-panel">
            <h3>Plats les plus vendus</h3>
            {stats.top_plats.length === 0 ? (
              <EmptyState icon="🍽️" title="Pas encore de ventes" />
            ) : (
              <div className="top-plats">
                {stats.top_plats.map((p, i) => (
                  <div className="top-plat-row" key={p.nom}>
                    <span className="top-plat-rank font-mono">#{i + 1}</span>
                    <div className="top-plat-info">
                      <span className="top-plat-name">{p.nom}</span>
                      <div className="top-plat-track">
                        <div className="top-plat-fill" style={{ width: `${(p.quantite / maxTopPlat) * 100}%` }} />
                      </div>
                    </div>
                    <span className="top-plat-qty font-mono">{p.quantite}</span>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        <div className="admin-panel admin-panel-wide">
          <h3>Commandes récentes</h3>
          {stats.commandes_recentes.length === 0 ? (
            <EmptyState icon="🧾" title="Aucune commande pour le moment" />
          ) : (
            <div className="recent-table">
              <div className="recent-head">
                <span>N°</span><span>Table</span><span>Articles</span><span>Total</span>
                <span>Paiement</span><span>Statut</span><span>Heure</span>
              </div>
              {stats.commandes_recentes.map((cmd) => (
                <div className="recent-row recent-row-cliquable" key={cmd.id} onClick={() => setTicketOuvert(cmd)}>
                  <span className="font-mono">#{cmd.id}</span>
                  <span>{cmd.numero_table || "—"}</span>
                  <span className="recent-lignes">{cmd.lignes.map((l) => `${l.quantite}x ${l.plat_nom}`).join(", ")}</span>
                  <span className="font-mono">{Number(cmd.total).toLocaleString("fr-FR")} F</span>
                  <span className="recent-paiement">
                    {cmd.mode_paiement === "ESPECES" ? "💵 Espèces" : (
                      <>
                        <span className={`paiement-tag paiement-tag-${cmd.mode_paiement.toLowerCase()}`}>
                          {cmd.mode_paiement === "WAVE" ? "🌊 Wave" : cmd.mode_paiement === "ORANGE_MONEY" ? "🟠 OM" : "🔷 QR"}
                        </span>
                        <span className="recent-reference font-mono">{cmd.reference_paiement}</span>
                      </>
                    )}
                  </span>
                  <span className={`recent-badge statut-${COULEUR_STATUT[cmd.statut]}`}>{LABELS_STATUT[cmd.statut]}</span>
                  <span className="font-mono">
                    {new Date(cmd.date_creation).toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" })}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>

        {ticketOuvert && <TicketModal commande={ticketOuvert} onFermer={() => setTicketOuvert(null)} />}
      </div>
    );
  }

  function contenuRubrique() {
    switch (rubrique) {
      case 1: return <ProduitsContenu />;
      case 2: return <CategoriesContenu />;
      case 3: return <TablesContenu />;
      case 4: return <LieuxContenu />;
      case 5: return <EmployesContenu />;
      case 8: return <ParametresContenu />;
      default: return contenuTableauDeBord();
    }
  }

  return (
    <StaffSidebar items={ITEMS_SIDEBAR} rubriqueActive={rubrique} onChangerRubrique={setRubrique} enfant={contenuRubrique()} />
  );
}
