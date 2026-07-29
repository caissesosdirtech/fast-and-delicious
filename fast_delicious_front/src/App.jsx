import { Routes, Route } from "react-router-dom";
import TopBar from "./components/TopBar";
import RouteProtegee from "./components/RouteProtegee";
import ClientMenu from "./pages/ClientMenu";
import ClientSuivi from "./pages/ClientSuivi";
import LoginStaff from "./pages/LoginStaff";
import CaissiereDashboard from "./pages/CaissiereDashboard";
import CuisineDashboard from "./pages/CuisineDashboard";
import LivraisonDashboard from "./pages/LivraisonDashboard";
import AdminDashboard from "./pages/AdminDashboard";
import MenuVitrine from "./pages/MenuVitrine";
import QRCodes from "./pages/QRCodes";
import Footer from "./components/Footer";
import CartDrawer from "./components/CartDrawer";

export default function App() {
  return (
    <>
      <TopBar />
      <main style={{ flex: 1 }}>
        <Routes>
          <Route path="/" element={<ClientMenu />} />
          <Route path="/menu" element={<MenuVitrine />} />
          <Route path="/suivi/:id" element={<ClientSuivi />} />
          <Route path="/staff/login" element={<LoginStaff />} />
          <Route
            path="/caisse"
            element={
              <RouteProtegee rolesAutorises={["caissiere", "admin"]}>
                <CaissiereDashboard />
              </RouteProtegee>
            }
          />
          <Route
            path="/cuisine"
            element={
              <RouteProtegee rolesAutorises={["cuisine", "admin"]}>
                <CuisineDashboard />
              </RouteProtegee>
            }
          />
          <Route
            path="/livraison"
            element={
              <RouteProtegee rolesAutorises={["livreur", "admin"]}>
                <LivraisonDashboard />
              </RouteProtegee>
            }
          />
          <Route
            path="/admin"
            element={
              <RouteProtegee rolesAutorises={["admin"]}>
                <AdminDashboard />
              </RouteProtegee>
            }
          />
          <Route
            path="/staff/qr-codes"
            element={
              <RouteProtegee rolesAutorises={["caissiere", "admin"]}>
                <QRCodes />
              </RouteProtegee>
            }
          />
        </Routes>
      </main>
      <Footer />
      <CartDrawer />
    </>
  );
}
