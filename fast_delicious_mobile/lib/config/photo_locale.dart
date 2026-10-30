/// Associe une photo locale embarquée (assets/plats/) à un plat d'après son NOM.
/// Équivalent mobile de `photosPlats.js` côté web : les photos du catalogue sont dans
/// l'appli, donc elles s'affichent même si le serveur n'a pas d'image pour le plat,
/// et même avec un réseau faible (stade). Aucune dépendance au nom de fichier côté serveur.

String _normaliser(String? texte) {
  if (texte == null) return '';
  var s = texte.toLowerCase();
  const avec = 'àâäáãéèêëíìîïóòôöõúùûüçœ';
  const sans = 'aaaaaeeeeiiiiooooouuuucoe';
  final sb = StringBuffer();
  for (final ch in s.split('')) {
    final i = avec.indexOf(ch);
    sb.write(i >= 0 ? sans[i] : ch);
  }
  s = sb.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  return s;
}

class _Regle {
  final String fichier;
  final List<List<String>> motifs; // au moins un groupe dont tous les mots sont présents
  const _Regle(this.fichier, this.motifs);
}

const List<_Regle> _regles = [
  // Formules (affiches). En tête : noms du type "Formule 1 — Doukouré".
  _Regle('formule-doukoure.png', [['doukoure']]),
  _Regle('formule-diaytaar.png', [['diaytaar']]),
  _Regle('formule-beuri-maana.png', [['beuri'], ['maana']]),

  _Regle('wrap-poulet.png', [['wrap']]),
  _Regle('crepe-jambon-fromage.png', [['crepe', 'jambon'], ['crepe', 'fromage']]),
  _Regle('crepe-nutella.png', [['crepe', 'nutella'], ['crepe', 'mordjene'], ['crepe', 'sucre'], ['crepe', 'chocolat']]),
  _Regle('chicken-tenders.png', [['tender'], ['nugget'], ['chicken']]),
  _Regle('cheesy-fries.png', [['cheesy'], ['frites', 'fromage']]),
  _Regle('classic-french-fries.png', [['french', 'fries'], ['frites', 'nature'], ['classic', 'fries']]),
  _Regle('wings.png', [['wings'], ['wing'], ['ailes', 'poulet'], ['aile', 'poulet']]),
  _Regle('hot-dog.png', [['hot', 'dog'], ['hotdog']]),
  _Regle('green-teranga-fataya.png', [['fataya'], ['teranga']]),
  _Regle('pain-haricots.png', [['pain', 'haricot'], ['haricot']]),
  _Regle('pain-thon.png', [['pain', 'thon'], ['thon']]),
  _Regle('donuts-bissap.png', [['donut']]),

  // Jus (un par parfum). Avant la règle générique "jus" et avant "thé bissap".
  _Regle('jus-bissap.png', [['jus', 'bissap']]),
  _Regle('jus-bouye.png', [['jus', 'bouye'], ['jus', 'baobab']]),
  _Regle('jus-maad.png', [['jus', 'maad'], ['jus', 'madd']]),
  _Regle('jus-ditakh.png', [['jus', 'ditakh'], ['jus', 'ditax']]),
  _Regle('jus-gingembre.png', [['jus', 'gingembre']]),
  _Regle('jus-citron.png', [['jus', 'citron']]),

  _Regle('cafe-touba.png', [['touba'], ['cafe']]),
  _Regle('the-menthe.png', [['menthe']]),
  _Regle('the-bissap.png', [['the', 'bissap']]),
  _Regle('jus-locaux.png', [['jus']]),
  _Regle('fanta-coca-sprite.png', [['fanta'], ['coca'], ['sprite'], ['soda']]),
  _Regle('eau-minerale.png', [['eau'], ['minerale']]),
];

/// Renvoie le chemin de l'asset (ex: 'assets/plats/wrap-poulet.png') ou null.
String? photoLocalePlat(String? nom) {
  final n = _normaliser(nom);
  if (n.isEmpty) return null;
  for (final regle in _regles) {
    for (final mots in regle.motifs) {
      if (mots.every((m) => n.contains(m))) return 'assets/plats/${regle.fichier}';
    }
  }
  return null;
}
