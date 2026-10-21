import { useEffect, useRef, useState } from "react";

/**
 * Affiche un nombre qui "monte" de 0 à sa valeur au chargement (effet compteur).
 * - value   : la valeur cible (nombre)
 * - duration: durée de l'animation en ms
 * Le rendu est formaté à la française (séparateur de milliers).
 */
export default function AnimatedNumber({ value, duration = 900 }) {
  const cible = Number(value) || 0;
  const [affiche, setAffiche] = useState(0);
  const rafRef = useRef(0);

  useEffect(() => {
    const debut = performance.now();
    function tick(t) {
      const p = Math.min((t - debut) / duration, 1);
      const eased = 1 - Math.pow(1 - p, 3); // easing "ease-out"
      setAffiche(Math.round(cible * eased));
      if (p < 1) rafRef.current = requestAnimationFrame(tick);
    }
    rafRef.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafRef.current);
  }, [cible, duration]);

  return <>{affiche.toLocaleString("fr-FR")}</>;
}
