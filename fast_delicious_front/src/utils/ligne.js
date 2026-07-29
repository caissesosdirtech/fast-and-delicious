/**
 * Construit le suffixe descriptif d'une ligne de commande à afficher côté staff
 * (accompagnement simple et/ou sélections de formule composée).
 * Ex : " (+ Alloco)" ou " (Grillade au choix : Poulet Fumé, Accompagnement : Alloco, Crudité : Crudités)"
 */
export function detailsLigne(ligne) {
  const morceaux = [];
  if (ligne.accompagnement_nom) {
    morceaux.push(`+ ${ligne.accompagnement_nom}`);
  }
  if (ligne.selections?.length > 0) {
    morceaux.push(ligne.selections.map((s) => `${s.groupe_nom} : ${s.option_nom}`).join(", "));
  }
  return morceaux.length > 0 ? ` (${morceaux.join(" — ")})` : "";
}
