import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../../config/api';
export function SiteListPage() {
  const { data } = useQuery({ queryKey: ['sites'], queryFn: () => apiClient.get('/sites').then(r => r.data) });
  const sites = data?.data ?? [];
  return (
    <div>
      <h2 style={{ margin: '0 0 20px' }}>Sites</h2>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {sites.map((s: Record<string, unknown>) => (
          <div key={s._id as string} style={{ backgroundColor: '#FFF', border: '1px solid #E0E0E0', borderRadius: 8, padding: '14px 18px' }}>
            <strong>{s.name as string}</strong> <span style={{ marginLeft: 8, fontFamily: 'monospace', backgroundColor: '#F5F5F5', padding: '2px 6px', borderRadius: 3, fontSize: 11 }}>{s.code as string}</span>
          </div>
        ))}
        {sites.length === 0 && <p style={{ color: '#888' }}>No sites configured yet.</p>}
      </div>
    </div>
  );
}
