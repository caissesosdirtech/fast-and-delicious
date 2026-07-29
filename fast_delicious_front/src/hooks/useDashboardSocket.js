import { useEffect, useRef, useState } from "react";
import { WS_BASE_URL } from "../api/client";

/**
 * Écoute le groupe "caisse" ou "cuisine" : à chaque événement reçu,
 * appelle `onEvenement`. Renvoie aussi l'état de la connexion.
 */
export function useDashboardSocket(groupe, onEvenement) {
  const [connecte, setConnecte] = useState(false);
  const callbackRef = useRef(onEvenement);
  callbackRef.current = onEvenement;

  useEffect(() => {
    const socket = new WebSocket(`${WS_BASE_URL}/ws/${groupe}/`);

    socket.onopen = () => setConnecte(true);
    socket.onclose = () => setConnecte(false);
    socket.onerror = () => setConnecte(false);
    socket.onmessage = (event) => {
      callbackRef.current?.(JSON.parse(event.data));
    };

    return () => socket.close();
  }, [groupe]);

  return { connecte };
}
