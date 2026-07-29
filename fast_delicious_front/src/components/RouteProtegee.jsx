import { Navigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

export default function RouteProtegee({ rolesAutorises, children }) {
  const { utilisateur, chargement } = useAuth();

  if (chargement) return <div style={{ padding: 40 }}>Chargement...</div>;
  if (!utilisateur) return <Navigate to="/staff/login" replace />;
  if (rolesAutorises && !rolesAutorises.includes(utilisateur.role)) {
    return <div style={{ padding: 40 }}>Accès réservé à un autre rôle ({rolesAutorises.join(", ")}).</div>;
  }
  return children;
}
