import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import client from "../api/client";
import { useRevelation } from "../hooks/useRevelation";
import "./MenuVitrine.css";

const ICONES_CATEGORIE = {
  "fast food": "🌯", "snack": "🌯",
  "crêpe": "🥞", "crepe": "🥞",
  "grillade": "🔥",
  "boisson": "🥤",
};

function iconePourCategorie(nom) {
  const cle = Object.keys(ICONES_CATEGORIE).find((k) => nom.toLowerCase().includes(k));
  return ICONES_CATEGORIE[cle] || "🍽️";
}

function CategorieVitrine({ cat, index, sectionRef }) {
  const [ref, visible] = useRevelation();

  return (
    <section
      id={`vitrine-cat-${cat.id}`}
      ref={(el) => { ref.current = el; sectionRef(cat.id, el); }}
      className={`vitrine-section${visible ? " visible" : ""}`}
      style={{ transitionDelay: `${Math.min(index, 4) * 0.08}s` }}
    >
      <div className="vitrine-section-head">
        <span className="vitrine-section-icon">{iconePourCategorie(cat.nom)}</span>
        <h2 className="font-display">{cat.nom}</h2>
        <span className="vitrine-section-count">{cat.plats.length} plat{cat.plats.length > 1 ? "s" : ""}</span>
      </div>

      <div className="vitrine-grid">
        {cat.plats.map((plat, i) => (
          <PlatVitrine key={plat.id} plat={plat} catIcon={iconePourCategorie(cat.nom)} delai={i * 0.06} />
        ))}
      </div>
    </section>
  );
}

function PlatVitrine({ plat, catIcon, delai }) {
  const [ref, visible] = useRevelation();
  const estFormule = plat.groupes_choix?.length > 0;
  const aAccompagnement = !estFormule && plat.accompagnements?.length > 0;

  return (
    <div
      ref={ref}
      className={`vitrine-card${visible ? " visible" : ""}${estFormule ? " vitrine-card-formule" : ""}`}
      style={{ transitionDelay: `${delai}s` }}
    >
      <div className="vitrine-card-img">
        {plat.image ? (
          <img src={plat.image} alt={plat.nom} loading="lazy" />
        ) : (
          <span aria-hidden="true">{catIcon}</span>
        )}
        {estFormule && <span className="vitrine-badge-formule">✨ Repas complet</span>}
      </div>
      <div className="vitrine-card-body">
        <div className="vitrine-card-name">{plat.nom}</div>
        {plat.description && <div className="vitrine-card-desc">{plat.description}</div>}

        {estFormule && (
          <div className="vitrine-groupes">
            {plat.groupes_choix.map((g) => (
              <div className="vitrine-groupe" key={g.id}>
                <span className="vitrine-groupe-nom">{g.nom} :</span>{" "}
                {g.options.map((o) => o.nom).join(", ")}
              </div>
            ))}
          </div>
        )}

        {aAccompagnement && (
          <div className="vitrine-accompagnement-chip">
            🥗 Accompagnement au choix : {plat.accompagnements.map((a) => a.nom).join(", ")}
          </div>
        )}

        <div className="vitrine-card-price font-mono">{Number(plat.prix).toLocaleString("fr-FR")} F</div>
      </div>
    </div>
  );
}

export default function MenuVitrine() {
  const [categories, setCategories] = useState([]);
  const [chargement, setChargement] = useState(true);
  const [erreur, setErreur] = useState(null);
  const sectionsRef = useRef({});

  useEffect(() => {
    client
      .get("menu/categories/")
      .then((res) => setCategories(res.data))
      .catch(() => setErreur("Impossible de charger le menu."))
      .finally(() => setChargement(false));
  }, []);

  function enregistrerSection(catId, el) {
    if (el) sectionsRef.current[catId] = el;
  }

  function allerVersCategorie(catId) {
    sectionsRef.current[catId]?.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  if (chargement) return <div className="vitrine-etat">Chargement du menu...</div>;
  if (erreur) return <div className="vitrine-etat">{erreur}</div>;

  const totalPlats = categories.reduce((acc, c) => acc + c.plats.length, 0);

  return (
    <div className="menu-vitrine">
      <div className="vitrine-hero">
        <div className="eyebrow-badge">
          <span className="eyebrow-flag" aria-hidden="true">🍔</span>
          <span className="eyebrow-text">Fast &amp; Delicious</span>
          <span className="eyebrow-flag eyebrow-flag-right" aria-hidden="true">🔥</span>
        </div>
        <h1 className="font-display">Notre menu complet</h1>
        <p>{totalPlats} plats répartis en {categories.length} rubriques — tout ce que propose Fast &amp; Delicious.</p>
        <a href="tel:+221761270766" className="appel-commande">
          📞 Commander par téléphone : <span className="font-mono">+221 76 127 07 66</span>
        </a>
      </div>

      {/* Navigation rapide entre toutes les rubriques */}
      <nav className="vitrine-nav">
        {categories.map((cat) => (
          <button key={cat.id} onClick={() => allerVersCategorie(cat.id)}>
            <span>{iconePourCategorie(cat.nom)}</span> {cat.nom}
          </button>
        ))}
      </nav>

      {categories.map((cat, i) => (
        <CategorieVitrine key={cat.id} cat={cat} index={i} sectionRef={enregistrerSection} />
      ))}

      <Link to="/" className="vitrine-cta">
        🛍️ Commander maintenant →
      </Link>
    </div>
  );
}
