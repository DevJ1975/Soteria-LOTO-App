import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../../config/api';
import { format } from 'date-fns';
export function AuditPage() {
  const { data } = useQuery({ queryKey: ['audit'], queryFn: () => apiClient.get('/audit', { params: { limit: 100 } }).then(r => r.data) });
  const events = data?.data ?? [];
  return (
    <div>
      <h2 style={{ margin: '0 0 20px' }}>Audit Trail</h2>
      <div style={{ backgroundColor: '#FFF', borderRadius: 8, border: '1px solid #E0E0E0', overflow: 'hidden' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead><tr style={{ backgroundColor: '#F5F5F5' }}>
            {['Time', 'Event Type', 'Description', 'User'].map(h => <th key={h} style={{ padding: '10px 14px', textAlign: 'left', fontSize: 11, fontWeight: 700, color: '#666' }}>{h}</th>)}
          </tr></thead>
          <tbody>
            {events.map((e: Record<string, unknown>) => (
              <tr key={e._id as string} style={{ borderBottom: '1px solid #F0F0F0' }}>
                <td style={{ padding: '9px 14px', fontSize: 11, color: '#888', whiteSpace: 'nowrap' }}>{format(new Date(e.createdAt as string), 'MMM d HH:mm')}</td>
                <td style={{ padding: '9px 14px', fontSize: 11, fontFamily: 'monospace' }}>{e.eventType as string}</td>
                <td style={{ padding: '9px 14px', fontSize: 12 }}>{e.description as string}</td>
                <td style={{ padding: '9px 14px', fontSize: 11, color: '#666' }}>{(e.userId as Record<string, string>)?.email ?? '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
