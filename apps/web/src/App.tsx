import React, { useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { useAuthStore } from './store/authStore';

// Layouts
import { AdminLayout } from './components/layout/AdminLayout';

// Pages
import { LoginPage } from './pages/auth/LoginPage';
import { DashboardPage } from './pages/dashboard/DashboardPage';
import { PlacardListPage } from './pages/placards/PlacardListPage';
import { PlacardDetailPage } from './pages/placards/PlacardDetailPage';
import { PlacardEditorPage } from './pages/placards/PlacardEditorPage';
import { ApprovalQueuePage } from './pages/approvals/ApprovalQueuePage';
import { EquipmentListPage } from './pages/equipment/EquipmentListPage';
import { SiteListPage } from './pages/sites/SiteListPage';
import { AuditPage } from './pages/audit/AuditPage';
import { QRResolvePage } from './pages/qr/QRResolvePage';

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading } = useAuthStore();
  if (isLoading) return <div style={{ padding: 40, textAlign: 'center' }}>Loading...</div>;
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  return <>{children}</>;
}

export function App() {
  const loadSession = useAuthStore((s) => s.loadSession);

  useEffect(() => { loadSession(); }, []);

  return (
    <BrowserRouter>
      <Routes>
        {/* Public */}
        <Route path="/login" element={<LoginPage />} />
        <Route path="/q/:token" element={<QRResolvePage />} />

        {/* Protected admin portal */}
        <Route
          path="/"
          element={
            <ProtectedRoute>
              <AdminLayout />
            </ProtectedRoute>
          }
        >
          <Route index element={<DashboardPage />} />
          <Route path="placards" element={<PlacardListPage />} />
          <Route path="placards/:id" element={<PlacardDetailPage />} />
          <Route path="placards/:id/edit" element={<PlacardEditorPage />} />
          <Route path="placards/new" element={<PlacardEditorPage />} />
          <Route path="approvals" element={<ApprovalQueuePage />} />
          <Route path="equipment" element={<EquipmentListPage />} />
          <Route path="sites" element={<SiteListPage />} />
          <Route path="audit" element={<AuditPage />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
