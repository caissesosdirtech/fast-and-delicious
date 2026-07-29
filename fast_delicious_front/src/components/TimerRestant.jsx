import { useEffect, useState } from "react";

/**
 * Affiche un compte à rebours qui décroît localement chaque seconde,
 * mais se resynchronise dès qu'une nouvelle valeur arrive du serveur (WebSocket).
 */
export default function TimerRestant({ minutesRestantes }) {
  const [secondes, setSecondes] = useState((minutesRestantes || 0) * 60);

  useEffect(() => {
    setSecondes((minutesRestantes || 0) * 60);
  }, [minutesRestantes]);

  useEffect(() => {
    const id = setInterval(() => {
      setSecondes((s) => (s > 0 ? s - 1 : 0));
    }, 1000);
    return () => clearInterval(id);
  }, []);

  const m = String(Math.floor(secondes / 60)).padStart(2, "0");
  const s = String(secondes % 60).padStart(2, "0");

  return (
    <div className="timer-box">
      <div className="big font-display">{m}:{s}</div>
      <div className="lbl">Temps restant estimé</div>
    </div>
  );
}
