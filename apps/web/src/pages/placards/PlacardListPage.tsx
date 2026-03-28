import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { apiClient } from '../../config/api';
import { PlacardStatus } from '@soteria/shared';
import { format } from 'date-fns';

export function PlacardListPage() {
  const navigate = useNavigate();
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(1);

  const { data, isLoading } = useQuery({
    queryKey: ['placards', search, status, page],
    queryFn: () =>
      apiClient.get('/placards', { params: { q: search || undefined, status: status || undefined, page, limit: 25 } }).then((r) => r.data),
    staleTime: 30000,
  });

  const placards = data?.data ?? [];
  const pagination = data?.pagination;

  const statusColor: Record<string, string> = {
    [PlacardStatus.DRAFT]: '#9E9E9E',
    [PlacardStatus.PENDING_REVIEW]: '#FF9800',
    [PlacardStatus.IN_REVIEW]: '#2196F3',
    [PlacardStatus.PENDING_APPROVAL]: '#9C27B0',
    [PlacardStatus.APPROVED]: '#4CAF50',
    [PlacardStatus.REJECTED]: '#CC0000',
    [PlacardStatus.SUPERSEDED]: '#795548',
    [PlacardStatus.ARCHIVED]: '#607D8B',
  };

  return (
    <div>
      <div style={styles.header}>
        <h1 style={styles.title}>Placards</h1>
        <button style={styles.newBtn} onClick={() => navigate('/placards/new')}>
          + New Placard
        </button>
      </div>

      {/* Filters */}
      <div style={styles.filters}>
        <input
          style={styles.searchInput}
          value={search}
          onChange={(e) => { setSearch(e.target.value); setPage(1); }}
          placeholder="Search placards, machines, equipment ID..."
        />
        <select style={styles.select} value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }}>
          <option value="">All Statuses</option>
          {Object.values(PlacardStatus).map((s) => (
            <option key={s} value={s}>{s.replace(/_/g, ' ')}</option>
          ))}
        </select>
      </div>

      {/* Table */}
      <div style={styles.tableWrap}>
        <table style={styles.table}>
          <thead>
            <tr style={styles.thead}>
              <th style={styles.th}>Placard No.</th>
              <th style={styles.th}>Machine</th>
              <th style={styles.th}>Location</th>
              <th style={styles.th}>Rev.</th>
              <th style={styles.th}>Status</th>
              <th style={styles.th}>Updated</th>
              <th style={styles.th}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {isLoading && (
              <tr><td colSpan={7} style={{ textAlign: 'center', padding: 24, color: '#888' }}>Loading...</td></tr>
            )}
            {placards.map((p: Record<string, unknown>) => (
              <tr key={p._id as string} style={styles.tr} onClick={() => navigate(`/placards/${p._id}`)}>
                <td style={{ ...styles.td, fontFamily: 'monospace', fontWeight: 700 }}>{p.placardNumber as string}</td>
                <td style={styles.td}>{(p.machineInfo as Record<string, string>)?.commonName}</td>
                <td style={styles.td}>{(p.machineInfo as Record<string, string>)?.location}</td>
                <td style={{ ...styles.td, textAlign: 'center' }}>Rev.{p.revisionNumber as number}</td>
                <td style={styles.td}>
                  <span style={{ ...styles.badge, backgroundColor: statusColor[p.status as string] ?? '#888' }}>
                    {(p.status as string).replace(/_/g, ' ')}
                  </span>
                </td>
                <td style={{ ...styles.td, color: '#888', fontSize: 12 }}>
                  {format(new Date(p.updatedAt as string), 'MMM d, yyyy')}
                </td>
                <td style={styles.td} onClick={(e) => e.stopPropagation()}>
                  <button style={styles.actionBtn} onClick={() => navigate(`/placards/${p._id}`)}>View</button>
                  {(p.status === PlacardStatus.APPROVED) && (
                    <a href={`${import.meta.env.VITE_API_URL ?? 'http://localhost:4000/api/v1'}/print/${p._id}?format=placard_en`}
                      style={styles.printBtn} target="_blank" rel="noreferrer">
                      Print
                    </a>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {pagination && (
        <div style={styles.pagination}>
          <button disabled={page === 1} onClick={() => setPage(p => p - 1)} style={styles.pageBtn}>← Prev</button>
          <span style={{ fontSize: 13, color: '#666' }}>
            Page {pagination.page} of {pagination.totalPages} ({pagination.total} total)
          </span>
          <button disabled={page >= pagination.totalPages} onClick={() => setPage(p => p + 1)} style={styles.pageBtn}>Next →</button>
        </div>
      )}
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  header: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 },
  title: { margin: 0, fontSize: 22, fontWeight: 700 },
  newBtn: { backgroundColor: '#CC0000', color: '#FFF', border: 'none', borderRadius: 6, padding: '9px 18px', cursor: 'pointer', fontSize: 13, fontWeight: 600 },
  filters: { display: 'flex', gap: 12, marginBottom: 16 },
  searchInput: { flex: 1, border: '1.5px solid #CCC', borderRadius: 6, padding: '8px 12px', fontSize: 14 },
  select: { border: '1.5px solid #CCC', borderRadius: 6, padding: '8px 12px', fontSize: 13 },
  tableWrap: { backgroundColor: '#FFF', borderRadius: 8, border: '1px solid #E0E0E0', overflow: 'hidden' },
  table: { width: '100%', borderCollapse: 'collapse' },
  thead: { backgroundColor: '#F5F5F5' },
  th: { padding: '11px 14px', textAlign: 'left', fontSize: 11, fontWeight: 700, color: '#666', textTransform: 'uppercase', letterSpacing: 0.5, borderBottom: '1px solid #E0E0E0' },
  tr: { cursor: 'pointer', borderBottom: '1px solid #F0F0F0', transition: 'background 0.1s' },
  td: { padding: '11px 14px', fontSize: 13 },
  badge: { color: '#FFF', padding: '2px 8px', borderRadius: 10, fontSize: 10, fontWeight: 600, textTransform: 'uppercase' },
  actionBtn: { backgroundColor: '#FFF', border: '1px solid #CCC', borderRadius: 4, padding: '4px 10px', cursor: 'pointer', fontSize: 11, marginRight: 6 },
  printBtn: { backgroundColor: '#1A1A1A', color: '#FFF', borderRadius: 4, padding: '4px 10px', fontSize: 11, textDecoration: 'none' },
  pagination: { display: 'flex', alignItems: 'center', gap: 16, marginTop: 16, justifyContent: 'center' },
  pageBtn: { border: '1px solid #CCC', borderRadius: 4, padding: '6px 14px', cursor: 'pointer', fontSize: 12, backgroundColor: '#FFF' },
};
