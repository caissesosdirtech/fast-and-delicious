import { useEffect, useRef, useState } from "react";
import { WS_BASE_URL } from "../api/client";

/**
 * Suit une commande en direct : renvoie les dernières données reçues
 * (statut, temps restant) et l'état de la connexion WebSocket.
 */
export function useCommandeSocket(commandeId) {
  const [donnees, setDonnees] = useState(null);
  const [connecte, setConnecte] = useState(false);
  const socketRef = useRef(null);

  useEffect(() => {
    if (!commandeId) return;

    const socket = new WebSocket(`${WS_BASE_URL}/ws/commande/${commandeId}/`);
    socketRef.current = socket;

    socket.onopen = () => setConnecte(true);
    socket.onclose = () => setConnecte(false);
    socket.onerror = () => setConnecte(false);
    socket.onmessage = (event) => {
      setDonnees(JSON.parse(event.data));
    };

    return () => socket.close();
  }, [commandeId]);

  return { donnees, connecte };
}
