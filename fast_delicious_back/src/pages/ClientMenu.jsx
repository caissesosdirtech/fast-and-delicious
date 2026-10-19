import { useEffect, useMemo, useRef, useState } from "react";
import client from "../api/client";
import { useCart } from "../context/CartContext";
import "./ClientMenu.css";

const ICONES_CATEGORIE = {
  "fast food": "🌯", "snack": "🌯",
  "crêpe": "🥞", "crepe": "🥞",
  "grillade": "🔥",
  "boisson": "🥤",
};

// Chaque "stand" (catégorie) prend une teinte différente, dans les mêmes couleurs que le
// ruban de fanions — le marché de kermesse devient littéralement une suite de stands colorés.
const TEINTES_STAND = ["or", "vert", "rouge", "encre"];

function iconePourCategorie(nom) {
  const cle = Object.keys(ICONES_CATEGORIE).find((k) => nom.toLowerCase().includes(k));
  return ICONES_CATEGORIE[cle] || "🍽️";
}

// Ruban de fanions façon kermesse — signature visuelle de la page. Largeur égale par fanion
// (flex:1), donc net sur n'importe quel écran sans calcul JS de position.
function RubanFanions({ nombre = 30 }) {
  const couleurs = ["var(--red)", "var(--gold)", "var(--green)", "var(--ink)"];
  return (
    <div className="ruban-fanions" aria-hidden="true">
      {Array.from({ length: nombre }).map((_, i) => (
        <span key={i} className="fanion" style={{ background: couleurs[i % couleurs.length] }} />
      ))}
    </div>
  );
}

// Bandeau défilant façon panneau lumineux de fête foraine.
function BandeauDefilant({ texte }) {
  return (
    <div className="marquee">
      <div className="marquee-track">
        <span>{texte}</span>
        <span>{texte}</span>
      </div>
    </div>
  );
}

