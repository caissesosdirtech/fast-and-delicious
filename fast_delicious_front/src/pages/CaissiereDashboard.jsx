import { useCallback, useEffect, useState } from "react";
import client from "../api/client";
import { useDashboardSocket } from "../hooks/useDashboardSocket";
import StaffSidebar from "../components/StaffSidebar";
import KpiCard from "../components/KpiCard";
import EmptyState from "../components/EmptyState";
import ClientsContenu from "../components/ClientsContenu";
import ParametresContenu from "../components/ParametresContenu";
import TicketModal from "../components/TicketModal";
import { detailsLigne } from "../utils/ligne";
import { jouerNotification } from "../utils/son";
import "./CaissiereDashboard.css";

const LABELS_STATUT = {
  EN_ATTENTE: "En attente", VALIDEE: "Validée", EN_PREPARATION: "En préparation",
  PRETE: "Prête", EN_LIVRAISON: "En livraison", SERVIE: "Servie", ANNULEE: "Annulée",
};
const COULEUR_STATUT = {
  EN_ATTENTE: "gold", VALIDEE: "gold", EN_PREPARATION: "gold",
  PRETE: "green", EN_LIVRAISON: "green", SERVIE: "ink", ANNULEE: "red",
};

const ITEMS_SIDEBAR = [
  { icone: "📊", label: "Tableau de bord" },
  { icone: "🧾", label: "Commandes" },
  { icone: "💳", label: "Paiements" },
  { icone: "🕓", label: "Historique" },
  { icone: "👥", label: "Clients" },
  { icone: "⚙️", label: "Paramètres" },
];

