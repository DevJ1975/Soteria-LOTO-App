import React from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../../config/api';
import { PlacardStatus } from '@soteria/shared';
import { format } from 'date-fns';
export function PlacardDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { data, isLoading } = useQuery({ queryKey: ['placard', id], queryFn: () => apiClient.get('/placards/' + id).then(r => r.data.data), enabled: !!id });
  if (isLoading) return <div style={{ padding: 32 }}>Loading...</div>;
  if (!data) return <div style={{ padding: 32 }}>Not found</div>;
  const p = data;
  return (
    <div style={{ maxWidth: 860 }}>
      <button style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#888', marginBottom: 8 }} onClick={() => navigate('/placards')}>← Back</button>
      <h1 style={{ margin: '0 0 4px', fontFamily: 'monospace' }}>{p.placardNumber}</h1>
      <p style={{ color: '#666', margin: '0 0 20px' }}>{p.machineInfo?.commonName} — Rev.{p.revisionNumber} — {p.status}</p>
      {p.status === PlacardStatus.APPROVED && (
        <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
          <a href={'http://localhost:4000/api/v1/print/' + id + '?format=placard_en'} target="_blank" rel="noreferrer" style={{ backgroundColor: '#1A1A1A', color: '#FFF', padding: '8px 14px', borderRadius: 5, textDecoration: 'none', fontSize: 12 }}>Print English PDF</a>
          <a href={'http://localhost:4000/api/v1/print/' + id + '?format=placard_es'} target="_blank" rel="noreferrer" style={{ backgroundColor: '#1565C0', color: '#FFF', padding: '8px 14px', borderRadius: 5, textDecoration: 'none', fontSize: 12 }}>Print Spanish PDF</a>
          <a href={'http://localhost:4000/api/v1/print/' + id + '?format=qr_posting_sign'} target="_blank" rel="noreferrer" style={{ backgroundColor: '#555', color: '#FFF', padding: '8px 14px', borderRadius: 5, textDecoration: 'none', fontSize: 12 }}>QR Posting Sign</a>
        </div>
      )}
      <div style={{ backgroundColor: '#FFF', borderRadius: 8, border: '1px solid #E0E0E0', padding: 20 }}>
        <h3 style={{ margin: '0 0 12px', fontSize: 12, color: '#888', textTransform: 'uppercase', letterSpacing: 0.5 }}>Procedure Steps ({p.procedureSteps?.length ?? 0})</h3>
        {(p.procedureSteps ?? []).map((s: Record<string, unknown>, i: number) => (
          <div key={i} style={{ display: 'flex', gap: 10, padding: '8px 0', borderBottom: '1px solid #F5F5F5' }}>
            <div style={{ width: 24, height: 24, borderRadius: 12, backgroundColor: '#CC0000', color: '#FFF', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 10, fontWeight: 700, flexShrink: 0, marginTop: 2 }}>{s.sequence as number}</div>
            <div><div style={{ fontSize: 9, fontWeight: 700, color: '#888', textTransform: 'uppercase' }}>{(s.phase as string)?.replace('_', ' ')}</div><div style={{ fontSize: 13, marginTop: 2 }}>{s.instruction as string}</div>{s.instructionEs && <div style={{ fontSize: 11, color: '#888', marginTop: 2 }}>{s.instructionEs as string}</div>}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
