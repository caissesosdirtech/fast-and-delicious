import AnimatedNumber from "./AnimatedNumber";
import "./KpiCard.css";

export default function KpiCard({ label, valeur, couleur }) {
  // Si la valeur est un nombre, on l'anime (effet compteur) ; sinon on l'affiche telle quelle.
  const contenu = typeof valeur === "number" ? <AnimatedNumber value={valeur} /> : valeur;
  return (
    <div className="kpi-card">
      <div className="kpi-valeur" style={couleur ? { color: couleur } : undefined}>{contenu}</div>
      <div className="kpi-label">{label}</div>
    </div>
  );
}