export default function CaissiereDashboard() {
  const [rubrique, setRubrique] = useState(0);
  const [commandes, setCommandes] = useState([]);
  const [stats, setStats] = useState(null);
  const [paiementsRecents, setPaiementsRecents] = useState(null);
  const [historiqueRecent, setHistoriqueRecent] = useState(null);
  const [selectionnee, setSelectionnee] = useState(null);
  const [enTraitement, setEnTraitement] = useState({});
  const [ticketOuvert, setTicketOuvert] = useState(null);

  const charger = useCallback(() => {
    Promise.all([client.get("caisse/commandes/"), client.get("admin/statistiques/")]).then(([c, s]) => {
      setCommandes(c.data);
      setStats(s.data);
      setSelectionnee((prev) => (prev ? c.data.find((cmd) => cmd.id === prev.id) || null : null));
    });
  }, []);

  const chargerPaiementsRecents = useCallback(() => {
    client.get("caisse/paiements-recents/").then((res) => setPaiementsRecents(res.data));
  }, []);

  const chargerHistoriqueRecent = useCallback(() => {
    client.get("caisse/historique-recent/").then((res) => setHistoriqueRecent(res.data));
  }, []);

  useEffect(() => {
    charger();
    const id = setInterval(charger, 20000);
    return () => clearInterval(id);
  }, [charger]);

  // Chargées à la demande, seulement quand on ouvre chaque rubrique (pas besoin sinon).
  useEffect(() => {
    if (rubrique === 2) chargerPaiementsRecents();
    if (rubrique === 3) chargerHistoriqueRecent();
  }, [rubrique, chargerPaiementsRecents, chargerHistoriqueRecent]);

  const { connecte } = useDashboardSocket("caisse", (data) => {
    if (data.evenement === "nouvelle_commande") jouerNotification();
    charger();
    if (rubrique === 2) chargerPaiementsRecents();
    if (rubrique === 3) chargerHistoriqueRecent();
  });

  async function encaisser(commandeId) {
    setEnTraitement((p) => ({ ...p, [commandeId]: true }));
    try {
      await client.patch(`caisse/commandes/${commandeId}/encaisser/`);
      charger();
    } finally {
      setEnTraitement((p) => ({ ...p, [commandeId]: false }));
    }
  }

  async function valider(commandeId) {
    setEnTraitement((p) => ({ ...p, [commandeId]: true }));
    try {
      await client.patch(`caisse/commandes/${commandeId}/valider/`);
      charger();
    } finally {
      setEnTraitement((p) => ({ ...p, [commandeId]: false }));
    }
  }

  async function prete(commandeId) {
    setEnTraitement((p) => ({ ...p, [commandeId]: true }));
    try {
      await client.patch(`caisse/commandes/${commandeId}/prete/`);
      charger();
    } finally {
      setEnTraitement((p) => ({ ...p, [commandeId]: false }));
    }
  }

  async function terminer(commandeId) {
    setEnTraitement((p) => ({ ...p, [commandeId]: true }));
    try {
      await client.patch(`caisse/commandes/${commandeId}/terminer/`);
      charger();
    } finally {
      setEnTraitement((p) => ({ ...p, [commandeId]: false }));
    }
  }

  async function annuler(commandeId) {
    const motif = window.prompt("Motif de l'annulation (ex: Référence de paiement invalide) :");
    if (motif === null) return;
    setEnTraitement((p) => ({ ...p, [commandeId]: true }));
    try {
      await client.patch(`commandes/${commandeId}/annuler/`, { motif });
      setCommandes((prev) => prev.filter((c) => c.id !== commandeId));
      setSelectionnee((prev) => (prev?.id === commandeId ? null : prev));
    } finally {
      setEnTraitement((p) => ({ ...p, [commandeId]: false }));
    }
  }

  function badgeStatut(statut) {
    return <span className={`badge-statut statut-${COULEUR_STATUT[statut]}`}>{LABELS_STATUT[statut] || statut}</span>;
  }

  function contenuRubrique() {
    if (rubrique === 4) return <ClientsContenu />;
    if (rubrique === 5) return <ParametresContenu />;

    if (rubrique === 2) {
      if (paiementsRecents === null) return <p className="chargement-texte">Chargement...</p>;
      return (
        <ListeSimple
          titre="10 derniers paiements mobile money"
          commandes={paiementsRecents}
          vide="Aucun paiement mobile money pour le moment."
          badgeStatut={badgeStatut}
          onOuvrirTicket={setTicketOuvert}
        />
      );
    }
    if (rubrique === 3) {
      if (historiqueRecent === null) return <p className="chargement-texte">Chargement...</p>;
      return (
        <ListeSimple
          titre="10 dernières commandes terminées"
          commandes={historiqueRecent}
          vide="Aucune commande terminée pour le moment."
          badgeStatut={badgeStatut}
          onOuvrirTicket={setTicketOuvert}
        />
      );
    }

    if (!stats) return <p className="chargement-texte">Chargement...</p>;

    const parStatut = stats.commandes_par_statut;

    // Rubrique 0 = Tableau de bord : les statistiques du jour (pas la liste des commandes).
    if (rubrique === 0) {
      return (
        <div>
          <div className="kpi-row">
            <KpiCard label="Chiffre d'affaires" valeur={`${Number(stats.chiffre_affaires).toLocaleString("fr-FR")} F`} couleur="var(--green)" />
            <KpiCard label="Commandes du jour" valeur={stats.nombre_commandes} />
            <KpiCard label="Panier moyen" valeur={`${Number(stats.panier_moyen).toLocaleString("fr-FR")} F`} />
            <KpiCard label="En cours" valeur={commandes.length} couleur="var(--gold)" />
          </div>

          <h3 className="section-titre">Répartition des commandes</h3>
          <div className="stats-statuts">
            <div className="stat-statut"><span>En attente</span><strong>{parStatut.EN_ATTENTE || 0}</strong></div>
            <div className="stat-statut"><span>Validées</span><strong>{parStatut.VALIDEE || 0}</strong></div>
            <div className="stat-statut"><span>Prêtes</span><strong>{parStatut.PRETE || 0}</strong></div>
            <div className="stat-statut"><span>Terminées</span><strong>{parStatut.SERVIE || 0}</strong></div>
            <div className="stat-statut"><span>Annulées</span><strong>{parStatut.ANNULEE || 0}</strong></div>
          </div>

          <h3 className="section-titre">Top plats du jour</h3>
          {(!stats.top_plats || stats.top_plats.length === 0) ? (
            <EmptyState icon="📊" title="Aucune vente pour le moment" />
          ) : (
            <div className="top-plats">
              {stats.top_plats.map((p, i) => (
                <div className="top-plat" key={p.nom}>
                  <span className="top-plat-rang">{i + 1}</span>
                  <span className="top-plat-nom">{p.nom}</span>
                  <strong>{p.quantite}</strong>
                </div>
              ))}
            </div>
          )}
        </div>
      );
    }

    // Rubrique 1 = Commandes : la liste des commandes en cours + actions.
    return (
      <div>
        <div className="kpi-row">
          <KpiCard label="En cours" valeur={commandes.length} couleur="var(--gold)" />
          <KpiCard label="Validées" valeur={parStatut.VALIDEE || 0} />
          <KpiCard label="Prêtes" valeur={parStatut.PRETE || 0} couleur="var(--green)" />
          <KpiCard label="Commandes du jour" valeur={stats.nombre_commandes} />
        </div>

        <h3 className="section-titre">Commandes en cours</h3>

        {commandes.length === 0 ? (
          <EmptyState icon="📥" title="Aucune commande en cours" />
        ) : (
          <div className="caisse-table-wrap">
            <table className="caisse-table">
              <thead>
                <tr>
                  <th>N° Commande</th><th>Table</th><th>Heure</th><th>Montant</th><th>Statut</th><th>Action</th>
                </tr>
              </thead>
              <tbody>
                {commandes.map((cmd) => (
                  <tr
                    key={cmd.id}
                    className={selectionnee?.id === cmd.id ? "ligne-selectionnee" : ""}
                    onClick={() => setSelectionnee(cmd)}
                  >
                    <td>#{cmd.id}</td>
                    <td>
                      {cmd.mode_commande === "LIVRAISON" ? "🛵" : (cmd.numero_table || "—")}
                      {cmd.lieu_nom && <div className="caisse-lieu">📍 {cmd.lieu_nom}</div>}
                    </td>
                    <td>{new Date(cmd.date_creation).toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" })}</td>
                    <td>{Number(cmd.total).toLocaleString("fr-FR")} F</td>
                    <td>{badgeStatut(cmd.statut)}</td>
                    <td onClick={(e) => e.stopPropagation()}>
                      <div className="action-icones">
                        {cmd.statut === "EN_ATTENTE" && (
                          <button className="icone-action icone-valider" title="Valider & encaisser" disabled={enTraitement[cmd.id]} onClick={() => valider(cmd.id)}>✓</button>
                        )}
                        {cmd.statut === "VALIDEE" && (
                          <button className="icone-action icone-valider" title="Marquer prête" disabled={enTraitement[cmd.id]} onClick={() => prete(cmd.id)}>▶</button>
                        )}
                        {cmd.statut === "PRETE" && (
                          <button className="icone-action icone-valider" title="Terminer" disabled={enTraitement[cmd.id]} onClick={() => terminer(cmd.id)}>✔</button>
                        )}
                        {cmd.statut !== "SERVIE" && cmd.statut !== "ANNULEE" && (
                          <button className="icone-action icone-annuler" title="Annuler" disabled={enTraitement[cmd.id]} onClick={() => annuler(cmd.id)}>✕</button>
                        )}
                        {(cmd.paiement_confirme || cmd.statut === "SERVIE") && (
                          <button className="icone-action icone-recu" title="Reçu de paiement" onClick={() => setTicketOuvert(cmd)}>🧾</button>
                        )}
                        <button className="icone-action icone-voir" title="Voir le détail" onClick={() => setSelectionnee(cmd)}>👁</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {selectionnee && (
          <DetailCommande
            commande={selectionnee}
            enTraitement={enTraitement[selectionnee.id]}
            onEncaisser={() => encaisser(selectionnee.id)}
            onValider={() => valider(selectionnee.id)}
            onPrete={() => prete(selectionnee.id)}
            onTerminer={() => terminer(selectionnee.id)}
            onAnnuler={() => annuler(selectionnee.id)}
            onRecu={() => setTicketOuvert(selectionnee)}
          />
        )}
      </div>
    );
  }

  return (
    <>
      <StaffSidebar items={ITEMS_SIDEBAR} rubriqueActive={rubrique} onChangerRubrique={setRubrique} enfant={contenuRubrique()} />
      {ticketOuvert && <TicketModal commande={ticketOuvert} onFermer={() => setTicketOuvert(null)} />}
    </>
  );
}

function DetailCommande({ commande, enTraitement, onEncaisser, onValider, onPrete, onTerminer, onAnnuler, onRecu }) {
  return (
    <div className="detail-commande">
      <div className="detail-gauche">
        <h4>Détails commande #{commande.id}</h4>
        {commande.lignes.map((l) => (
          <div className="detail-ligne" key={l.id}>
            <span>{l.quantite}x {l.plat_nom}{detailsLigne(l)}</span>
            <span>{Number(l.sous_total).toLocaleString("fr-FR")} F</span>
          </div>
        ))}
        {commande.remarque && <div className="detail-remarque">Remarque client : {commande.remarque}</div>}
        {commande.mode_paiement !== "ESPECES" && (
          <div className="detail-reference">Réf. paiement : {commande.reference_paiement}</div>
        )}
        <div className="detail-divider" />
        <div className="detail-total">
          <span>Total</span>
          <span>{Number(commande.total).toLocaleString("fr-FR")} FCFA</span>
        </div>
        {commande.paiement_confirme && <div className="detail-paiement-ok">✓ Paiement confirmé</div>}
      </div>
      <div className="detail-droite">
        {commande.statut === "EN_ATTENTE" && (
          <>
            <button className="detail-btn detail-btn-valider" disabled={enTraitement} onClick={onValider}>
              Valider &amp; encaisser
            </button>
            <button className="detail-btn detail-btn-encaisser" disabled={enTraitement || commande.paiement_confirme} onClick={onEncaisser}>
              {commande.paiement_confirme ? "✓ Encaissé" : "Encaisser"}
            </button>
          </>
        )}
        {commande.statut === "VALIDEE" && (
          <button className="detail-btn detail-btn-valider" disabled={enTraitement} onClick={onPrete}>
            Marquer prête
          </button>
        )}
        {commande.statut === "PRETE" && (
          <button className="detail-btn detail-btn-valider" disabled={enTraitement} onClick={onTerminer}>
            Terminer la commande
          </button>
        )}
        {(commande.paiement_confirme || commande.statut === "SERVIE") && (
          <button className="detail-btn detail-btn-recu" onClick={onRecu}>
            🧾 Reçu de paiement
          </button>
        )}
        {commande.statut !== "SERVIE" && commande.statut !== "ANNULEE" && (
          <button className="detail-btn detail-btn-annuler" disabled={enTraitement} onClick={onAnnuler}>
            Annuler la commande
          </button>
        )}
      </div>
    </div>
  );
}

function ListeSimple({ titre, commandes, vide, badgeStatut, onOuvrirTicket }) {
  return (
    <div>
      <h3 className="section-titre">{titre}</h3>
      {commandes.length === 0 ? (
        <EmptyState icon="📭" title={vide} />
      ) : (
        commandes.map((c) => (
          <div className="liste-simple-item" key={c.id} onClick={() => onOuvrirTicket(c)}>
            <div>
              <div className="liste-simple-id">#{c.id} · {c.numero_table || "—"}</div>
              <div className="liste-simple-articles">
                {c.lignes.map((l) => `${l.quantite}x ${l.plat_nom}`).join(", ")}
              </div>
              {c.mode_paiement !== "ESPECES" && (
                <div className="liste-simple-paiement">
                  {c.mode_paiement === "WAVE" ? "🌊 Wave" : "🟠 Orange Money"} · réf. {c.reference_paiement}
                </div>
              )}
              {c.statut === "ANNULEE" && c.motif_annulation && (
                <div className="liste-simple-motif">Motif : {c.motif_annulation}</div>
              )}
            </div>
            <div className="liste-simple-droite">
              {badgeStatut(c.statut)}
              <span className="liste-simple-total">{Number(c.total).toLocaleString("fr-FR")} F</span>
            </div>
          </div>
        ))
      )}
    </div>
  );
}
