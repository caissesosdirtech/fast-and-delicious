import "./Stepper.css";

const ETAPES_SUR_PLACE = [
  { cle: "EN_ATTENTE", label: "Reçue" },
  { cle: "VALIDEE", label: "Validée" },
  { cle: "EN_PREPARATION", label: "En cuisine" },
  { cle: "PRETE", label: "Prête" },
];

const ETAPES_LIVRAISON = [
  { cle: "EN_ATTENTE", label: "Reçue" },
  { cle: "VALIDEE", label: "Validée" },
  { cle: "EN_PREPARATION", label: "En cuisine" },
  { cle: "PRETE", label: "Prête" },
  { cle: "EN_LIVRAISON", label: "En livraison" },
];

export default function Stepper({ statutActuel, modeCommande = "SUR_PLACE" }) {
  const etapes = modeCommande === "LIVRAISON" ? ETAPES_LIVRAISON : ETAPES_SUR_PLACE;
  const indexActuel = etapes.findIndex((e) => e.cle === statutActuel);
  // Une fois "Servie", toutes les étapes sont marquées comme terminées.
  const toutesFaites = statutActuel === "SERVIE";

  return (
    <div className="stepper">
      {etapes.map((etape, i) => {
        let classe = "step";
        if (toutesFaites || i < indexActuel) classe += " done";
        else if (i === indexActuel) classe += " current";
        return (
          <div className={classe} key={etape.cle}>
            <div className="dot" />
            <label>{etape.label}</label>
          </div>
        );
      })}
    </div>
  );
}
