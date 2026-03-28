import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { apiClient } from '../../config/api';
import { useAuthStore } from '../../store/authStore';
import { PlacardStatus } from '@soteria/shared';

export function DashboardPage() {
  const navigate = useNavigate();
  const user = useAuthStore(s => s.user);

  const { data: pendingData } = useQuery({
    queryKey: ['pending-approvals'],
    queryFn: () => apiClient.get('/placards', { params: { status: PlacardStatus.PENDING_APPROVAL, limit: 5 } }).then(r => r.data),
  });

  const pending = pendingData?.pagination?.total ?? 0;

  return (
    <div>
      <h1 style={{ margin: '0 0 6px', fontSize: 24, fontWeight: 700 }}>
        Welcome, {user?.firstName ?? 'Admin'}
      </h1>
      <p style={{ margin: '0 0 28px', color: '#888', fontSize: 14 }}>Soteria LOTO — Admin Portal</p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: 16, marginBottom: 28 }}>
        <StatCard label="Pending Approvals" value={String(pending)} accent="#CC0000" onClick={() => navigate('/approvals')} />
        <StatCard label="All Placards" value="View All" accent="#1A1A1A" onClick={() => navigate('/placards')} />
        <StatCard label="Equipment" value="Browse" accent="#333" onClick={() => navigate('/equipment')} />
        <StatCard label="Audit Trail" value="View" accent="#555" onClick={() => navigate('/audit')} />
      </div>

      {pending > 0 && (
        <div style={{ backgroundColor: '#FFF3CD', border: '2px solid #FF9800', borderRadius: 8, padding: '14px 18px', marginBottom: 20 }}>
          <strong style={{ color: '#CC6600' }}>⚠ {pending} placard{pending !== 1 ? 's' : ''} awaiting approval</strong>
          <span style={{ marginLeft: 10, fontSize: 13 }}>
            <a href="/approvals" style={{ color: '#CC6600' }}>Go to Approval Queue →</a>
          </span>
        </div>
      )}
    </div>
  );
}

function StatCard({ label, value, accent, onClick }: { label: string; value: string; accent: string; onClick: () => void }) {
  return (
    <div onClick={onClick} style={{ backgroundColor: '#FFF', border: '1px solid #E0E0E0', borderRadius: 8, padding: 20, cursor: 'pointer', borderLeft: `4px solid ${accent}` }}>
      <div style={{ fontSize: 22, fontWeight: 700, color: accent }}>{value}</div>
      <div style={{ fontSize: 12, color: '#666', marginTop: 4, fontWeight: 600, textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
    </div>
  );
}
