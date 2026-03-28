import React from 'react';
import { useParams } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../../config/api';
export function QRResolvePage() {
  const { token } = useParams();
  const { data, isLoading, error } = useQuery({ queryKey: ['qr', token], queryFn: () => apiClient.get('/qr/' + token).then(r => r.data), enabled: !!token });
  if (isLoading) return <div style={{ padding: 40, textAlign: 'center' }}>Loading placard...</div>;
  if (error) return <div style={{ padding: 40, textAlign: 'center', color: '#CC0000' }}>QR code not found or inactive.</div>;
  const placard = data?.data?.placard;
  if (!placard) return <div style={{ padding: 40 }}>No placard data</div>;
  return (
    <div style={{ maxWidth: 600, margin: '40px auto', padding: 24, backgroundColor: '#FFF', borderRadius: 8, border: '1px solid #E0E0E0' }}>
      <div style={{ backgroundColor: '#CC0000', padding: '14px 20px', borderRadius: 6, marginBottom: 20 }}>
        <h2 style={{ color: '#FFF', margin: 0, fontSize: 16 }}>LOCKOUT / TAGOUT PROCEDURE</h2>
        <p style={{ color: '#FFCCCC', margin: '4px 0 0', fontSize: 12 }}>{placard.placardNumber} — Rev.{placard.revisionNumber}</p>
      </div>
      <h3 style={{ margin: '0 0 4px' }}>{placard.machineInfo?.commonName}</h3>
      <p style={{ color: '#666', fontSize: 13 }}>{placard.machineInfo?.location}</p>
      <p style={{ color: '#4CAF50', fontWeight: 700 }}>Status: {placard.status?.toUpperCase()}</p>
      <p style={{ fontSize: 11, color: '#888' }}>Digital reference only. Obtain printed placard from your EHS team for LOTO operations.</p>
    </div>
  );
}
