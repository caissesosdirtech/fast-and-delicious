// Associe automatiquement une photo locale (livrée dans public/plats/) à un plat,
// en se basant sur son NOM. Avantage : les photos sont intégrées au front, donc elles
// survivent à chaque redéploiement Railway (contrairement à un upload via l'admin, effacé
// à chaque déploiement). Aucune image à téléverser : il suffit que le plat porte un nom
// reconnu ci-dessous.
//
// Priorité d'affichage dans le menu : plat.image (si un jour tu en uploades une) > photo
// locale (ci-dessous) > icône de secours. Les catégories et les plats en base ne sont pas
// modifiés : on ne fait qu'ajouter l'affichage d'une image.

// Normalise un texte : minuscules, sans accents, espaces simples.
function normaliser(texte) {
  return (texte || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "") // retire les accents
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

// Règles testées dans l'ordre : la première qui correspond gagne.
// `motifs` : au moins un groupe de mots doit être entièrement présent dans le nom normalisé.
const REGLES = [
  { fichier: "wrap-poulet.png",          motifs: [["wrap"]] },
  { fichier: "crepe-jambon-fromage.png", motifs: [["crepe", "jambon"], ["crepe", "fromage"]] },
  { fichier: "crepe-nutella.png",        motifs: [["crepe", "nutella"], ["crepe", "mordjene"], ["crepe", "sucre"], ["crepe", "chocolat"]] },
  { fichier: "chicken-tenders.png",      motifs: [["tender"], ["nugget"], ["chicken"]] },
  { fichier: "hot-dog.png",              motifs: [["hot", "dog"], ["hotdog"]] },
  { fichier: "green-teranga-fataya.png", motifs: [["fataya"], ["teranga"]] },
  { fichier: "pain-haricots.png",        motifs: [["pain", "haricot"], ["haricot"]] },
  { fichier: "pain-thon.png",            motifs: [["pain", "thon"], ["thon"]] },
  { fichier: "donuts-bissap.png",        motifs: [["donut"]] },

  // --- Jus naturels (un par parfum). À placer AVANT la règle générique "jus" et avant "thé bissap". ---
  { fichier: "jus-bissap.png",           motifs: [["jus", "bissap"]] },
  { fichier: "jus-bouye.png",            motifs: [["jus", "bouye"], ["jus", "pain de singe"], ["jus", "baobab"]] },
  { fichier: "jus-maad.png",             motifs: [["jus", "maad"], ["jus", "madd"]] },
  { fichier: "jus-ditakh.png",           motifs: [["jus", "ditakh"], ["jus", "ditax"]] },
  { fichier: "jus-gingembre.png",        motifs: [["jus", "gingembre"]] },
  { fichier: "jus-citron.png",           motifs: [["jus", "citron"]] },

  { fichier: "cafe-touba.png",           motifs: [["touba"], ["cafe"]] },
  { fichier: "the-menthe.png",           motifs: [["menthe"]] },
  { fichier: "the-bissap.png",           motifs: [["the", "bissap"]] },
  { fichier: "jus-locaux.png",           motifs: [["jus"]] }, // "Jus locaux en canette" (assortiment)
  { fichier: "fanta-coca-sprite.png",    motifs: [["fanta"], ["coca"], ["sprite"], ["soda"]] },
];

export function photoLocalePlat(nom) {
  const n = normaliser(nom);
  if (!n) return null;
  for (const regle of REGLES) {
    const correspond = regle.motifs.some((mots) => mots.every((m) => n.includes(m)));
    if (correspond) return `/plats/${regle.fichier}`;
  }
  return null;
}
