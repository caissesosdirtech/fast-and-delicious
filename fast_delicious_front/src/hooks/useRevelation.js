import { useEffect, useRef, useState } from "react";

/**
 * Ajoute une classe "visible" à un élément dès qu'il entre dans le viewport,
 * pour déclencher une animation d'apparition au défilement (fade + slide).
 */
export function useRevelation(options = {}) {
  const ref = useRef(null);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setVisible(true);
          observer.unobserve(el);
        }
      },
      { threshold: 0.15, ...options }
    );

    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  return [ref, visible];
}