export default function ClientMenu() {
  const [categories, setCategories] = useState([]);
  const [categorieActive, setCategorieActive] = useState(null);
  const [recherche, setRecherche] = useState("");
  const [erreur, setErreur] = useState(null);
  const [chargement, setChargement] = useState(true);
  const [choixAccompagnement, setChoixAccompagnement] = useState({}); // { platId: accompagnementId }
  const [choixGroupes, setChoixGroupes] = useState({}); // { platId: { groupeId: optionId } }
  const [erreurChoix, setErreurChoix] = useState({}); // { platId: message }
  const [lieux, setLieux] = useState([]);
  const sectionsRef = useRef({});

  const {
    quantitePourPlat, modifierQuantite, numeroTable, setNumeroTable,
    modeCommande, setModeCommande, adresseLivraison, setAdresseLivraison,
    telephoneClient, setTelephoneClient, lieu, setLieu,
    setPanierOuvert, totalArticles,
  } = useCart();

  useEffect(() => {
    // Pré-remplit le numéro de table/stand si on arrive via un QR code (ex: /?table=Stand%202)
    const params = new URLSearchParams(window.location.search);
    const tableDepuisUrl = params.get("table");
    if (tableDepuisUrl) {
      setNumeroTable(tableDepuisUrl);
    }
    const lieuDepuisUrl = params.get("lieu");
    if (lieuDepuisUrl) {
      setLieu(lieuDepuisUrl);
    }
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    // Ne s'affiche/s'active que si l'équipe a configuré plusieurs lieux (deux événements en
    // même temps) — sinon totalement invisible, comportement habituel inchangé.
    client.get("menu/lieux/").then((res) => setLieux(res.data));
  }, []);

  useEffect(() => {
    client
      .get("menu/categories/")
      .then((res) => {
        setCategories(res.data);
        if (res.data.length > 0) setCategorieActive(res.data[0].id);
      })
      .catch(() => setErreur("Impossible de charger le menu. Vérifiez que le serveur est lancé."))
      .finally(() => setChargement(false));
  }, []);

  function allerVersCategorie(catId) {
    setCategorieActive(catId);
    sectionsRef.current[catId]?.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  function ajouterAuPanier(plat) {
    // Cas 1 : formule composée (plusieurs groupes de choix, ex : Grillade + Accompagnement + Crudité)
    if (plat.groupes_choix?.length > 0) {
      const manquants = plat.groupes_choix.filter(
        (g) => g.obligatoire && !choixGroupes[plat.id]?.[g.id]
      );
      if (manquants.length > 0) {
        setErreurChoix((prev) => ({
          ...prev,
          [plat.id]: `Merci de choisir : ${manquants.map((g) => g.nom).join(", ")}.`,
        }));
        return;
      }
      const selections = plat.groupes_choix
        .filter((g) => choixGroupes[plat.id]?.[g.id])
        .map((g) => {
          const optionId = choixGroupes[plat.id][g.id];
          const option = g.options.find((o) => String(o.id) === String(optionId));
          return { groupeId: g.id, groupeNom: g.nom, optionId: option.id, optionNom: option.nom };
        });
      modifierQuantite(plat, 1, { selections });

    // Cas 2 : accompagnement simple (un seul choix optionnel/obligatoire)
    } else if (plat.accompagnements?.length > 0) {
      const choixId = choixAccompagnement[plat.id];
      if (plat.accompagnement_obligatoire && !choixId) {
        setErreurChoix((prev) => ({ ...prev, [plat.id]: "Choisis un accompagnement d'abord." }));
        return;
      }
      const accompagnement = choixId
        ? plat.accompagnements.find((a) => String(a.id) === String(choixId))
        : null;
      modifierQuantite(plat, 1, { accompagnement });

    // Cas 3 : plat simple, sans choix
    } else {
      modifierQuantite(plat, 1);
    }
    setErreurChoix((prev) => ({ ...prev, [plat.id]: null }));
  }

  // Les formules composées (ex : Formule complète) sont retirées de leur rubrique d'origine
  // pour être mises en avant à part, juste sous le bandeau.
  const formules = useMemo(
    () => categories.flatMap((cat) => cat.plats.filter((p) => p.groupes_choix?.length > 0)),
    [categories]
  );

  const categoriesSansFormules = useMemo(
    () => categories.map((cat) => ({
      ...cat,
      plats: cat.plats.filter((p) => !(p.groupes_choix?.length > 0)),
    })),
    [categories]
  );

  // Filtre les plats par recherche, sans faire disparaître les catégories qui n'ont
  // pas de résultat — elles sont simplement masquées.
  const categoriesFiltrees = useMemo(() => {
    if (!recherche.trim()) return categoriesSansFormules;
    const q = recherche.trim().toLowerCase();
    return categoriesSansFormules
      .map((cat) => ({
        ...cat,
        plats: cat.plats.filter((p) => p.nom.toLowerCase().includes(q)),
      }))
      .filter((cat) => cat.plats.length > 0);
  }, [categoriesSansFormules, recherche]);

  const totalPlats = categories.reduce((acc, c) => acc + c.plats.length, 0);

  if (chargement) {
    return <div className="menu-etat">Chargement du menu...</div>;
  }

  if (erreur && categories.length === 0) {
    return <div className="menu-etat menu-etat-erreur">{erreur}</div>;
  }

  return (
    <div className="client-menu">

      {/* Bandeau d'en-tête plein format */}
      <div className="menu-banner">
        <RubanFanions />
        <BandeauDefilant texte="🍽️ PAIEMENT ESPÈCES / WAVE / ORANGE MONEY — LIVRAISON DISPONIBLE — RETRAIT SUR PLACE 🍽️" />

        <div className="menu-banner-content">
          <h1 className="menu-hero-title font-display">Notre menu</h1>
          <p className="menu-hero-sub">Compose ta commande — <strong>{totalPlats} plats</strong> t'attendent au marché.</p>

          <a href="tel:+221761270766" className="appel-commande">
            📞 Commander par téléphone : <span className="font-mono">+221 76 127 07 66</span>
          </a>

          {lieux.length > 1 && (
            <div className="lieu-select-wrap">
              <select
                className="lieu-select-client"
                value={lieu}
                onChange={(e) => setLieu(e.target.value)}
              >
                <option value="">📍 Choisis ton stand / événement...</option>
                {lieux.map((l) => (
                  <option key={l.id} value={l.id}>📍 {l.nom}</option>
                ))}
              </select>
            </div>
          )}

          <div className={`mode-toggle mode-toggle-${modeCommande === "SUR_PLACE" ? "left" : "right"}`}>
            <div className="mode-toggle-indicator" aria-hidden="true" />
            <button
              className={modeCommande === "SUR_PLACE" ? "active" : ""}
              onClick={() => setModeCommande("SUR_PLACE")}
            >
              🏠 Retrait sur place
            </button>
            <button
              className={modeCommande === "LIVRAISON" ? "active" : ""}
              onClick={() => setModeCommande("LIVRAISON")}
            >
              🛵 Livraison à domicile
            </button>
          </div>

          <div className="menu-banner-controls">
            <input
              className="search-input"
              placeholder="🔍 Rechercher un plat..."
              value={recherche}
              onChange={(e) => setRecherche(e.target.value)}
            />
            {modeCommande === "SUR_PLACE" ? (
              <input
                className="table-input"
                placeholder="N° table / stand"
                value={numeroTable}
                onChange={(e) => setNumeroTable(e.target.value)}
              />
            ) : null}
          </div>

          {modeCommande === "SUR_PLACE" && (
            numeroTable.trim() ? (
              <div className="table-info table-info-ok">
                ✅ Ta commande sera livrée directement à <strong>{numeroTable}</strong>
              </div>
            ) : (
              <div className="table-info table-info-warn">
                ⚠️ Précise ton <strong>numéro de table / stand</strong> ci-dessus pour qu'on te livre
                directement ! Sinon, tu devras venir récupérer ta commande toi-même.
              </div>
            )
          )}

          {modeCommande === "LIVRAISON" && (
            <div className="livraison-fields">
              <input
                className="table-input"
                placeholder="Adresse de livraison *"
                value={adresseLivraison}
                onChange={(e) => setAdresseLivraison(e.target.value)}
              />
              <input
                className="table-input"
                placeholder="Numéro de téléphone *"
                value={telephoneClient}
                onChange={(e) => setTelephoneClient(e.target.value)}
              />
            </div>
          )}
        </div>

        <svg className="menu-banner-vague" viewBox="0 0 1440 60" preserveAspectRatio="none" aria-hidden="true">
          <path d="M0,32 C 240,64 480,0 720,20 S 1200,64 1440,28 L1440,60 L0,60 Z" fill="var(--cream)" />
        </svg>
      </div>

      {/* Formules du jour : grande vitrine, plus un carrousel discret */}
      {formules.length > 0 && !recherche.trim() && (
        <div className="formule-section">
          <div className="formule-section-head">
            <span className="formule-section-eyebrow">✨ À NE PAS MANQUER</span>
            <h2 className="font-display">Les formules du jour</h2>
          </div>

          <div className={`formule-vitrine-wrap${formules.length > 1 ? " formule-vitrine-wrap-scroll" : ""}`}>
            {formules.map((plat) => {
              const quantite = quantitePourPlat(plat.id);
              return (
                <div className="formule-vitrine" key={plat.id}>
                  <div className="formule-vitrine-glow" aria-hidden="true" />
                  <div className="formule-vitrine-ruban" aria-hidden="true">FORMULE</div>

                  <div className="formule-vitrine-media">
                    {plat.image ? (
                      <img src={plat.image} alt={plat.nom} loading="lazy" />
                    ) : (
                      <span aria-hidden="true">🍱</span>
                    )}
                    {quantite > 0 && <span className="plat-thumb-badge">{quantite}</span>}
                  </div>

                  <div className="formule-vitrine-info">
                    <h3 className="font-display">{plat.nom}</h3>
                    {plat.description && <p className="formule-vitrine-desc">{plat.description}</p>}
                    <div className="formule-vitrine-price font-mono">
                      {Number(plat.prix).toLocaleString("fr-FR")} F
                    </div>

                    <div className="groupes-choix groupes-choix-highlight">
                      {plat.groupes_choix.map((groupe) => (
                        <div className="groupe-choix" key={groupe.id}>
                          <label>
                            {groupe.nom}{groupe.obligatoire && <span className="req">*</span>}
                          </label>
                          <select
                            value={choixGroupes[plat.id]?.[groupe.id] || ""}
                            onChange={(e) => {
                              setChoixGroupes((prev) => ({
                                ...prev,
                                [plat.id]: { ...prev[plat.id], [groupe.id]: e.target.value },
                              }));
                              setErreurChoix((prev) => ({ ...prev, [plat.id]: null }));
                            }}
                          >
                            <option value="">Choisir...</option>
                            {groupe.options.map((o) => (
                              <option key={o.id} value={o.id}>{o.nom}</option>
                            ))}
                          </select>
                        </div>
                      ))}
                    </div>

                    {erreurChoix[plat.id] && (
                      <div className="accompagnement-erreur">{erreurChoix[plat.id]}</div>
                    )}

                    <button className="add-btn formule-vitrine-btn" onClick={() => ajouterAuPanier(plat)}>
                      + Ajouter la formule
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Navigation des rubriques, sticky en haut du scroll */}
      <nav className="rubrique-nav">
        <div className="rubrique-nav-inner">
          {categoriesSansFormules.map((cat) => (
            <button
              key={cat.id}
              className={cat.id === categorieActive ? "active" : ""}
              onClick={() => allerVersCategorie(cat.id)}
            >
              <span>{iconePourCategorie(cat.nom)}</span>
              {cat.nom}
              <span className="rubrique-nav-count">{cat.plats.length}</span>
            </button>
          ))}
        </div>
      </nav>

      {erreur && <div className="erreur">{erreur}</div>}

      <div className="menu-content">
        {categoriesFiltrees.length === 0 && (
          <div className="menu-etat">Aucun plat ne correspond à "{recherche}".</div>
        )}

        {categoriesFiltrees.map((cat, index) => {
          const teinte = TEINTES_STAND[index % TEINTES_STAND.length];
          return (
            <section
              className={`stand stand-${teinte}`}
              key={cat.id}
              ref={(el) => (sectionsRef.current[cat.id] = el)}
            >
              <div className="stand-enseigne">
                <span className="stand-enseigne-icon">{iconePourCategorie(cat.nom)}</span>
                <div className="stand-enseigne-texte">
                  <span className="stand-enseigne-label">Le stand</span>
                  <h3>{cat.nom}</h3>
                </div>
                <span className="stand-enseigne-count">
                  {cat.plats.length} plat{cat.plats.length > 1 ? "s" : ""}
                </span>
              </div>

              <div className="menu-grid">
                {cat.plats.map((plat) => {
                  const quantite = quantitePourPlat(plat.id);
                  const aAccompagnementSimple = plat.accompagnements?.length > 0;
                  const aChoix = aAccompagnementSimple; // besoin d'un bouton "+Ajouter" explicite (re-sélection à chaque ajout)

                  return (
                    <div className={`plat-card${quantite > 0 ? " in-cart" : ""}`} key={plat.id}>
                      <div className="plat-thumb">
                        {plat.image ? (
                          <img src={plat.image} alt={plat.nom} loading="lazy" />
                        ) : (
                          <span className="plat-thumb-fallback" aria-hidden="true">
                            {iconePourCategorie(cat.nom)}
                          </span>
                        )}
                        <div className="plat-thumb-overlay">
                          <div className="plat-thumb-overlay-title">{plat.nom}</div>
                          {plat.description && (
                            <div className="plat-thumb-overlay-desc">{plat.description}</div>
                          )}
                          {plat.temps_preparation_min && (
                            <div className="plat-thumb-overlay-meta">
                              ⏱ {plat.temps_preparation_min} min de préparation
                            </div>
                          )}
                        </div>
                        {quantite > 0 && <span className="plat-thumb-badge">{quantite}</span>}

                        {/* Ajout rapide en un tap pour les plats simples, sans ouvrir le panier */}
                        {!aChoix && quantite === 0 && (
                          <button
                            className="plat-thumb-fab"
                            onClick={() => ajouterAuPanier(plat)}
                            aria-label={`Ajouter ${plat.nom}`}
                          >
                            +
                          </button>
                        )}
                      </div>

                      <div className="plat-top">
                        <div className="plat-name">{plat.nom}</div>
                        {plat.description && <div className="plat-desc">{plat.description}</div>}
                      </div>

                      {/* Accompagnement simple (un seul choix, ex : brochette + accompagnement facultatif) */}
                      {aAccompagnementSimple && (
                        <div className="accompagnement-select">
                          <select
                            value={choixAccompagnement[plat.id] || ""}
                            onChange={(e) => {
                              setChoixAccompagnement((prev) => ({ ...prev, [plat.id]: e.target.value }));
                              setErreurChoix((prev) => ({ ...prev, [plat.id]: null }));
                            }}
                          >
                            <option value="">
                              {plat.accompagnement_obligatoire ? "Choisir un accompagnement..." : "Sans accompagnement"}
                            </option>
                            {plat.accompagnements.map((a) => (
                              <option key={a.id} value={a.id}>{a.nom}</option>
                            ))}
                          </select>
                          {erreurChoix[plat.id] && (
                            <div className="accompagnement-erreur">{erreurChoix[plat.id]}</div>
                          )}
                        </div>
                      )}

                      <div className="plat-row">
                        <span className="plat-price font-mono">
                          {Number(plat.prix).toLocaleString("fr-FR")} F
                        </span>

                        {aChoix ? (
                          <button className="add-btn" onClick={() => ajouterAuPanier(plat)}>
                            + Ajouter
                          </button>
                        ) : quantite > 0 ? (
                          <div className="qty-stepper">
                            <button onClick={() => modifierQuantite(plat, -1)} aria-label={`Retirer ${plat.nom}`}>−</button>
                            <span>{quantite}</span>
                            <button onClick={() => modifierQuantite(plat, 1)} aria-label={`Ajouter ${plat.nom}`}>+</button>
                          </div>
                        ) : (
                          <button className="add-btn" onClick={() => ajouterAuPanier(plat)}>
                            + Ajouter
                          </button>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            </section>
          );
        })}
      </div>

      {/* Barre panier flottante (raccourci mobile, en plus de l'icône du haut) */}
      {totalArticles > 0 && (
        <button className="cart-bar" onClick={() => setPanierOuvert(true)}>
          <span className="cart-bar-ruban" aria-hidden="true" />
          <span className="cart-bar-left">
            🛍️ {totalArticles} article{totalArticles > 1 ? "s" : ""}
          </span>
          <span className="cart-bar-total font-mono">Voir le panier →</span>
        </button>
      )}
    </div>
  );
}
