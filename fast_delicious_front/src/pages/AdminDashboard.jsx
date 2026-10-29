import { useCallback, useEffect, useState } from "react";
import client from "../api/client";
import StaffSidebar from "../components/StaffSidebar";
import EmptyState from "../components/EmptyState";
import TicketModal from "../components/TicketModal";
import ProduitsContenu from "../components/ProduitsContenu";
import VenteDirecteContenu from "../components/VenteDirecteContenu";
import CaisseContenu from "../components/CaisseContenu";
import CategoriesContenu from "../components/CategoriesContenu";
import TablesContenu from "../components/TablesContenu";
import LieuxContenu from "../components/LieuxContenu";
import EmployesContenu from "../components/EmployesContenu";
import CommandesContenu from "../components/CommandesContenu";
import AnimatedNumber from "../components/AnimatedNumber";
import ParametresContenu from "../components/ParametresContenu";
import { useDashboardSocket } from "../hooks/useDashboardSocket";
import { jouerNotification } from "../utils/son";
import "./AdminDashboard.css";

const LABELS_STATUT = {
  EN_ATTENTE: "En attente",
  VALIDEE: "Validée",
  EN_PREPARATION: "En préparation",
  PRETE: "Prête",
  EN_LIVRAISON: "En livraison",
  SERVIE: "Servie",
  ANNULEE: "Annulée",
};

const COULEUR_STATUT = {
  EN_ATTENTE: "gold",
  VALIDEE: "gold",
  EN_PREPARATION: "gold",
  PRETE: "green",
  EN_LIVRAISON: "green",
  SERVIE: "ink",
  ANNULEE: "red",
};

