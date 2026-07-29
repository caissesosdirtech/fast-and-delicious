import "./KpiCard.css";

export default function KpiCard({ label, valeur, couleur }) {
  return (
    <div className="kpi-card">
      <div className="kpi-valeur" style={couleur ? { color: couleur } : undefined}>{valeur}</div>
      <div className="kpi-label">{label}</div>
    </div>
  );
}
