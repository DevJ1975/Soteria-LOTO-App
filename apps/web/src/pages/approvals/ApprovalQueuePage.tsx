// ============================================================
// ApprovalQueuePage — Phase 7 Web Admin Portal
// Shows all placards pending review or approval
// Approver can approve/reject with comments
// ============================================================

import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../../config/api';
import { PlacardStatus } from '@soteria/shared';
import { format } from 'date-fns';

interface Placard {
  _id: string;
  placardNumber: string;
  revisionNumber: number;
  status: PlacardStatus;
  machineInfo: { commonName: string; location: string };
  authorId: { firstName: string; lastName: string };
  createdAt: string;
  wasAIAssisted: boolean;
}

export function ApprovalQueuePage() {
  const queryClient = useQueryClient();
  const [selected, setSelected] = useState<Placard | null>(null);
  const [comments, setComments] = useState('');
  const [action, setAction] = useState<'approve' | 'reject' | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ['approval-queue'],
    queryFn: () =>
      apiClient
        .get('/placards', {
          params: { status: `${PlacardStatus.PENDING_REVIEW},${PlacardStatus.IN_REVIEW},${PlacardStatus.PENDING_APPROVAL}` },
        })
        .then((r) => r.data),
  });

  const approveMutation = useMutation({
    mutationFn: ({ id, comments }: { id: string; comments: string }) =>
      apiClient.post(`/placards/${id}/approve`, { comments }),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['approval-queue'] }); setSelected(null); setComments(''); },
  });

  const rejectMutation = useMutation({
    mutationFn: ({ id, comments }: { id: string; comments: string }) =>
      apiClient.post(`/placards/${id}/reject`, { comments }),
    onSuccess: () => { queryClient.invalidateQueries({ queryKey: ['approval-queue'] }); setSelected(null); setComments(''); },
  });

  const handleAction = () => {
    if (!selected || !action) return;
    if (action === 'reject' && !comments.trim()) {
      alert('Rejection comments are required');
      return;
    }
    if (action === 'approve') {
      approveMutation.mutate({ id: selected._id, comments });
    } else {
      rejectMutation.mutate({ id: selected._id, comments });
    }
  };

  const placards: Placard[] = data?.data ?? [];

  return (
    <div>
      <div style={styles.pageHeader}>
        <h1 style={styles.pageTitle}>Approval Queue</h1>
        <span style={styles.countBadge}>{placards.length} pending</span>
      </div>

      {isLoading && <p style={{ color: '#888' }}>Loading...</p>}

      {placards.length === 0 && !isLoading && (
        <div style={styles.emptyState}>
          <div style={styles.emptyIcon}>✓</div>
          <p>No placards pending review or approval</p>
        </div>
      )}

      <div style={styles.queue}>
        {placards.map((placard) => (
          <div key={placard._id} style={styles.queueCard}>
            <div style={styles.queueCardLeft}>
              <div style={styles.placardNum}>{placard.placardNumber}</div>
              <div style={styles.machineName}>{placard.machineInfo.commonName}</div>
              <div style={styles.meta}>
                {placard.machineInfo.location} • Rev.{placard.revisionNumber} •{' '}
                By {placard.authorId?.firstName} {placard.authorId?.lastName} •{' '}
                {format(new Date(placard.createdAt), 'MMM d, yyyy')}
                {placard.wasAIAssisted && <span style={styles.aiTag}> AI-Assisted</span>}
              </div>
            </div>
            <div style={styles.queueCardRight}>
              <StatusBadge status={placard.status} />
              <div style={styles.actionBtns}>
                <button
                  style={styles.approveBtn}
                  onClick={() => { setSelected(placard); setAction('approve'); }}
                >
                  Approve
                </button>
                <button
                  style={styles.rejectBtn}
                  onClick={() => { setSelected(placard); setAction('reject'); }}
                >
                  Reject
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Action Modal */}
      {selected && action && (
        <div style={styles.modalOverlay}>
          <div style={styles.modal}>
            <h3 style={{ marginTop: 0 }}>
              {action === 'approve' ? 'Approve' : 'Reject'} Placard
            </h3>
            <p style={styles.modalPlacardNum}>{selected.placardNumber} — {selected.machineInfo.commonName}</p>

            {action === 'approve' && (
              <div style={styles.warningBox}>
                <strong>⚠ Certification:</strong> By approving this placard, you certify that you have reviewed
                the procedure content, verified it is complete, accurate, and appropriate for the described
                equipment. This placard will be available for LOTO operations upon approval.
              </div>
            )}

            <label style={styles.label}>
              {action === 'reject' ? 'Rejection Comments * (required)' : 'Approval Comments (optional)'}
            </label>
            <textarea
              style={styles.textarea}
              value={comments}
              onChange={(e) => setComments(e.target.value)}
              placeholder={action === 'reject' ? 'Explain what needs to be corrected...' : 'Optional notes...'}
              rows={4}
            />

            <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
              <button style={styles.cancelBtn} onClick={() => { setSelected(null); setAction(null); setComments(''); }}>
                Cancel
              </button>
              <button
                style={action === 'approve' ? styles.approveBtn : styles.rejectBtn}
                onClick={handleAction}
                disabled={approveMutation.isPending || rejectMutation.isPending}
              >
                {action === 'approve' ? 'Confirm Approval' : 'Confirm Rejection'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function StatusBadge({ status }: { status: PlacardStatus }) {
  const colors: Record<string, string> = {
    [PlacardStatus.PENDING_REVIEW]: '#FF9800',
    [PlacardStatus.IN_REVIEW]: '#2196F3',
    [PlacardStatus.PENDING_APPROVAL]: '#9C27B0',
  };
  return (
    <span style={{ ...styles.statusBadge, backgroundColor: colors[status] ?? '#888' }}>
      {status.replace(/_/g, ' ').toUpperCase()}
    </span>
  );
}

const styles: Record<string, React.CSSProperties> = {
  pageHeader: { display: 'flex', alignItems: 'center', gap: 12, marginBottom: 24 },
  pageTitle: { margin: 0, fontSize: 22, fontWeight: 700 },
  countBadge: { backgroundColor: '#CC0000', color: '#FFF', borderRadius: 12, padding: '3px 10px', fontSize: 13, fontWeight: 700 },
  queue: { display: 'flex', flexDirection: 'column', gap: 10 },
  queueCard: { backgroundColor: '#FFF', border: '1px solid #E0E0E0', borderRadius: 8, padding: '16px 20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' },
  queueCardLeft: { flex: 1 },
  queueCardRight: { display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 10 },
  placardNum: { fontWeight: 700, fontSize: 15, color: '#1A1A1A', fontFamily: 'monospace' },
  machineName: { fontSize: 13, color: '#333', marginTop: 3 },
  meta: { fontSize: 11, color: '#888', marginTop: 4 },
  aiTag: { backgroundColor: '#E3F2FD', color: '#1976D2', padding: '1px 6px', borderRadius: 3, fontWeight: 600 },
  statusBadge: { color: '#FFF', padding: '3px 8px', borderRadius: 4, fontSize: 10, fontWeight: 700 },
  actionBtns: { display: 'flex', gap: 8 },
  approveBtn: { backgroundColor: '#2E7D32', color: '#FFF', border: 'none', borderRadius: 5, padding: '7px 16px', cursor: 'pointer', fontSize: 12, fontWeight: 600 },
  rejectBtn: { backgroundColor: '#CC0000', color: '#FFF', border: 'none', borderRadius: 5, padding: '7px 16px', cursor: 'pointer', fontSize: 12, fontWeight: 600 },
  emptyState: { textAlign: 'center', padding: 48, color: '#888' },
  emptyIcon: { fontSize: 48, color: '#4CAF50', marginBottom: 8 },
  // Modal
  modalOverlay: { position: 'fixed', inset: 0, backgroundColor: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 },
  modal: { backgroundColor: '#FFF', borderRadius: 12, padding: 28, width: '95%', maxWidth: 520 },
  modalPlacardNum: { fontFamily: 'monospace', color: '#CC0000', fontWeight: 700, fontSize: 14 },
  warningBox: { backgroundColor: '#FFF3CD', borderLeft: '4px solid #FF9800', padding: '10px 14px', fontSize: 12, marginBottom: 16, borderRadius: 4 },
  label: { fontSize: 12, fontWeight: 600, color: '#555', display: 'block', marginBottom: 6, textTransform: 'uppercase' },
  textarea: { width: '100%', border: '1.5px solid #CCC', borderRadius: 6, padding: 10, fontSize: 13, resize: 'vertical', boxSizing: 'border-box' },
  cancelBtn: { flex: 1, backgroundColor: '#FFF', border: '1px solid #CCC', borderRadius: 5, padding: '8px 16px', cursor: 'pointer', fontSize: 13 },
};