const ITEMS_SIDEBAR = [
  { icone: "📊", label: "Dashboard" },
  { icone: "💰", label: "État de la caisse" },
  { icone: "🛒", label: "Vente directe" },
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
  const [lieuFiltre, setLieuFiltre] = useState("");

  // "" = aujourd'hui
  // "2026-09-07" = historique
  const [dateFiltre, setDateFiltre] = useState("");

  /*
   * ============================================================
   * CHARGEMENT DES STATISTIQUES
   * ============================================================
   */
  const charger = useCallback(
    async (silencieux = false) => {
      if (!silencieux) {
        setActualisation(true);
      }

      setErreur(null);

      try {
        const params = new URLSearchParams();

        if (lieuFiltre) {
          params.append("lieu", String(lieuFiltre));
        }

        /*
         * IMPORTANT :
         * On envoie exactement la date choisie dans le calendrier.
         *
         * Exemple :
         * date=2026-09-07
         */
        if (dateFiltre) {
          params.append("date", dateFiltre);
        }

        const queryString = params.toString();

        const url = queryString
          ? `admin/statistiques/?${queryString}`
          : "admin/statistiques/";

        console.log("📊 Chargement statistiques :", url);

        const response = await client.get(url);

        console.log("📊 Réponse statistiques :", response.data);

        setStats(response.data);
      } catch (error) {
        console.error(
          "❌ Erreur chargement statistiques :",
          error?.response?.data || error
        );

        setStats(null);

        if (error?.response?.status === 400) {
          setErreur(
            error?.response?.data?.detail ||
              "La date sélectionnée n'est pas valide."
          );
        } else if (error?.response?.status === 401) {
          setErreur("Votre session a expiré. Veuillez vous reconnecter.");
        } else if (error?.response?.status === 403) {
          setErreur(
            "Vous n'avez pas l'autorisation de consulter ces statistiques."
          );
        } else {
          setErreur(
            "Impossible de charger les statistiques pour cette date."
          );
        }
      } finally {
        if (!silencieux) {
          setActualisation(false);
        } else {
          setActualisation(false);
        }
      }
    },
    [lieuFiltre, dateFiltre]
  );

  /*
   * ============================================================
   * CHARGEMENT DES LIEUX
   * ============================================================
   */
  useEffect(() => {
    client
      .get("menu/lieux/")
      .then((res) => {
        setLieux(Array.isArray(res.data) ? res.data : []);
      })
      .catch((error) => {
        console.error("Erreur chargement lieux :", error);
      });
  }, []);

  /*
   * ============================================================
   * CHARGEMENT LORSQUE LA DATE OU LE LIEU CHANGE
   * ============================================================
   */
  useEffect(() => {
    charger();

    /*
     * Si une date historique est sélectionnée,
     * on NE rafraîchit PAS automatiquement.
     */
    if (dateFiltre) {
      return undefined;
    }

    /*
     * Aujourd'hui :
     * rafraîchissement automatique toutes les 20 secondes.
     */
    const id = setInterval(() => {
      charger(true);
    }, 20000);

    return () => clearInterval(id);
  }, [charger, dateFiltre]);

  /*
   * ============================================================
   * WEBSOCKET / TEMPS RÉEL
   * ============================================================
   */
  const surEvenement = useCallback(() => {
    /*
     * Pour une date historique, on ne touche pas aux données.
     */
    if (dateFiltre) {
      return;
    }

    jouerNotification();
    charger(true);
  }, [dateFiltre, charger]);

  const { connecte: connecteCaisse } = useDashboardSocket(
    "caisse",
    surEvenement
  );

  const { connecte: connecteCuisine } = useDashboardSocket(
    "cuisine",
    surEvenement
  );

  const { connecte: connecteLivraison } = useDashboardSocket(
    "livraison",
    surEvenement
  );

  const connecte =
    connecteCaisse &&
    connecteCuisine &&
    connecteLivraison;

  /*
   * ============================================================
   * DATE AFFICHÉE
   * ============================================================
   */
  function dateLisible(date) {
    if (!date) {
      return "Aujourd'hui";
    }

    /*
     * On évite les problèmes de décalage UTC avec :
     * new Date("2026-09-07")
     *
     * On construit directement la date locale.
     */
    const morceaux = String(date).split("-");

    if (morceaux.length === 3) {
      const annee = Number(morceaux[0]);
      const mois = Number(morceaux[1]) - 1;
      const jour = Number(morceaux[2]);

      const d = new Date(annee, mois, jour);

      return d.toLocaleDateString("fr-FR", {
        day: "2-digit",
        month: "long",
        year: "numeric",
      });
    }

    return String(date);
  }

  /*
   * ============================================================
   * TABLEAU DE BORD
   * ============================================================
   */
  function contenuTableauDeBord() {
    if (erreur) {
      return (
        <div className="admin-etat">
          <span aria-hidden="true">⚠️</span>

          <p>{erreur}</p>

          <button
            className="refresh-btn"
            onClick={() => charger()}
          >
            🔄 Réessayer
          </button>
        </div>
      );
    }

    if (!stats) {
      return (
        <p className="chargement-texte">
          Chargement des statistiques...
        </p>
      );
    }

    /*
     * Sécurisation des tableaux venant de l'API
     */
    const topPlats = Array.isArray(stats.top_plats)
      ? stats.top_plats
      : [];

    const commandesRecentes = Array.isArray(
      stats.commandes_recentes
    )
      ? stats.commandes_recentes
      : [];

    const commandesParStatut =
      stats.commandes_par_statut &&
      typeof stats.commandes_par_statut === "object"
        ? stats.commandes_par_statut
        : {};

    const maxTopPlat = Math.max(
      ...topPlats.map((p) => Number(p.quantite) || 0),
      1
    );

    const totalCommandesStatut =
      Object.values(commandesParStatut).reduce(
        (a, b) => a + (Number(b) || 0),
        0
      ) || 1;

    /*
     * Déterminer la date réellement affichée.
     */
    const dateAffichee =
      stats.date || dateFiltre || "";

    const estAujourdHui =
      !dateFiltre ||
      stats.est_aujourdhui === true;

    return (
      <div className="admin-dashboard">

        {/* =====================================================
            BARRE DE FILTRES
        ====================================================== */}
        <div className="admin-toolbar">

          {lieux.length > 1 && (
            <select
              className="lieu-select"
              value={lieuFiltre}
              onChange={(e) =>
                setLieuFiltre(e.target.value)
              }
            >
              <option value="">
                📍 Tous les lieux
              </option>

              {lieux.map((l) => (
                <option
                  key={l.id}
                  value={l.id}
                >
                  📍 {l.nom}
                </option>
              ))}
            </select>
          )}

          <input
            type="date"
            className="date-select"
            value={dateFiltre}
            max={new Date()
              .toLocaleDateString("en-CA")}
            onChange={(e) => {
              const nouvelleDate = e.target.value;

              console.log(
                "📅 Date sélectionnée :",
                nouvelleDate
              );

              setDateFiltre(nouvelleDate);
            }}
          />

          {dateFiltre && (
            <button
              className="date-reset-btn"
              onClick={() => {
                console.log(
                  "📅 Retour à aujourd'hui"
                );

                setDateFiltre("");
              }}
            >
              ↩ Aujourd'hui
            </button>
          )}

          <button
            className="refresh-btn"
            onClick={() => charger()}
            disabled={actualisation}
          >
            {actualisation
              ? "Actualisation..."
              : "🔄 Actualiser"}
          </button>
        </div>

        {/* =====================================================
            BANDEAU DATE
        ====================================================== */}
        {!estAujourdHui && (
          <div className="historique-bandeau">
            🕓 Historique du{" "}
            <strong>
              {dateLisible(dateAffichee)}
            </strong>
          </div>
        )}

        {estAujourdHui && (
          <div className="historique-bandeau">
            🟢 Données du jour —{" "}
            <strong>
              {dateLisible(dateAffichee)}
            </strong>
          </div>
        )}

        {/* =====================================================
            KPI
        ====================================================== */}
        <div className="kpi-grid">

          <div className="kpi-card">
            <div className="kpi-label">
              {estAujourdHui
                ? "Commandes aujourd'hui"
                : "Commandes du jour"}
            </div>

            <div className="kpi-value font-display">
              <AnimatedNumber value={stats.nombre_commandes || 0} />
            </div>
          </div>

          <div className="kpi-card kpi-accent">
            <div className="kpi-label">
              Chiffre d'affaires
            </div>

            <div className="kpi-value font-display">
              <AnimatedNumber value={stats.chiffre_affaires || 0} />

              <span> FCFA</span>
            </div>
          </div>

          <div className="kpi-card">
            <div className="kpi-label">
              Panier moyen
            </div>

            <div className="kpi-value font-display">
              <AnimatedNumber value={stats.panier_moyen || 0} />

              <span> FCFA</span>
            </div>
          </div>

        </div>

        {/* =====================================================
            STATUTS + TOP PLATS
        ====================================================== */}
        <div className="admin-columns">

          <div className="admin-panel">
            <h3>
              Commandes par statut
            </h3>

            {Object.keys(commandesParStatut).length ===
            0 ||
            Object.values(commandesParStatut).every(
              (n) => Number(n) === 0
            ) ? (
              <EmptyState
                icon="📭"
                title={
                  estAujourdHui
                    ? "Aucune commande aujourd'hui"
                    : "Aucune commande pour cette date"
                }
              />
            ) : (
              <div className="statut-bars">
                {Object.entries(
                  commandesParStatut
                ).map(([statut, n]) => (
                  <div
                    className="statut-row"
                    key={statut}
                  >
                    <span className="statut-label">
                      {LABELS_STATUT[statut] ||
                        statut}
                    </span>

                    <div className="statut-track">
                      <div
                        className={`statut-fill statut-${
                          COULEUR_STATUT[statut] ||
                          "gold"
                        }`}
                        style={{
                          width: `${
                            (Number(n) /
                              totalCommandesStatut) *
                            100
                          }%`,
                        }}
                      />
                    </div>

                    <span className="statut-count font-mono">
                      {n}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="admin-panel">
            <h3>
              Plats les plus vendus
            </h3>

            {topPlats.length === 0 ? (
              <EmptyState
                icon="🍽️"
                title={
                  estAujourdHui
                    ? "Pas encore de ventes"
                    : "Aucune vente pour cette date"
                }
              />
            ) : (
              <div className="top-plats">
                {topPlats.map((p, i) => (
                  <div
                    className="top-plat-row"
                    key={`${p.nom}-${i}`}
                  >
                    <span className="top-plat-rank font-mono">
                      #{i + 1}
                    </span>

                    <div className="top-plat-info">
                      <span className="top-plat-name">
                        {p.nom}
                      </span>

                      <div className="top-plat-track">
                        <div
                          className="top-plat-fill"
                          style={{
                            width: `${
                              (Number(p.quantite) /
                                maxTopPlat) *
                              100
                            }%`,
                          }}
                        />
                      </div>
                    </div>

                    <span className="top-plat-qty font-mono">
                      {p.quantite}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </div>

        </div>

        {/* =====================================================
            COMMANDES RÉCENTES
        ====================================================== */}
        <div className="admin-panel admin-panel-wide">

          <h3>
            {estAujourdHui
              ? "Commandes récentes"
              : `Commandes du ${dateLisible(
                  dateAffichee
                )}`}
          </h3>

          {commandesRecentes.length === 0 ? (
            <EmptyState
              icon="🧾"
              title={
                estAujourdHui
                  ? "Aucune commande pour le moment"
                  : "Aucune commande pour cette date"
              }
            />
          ) : (
            <div className="recent-table">

              <div className="recent-head">
                <span>N°</span>
                <span>Table</span>
                <span>Articles</span>
                <span>Total</span>
                <span>Paiement</span>
                <span>Statut</span>
                <span>Heure</span>
              </div>

              {commandesRecentes.map((cmd) => (
                <div
                  className="recent-row recent-row-cliquable"
                  key={cmd.id}
                  onClick={() =>
                    setTicketOuvert(cmd)
                  }
                >

                  <span className="font-mono">
                    #{cmd.id}
                  </span>

                  <span>
                    {cmd.numero_table || "—"}
                  </span>

                  <span className="recent-lignes">
                    {Array.isArray(cmd.lignes)
                      ? cmd.lignes
                          .map(
                            (l) =>
                              `${l.quantite}x ${l.plat_nom}`
                          )
                          .join(", ")
                      : "—"}
                  </span>

                  <span className="font-mono">
                    {Number(
                      cmd.total || 0
                    ).toLocaleString("fr-FR")}{" "}
                    F
                  </span>

                  <span className="recent-paiement">
                    {cmd.mode_paiement ===
                    "ESPECES" ? (
                      "💵 Espèces"
                    ) : (
                      <>
                        <span
                          className={`paiement-tag paiement-tag-${String(
                            cmd.mode_paiement || ""
                          ).toLowerCase()}`}
                        >
                          {cmd.mode_paiement ===
                          "WAVE"
                            ? "🌊 Wave"
                            : cmd.mode_paiement ===
                              "ORANGE_MONEY"
                            ? "🟠 OM"
                            : "🔷 QR"}
                        </span>

                        {cmd.reference_paiement && (
                          <span className="recent-reference font-mono">
                            {
                              cmd.reference_paiement
                            }
                          </span>
                        )}
                      </>
                    )}
                  </span>

                  <span
                    className={`recent-badge statut-${
                      COULEUR_STATUT[
                        cmd.statut
                      ] || "gold"
                    }`}
                  >
                    {LABELS_STATUT[
                      cmd.statut
                    ] || cmd.statut}
                  </span>

                  <span className="font-mono">
                    {cmd.date_creation
                      ? new Date(
                          cmd.date_creation
                        ).toLocaleTimeString(
                          "fr-FR",
                          {
                            hour: "2-digit",
                            minute: "2-digit",
                          }
                        )
                      : "—"}
                  </span>

                </div>
              ))}
            </div>
          )}
        </div>

        {/* =====================================================
            GRAPHIQUE DES 7 DERNIERS JOURS
        ====================================================== */}
        {Array.isArray(stats.ventes_7_jours) && stats.ventes_7_jours.length > 0 && (
          <div className="admin-panel admin-panel-wide">
            <h3>Ventes des 7 derniers jours</h3>
            <div className="chart7">
              {(() => {
                const v = stats.ventes_7_jours;
                const maxV = Math.max(...v.map((d) => Number(d.total) || 0), 1);
                const jours = ["dim", "lun", "mar", "mer", "jeu", "ven", "sam"];
                return v.map((d) => {
                  const total = Number(d.total) || 0;
                  const hauteur = Math.round((total / maxV) * 100);
                  const dt = new Date(d.date);
                  return (
                    <div className="chart7-col" key={d.date}>
                      <div className="chart7-val font-mono">{total ? total.toLocaleString("fr-FR") : ""}</div>
                      <div className="chart7-bar-wrap">
                        <div className="chart7-bar" style={{ height: `${Math.max(hauteur, 2)}%` }} />
                      </div>
                      <div className="chart7-label">{jours[dt.getDay()]} {dt.getDate()}</div>
                    </div>
                  );
                });
              })()}
            </div>
          </div>
        )}

        {ticketOuvert && (
          <TicketModal
            commande={ticketOuvert}
            onFermer={() =>
              setTicketOuvert(null)
            }
          />
        )}

      </div>
    );
  }

  /*
   * ============================================================
   * DASHBOARD = résumé court (KPI + dernières commandes).
   * Les détails complets sont dans l'onglet Statistiques.
   * ============================================================
   */
  function contenuResume() {
    if (erreur) {
      return (
        <div className="admin-etat">
          <span aria-hidden="true">⚠️</span>
          <p>{erreur}</p>
          <button className="refresh-btn" onClick={() => charger()}>🔄 Réessayer</button>
        </div>
      );
    }
    if (!stats) {
      return <p className="chargement-texte">Chargement...</p>;
    }
    const recentes = Array.isArray(stats.commandes_recentes)
      ? stats.commandes_recentes.slice(0, 5)
      : [];
    return (
      <div className="admin-dashboard">
        <div className="historique-bandeau">
          🟢 Données du jour — <strong>{dateLisible(stats.date || "")}</strong>
        </div>

        <div className="kpi-grid">
          <div className="kpi-card">
            <div className="kpi-label">Commandes aujourd'hui</div>
            <div className="kpi-value font-display"><AnimatedNumber value={stats.nombre_commandes || 0} /></div>
          </div>
          <div className="kpi-card kpi-accent">
            <div className="kpi-label">Chiffre d'affaires</div>
            <div className="kpi-value font-display"><AnimatedNumber value={stats.chiffre_affaires || 0} /><span> FCFA</span></div>
          </div>
          <div className="kpi-card">
            <div className="kpi-label">Panier moyen</div>
            <div className="kpi-value font-display"><AnimatedNumber value={stats.panier_moyen || 0} /><span> FCFA</span></div>
          </div>
        </div>

        <div className="admin-panel admin-panel-wide">
          <h3>Dernières commandes</h3>
          {recentes.length === 0 ? (
            <EmptyState icon="🧾" title="Aucune commande pour le moment" />
          ) : (
            <div className="resume-liste">
              {recentes.map((cmd) => (
                <div className="resume-row" key={cmd.id} onClick={() => setTicketOuvert(cmd)}>
                  <span className="font-mono">#{cmd.id}</span>
                  <span className="resume-articles">
                    {Array.isArray(cmd.lignes) ? cmd.lignes.map((l) => `${l.quantite}x ${l.plat_nom}`).join(", ") : "—"}
                  </span>
                  <span className={`recent-badge statut-${COULEUR_STATUT[cmd.statut] || "gold"}`}>
                    {LABELS_STATUT[cmd.statut] || cmd.statut}
                  </span>
                  <span className="font-mono resume-total">{Number(cmd.total || 0).toLocaleString("fr-FR")} F</span>
                </div>
              ))}
            </div>
          )}
          <p className="resume-hint">Gérer toutes les commandes dans l'onglet 🧾 Commandes · détails et graphiques dans 📈 Statistiques.</p>
        </div>

        {ticketOuvert && (
          <TicketModal commande={ticketOuvert} onFermer={() => setTicketOuvert(null)} />
        )}
      </div>
    );
  }

  /*
   * ============================================================
   * RUBRIQUES
   * ============================================================
   */
  function contenuRubrique() {
  switch (rubrique) {

    case 1:
      return <CaisseContenu />;

    case 2:
      return <VenteDirecteContenu />;

    case 3:
      return <ProduitsContenu />;

    case 4:
      return <CategoriesContenu />;

    case 5:
      return <TablesContenu />;

    case 6:
      return <LieuxContenu />;

    case 7:
      return <EmployesContenu />;

    case 8:
      return <CommandesContenu />;

    case 9:
      return contenuTableauDeBord();

    case 10:
      return <ParametresContenu />;

    default:
      return contenuResume();

  }
}

  return (
    <StaffSidebar
      items={ITEMS_SIDEBAR}
      rubriqueActive={rubrique}
      onChangerRubrique={setRubrique}
      enfant={contenuRubrique()}
    />
  );
}