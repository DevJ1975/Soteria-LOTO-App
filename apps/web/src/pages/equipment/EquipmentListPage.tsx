import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../../config/api';
export function EquipmentListPage() {
  const { data, isLoading } = useQuery({ queryKey: ['equipment'], queryFn: () => apiClient.get('/equipment', { params: { limit: 50 } }).then(r => r.data) });
  const items = data?.data ?? [];
  return (
    <div>
      <h2 style={{ margin: '0 0 20px' }}>Equipment</h2>
      <div style={{ backgroundColor: '#FFF', borderRadius: 8, border: '1px solid #E0E0E0', overflow: 'hidden' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead><tr style={{ backgroundColor: '#F5F5F5' }}>
            {['Equipment ID', 'Name', 'Location', 'Category', 'Status'].map(h => <th key={h} style={{ padding: '10px 14px', textAlign: 'left', fontSize: 11, fontWeight: 700, color: '#666', textTransform: 'uppercase' }}>{h}</th>)}
          </tr></thead>
          <tbody>
            {isLoading && <tr><td colSpan={5} style={{ padding: 20, textAlign: 'center', color: '#888' }}>Loading...</td></tr>}
            {items.map((e: Record<string, unknown>) => (
              <tr key={e._id as string} style={{ borderBottom: '1px solid #F0F0F0' }}>
                <td style={{ padding: '10px 14px', fontFamily: 'monospace', fontSize: 12 }}>{e.equipmentId as string}</td>
                <td style={{ padding: '10px 14px', fontSize: 13, fontWeight: 500 }}>{e.commonName as string}</td>
                <td style={{ padding: '10px 14px', fontSize: 12, color: '#666' }}>{e.location as string}</td>
                <td style={{ padding: '10px 14px', fontSize: 12 }}>{e.category as string}</td>
                <td style={{ padding: '10px 14px', fontSize: 11 }}>{e.status as string}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
