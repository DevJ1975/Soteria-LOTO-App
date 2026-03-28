// ============================================================
// DashboardScreen
// Main hub for field workers: new placard, resume draft,
// scan QR, recent placards, sync status
// ============================================================

import React, { useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  RefreshControl,
} from 'react-native';
import { useRouter } from 'expo-router';
import { useAuthStore } from '../../store/authStore';
import { useWalkdownStore } from '../../store/walkdownStore';
import { SyncService } from '../../services/sync.service';

export function DashboardScreen() {
  const router = useRouter();
  const user = useAuthStore((s) => s.user);
  const logout = useAuthStore((s) => s.logout);
  const drafts = useWalkdownStore((s) => s.drafts);
  const createDraft = useWalkdownStore((s) => s.createDraft);
  const loadFromStorage = useWalkdownStore((s) => s.loadFromStorage);

  useEffect(() => {
    loadFromStorage();
    // Start background sync listener
    const unsubscribe = SyncService.startBackgroundSync();
    return unsubscribe;
  }, []);

  const pendingDrafts = drafts.filter((d) => d.syncStatus !== 'synced');

  const handleNewPlacard = () => {
    const draftId = createDraft();
    router.push(`/walkdown/${draftId}/step/0`);
  };

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={styles.content}
      refreshControl={
        <RefreshControl refreshing={false} onRefresh={() => SyncService.syncPendingDrafts()} />
      }
    >
      {/* Header */}
      <View style={styles.header}>
        <View>
          <Text style={styles.greeting}>
            {user?.firstName ? `Hi, ${user.firstName}` : 'Dashboard'}
          </Text>
          <Text style={styles.subGreeting}>Field LOTO Procedures</Text>
        </View>
        <TouchableOpacity style={styles.logoutBtn} onPress={logout}>
          <Text style={styles.logoutText}>Sign Out</Text>
        </TouchableOpacity>
      </View>

      {/* Sync status banner */}
      {pendingDrafts.length > 0 && (
        <TouchableOpacity
          style={styles.syncBanner}
          onPress={() => SyncService.syncPendingDrafts()}
        >
          <Text style={styles.syncBannerText}>
            ↑ {pendingDrafts.length} draft{pendingDrafts.length !== 1 ? 's' : ''} pending sync
            — Tap to sync now
          </Text>
        </TouchableOpacity>
      )}

      {/* Primary actions */}
      <Text style={styles.sectionTitle}>ACTIONS</Text>

      <TouchableOpacity style={styles.primaryAction} onPress={handleNewPlacard} activeOpacity={0.85}>
        <Text style={styles.primaryActionIcon}>＋</Text>
        <View style={styles.primaryActionText}>
          <Text style={styles.primaryActionTitle}>New LOTO Placard</Text>
          <Text style={styles.primaryActionSub}>Start a field walkdown</Text>
        </View>
      </TouchableOpacity>

      <View style={styles.actionRow}>
        <TouchableOpacity
          style={styles.secondaryAction}
          onPress={() => router.push('/qr/scan')}
        >
          <Text style={styles.secondaryActionIcon}>⊡</Text>
          <Text style={styles.secondaryActionTitle}>Scan QR</Text>
          <Text style={styles.secondaryActionSub}>Retrieve placard</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.secondaryAction}
          onPress={() => router.push('/placards')}
        >
          <Text style={styles.secondaryActionIcon}>≡</Text>
          <Text style={styles.secondaryActionTitle}>Browse</Text>
          <Text style={styles.secondaryActionSub}>Search placards</Text>
        </TouchableOpacity>
      </View>

      {/* Drafts in progress */}
      {pendingDrafts.length > 0 && (
        <>
          <Text style={styles.sectionTitle}>IN PROGRESS</Text>
          {pendingDrafts.slice(0, 5).map((draft) => (
            <TouchableOpacity
              key={draft.id}
              style={styles.draftCard}
              onPress={() => router.push(`/walkdown/${draft.id}/step/${draft.currentStep}`)}
            >
              <View style={styles.draftCardLeft}>
                <Text style={styles.draftCardTitle}>
                  {draft.machineInfo.commonName || 'Untitled Equipment'}
                </Text>
                <Text style={styles.draftCardSub}>
                  {draft.siteName ?? 'No site selected'} • Step {draft.currentStep + 1} of 8
                </Text>
                <Text style={styles.draftCardDate}>
                  Updated {new Date(draft.updatedAt).toLocaleDateString()}
                </Text>
              </View>
              <SyncStatusBadge status={draft.syncStatus} />
            </TouchableOpacity>
          ))}
        </>
      )}
    </ScrollView>
  );
}

function SyncStatusBadge({ status }: { status: string }) {
  const colors: Record<string, string> = {
    local: '#FF9800',
    syncing: '#2196F3',
    synced: '#4CAF50',
    error: '#CC0000',
  };
  const labels: Record<string, string> = {
    local: 'LOCAL',
    syncing: 'SYNCING',
    synced: 'SYNCED',
    error: 'ERROR',
  };

  return (
    <View style={[styles.syncBadge, { backgroundColor: colors[status] ?? '#999' }]}>
      <Text style={styles.syncBadgeText}>{labels[status] ?? status}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F0F0F0' },
  content: { paddingBottom: 40 },
  header: {
    backgroundColor: '#CC0000',
    paddingTop: 56,
    paddingBottom: 20,
    paddingHorizontal: 20,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-end',
  },
  greeting: { color: '#FFF', fontSize: 22, fontWeight: '700' },
  subGreeting: { color: '#FFCCCC', fontSize: 12, marginTop: 2 },
  logoutBtn: { paddingVertical: 6, paddingHorizontal: 12 },
  logoutText: { color: '#FFCCCC', fontSize: 13 },
  syncBanner: {
    backgroundColor: '#FF9800',
    padding: 12,
    alignItems: 'center',
  },
  syncBannerText: { color: '#FFF', fontWeight: '600', fontSize: 13 },
  sectionTitle: {
    fontSize: 11,
    fontWeight: '700',
    color: '#888',
    letterSpacing: 1.5,
    paddingHorizontal: 20,
    paddingTop: 20,
    paddingBottom: 10,
  },
  primaryAction: {
    marginHorizontal: 16,
    backgroundColor: '#CC0000',
    borderRadius: 10,
    padding: 18,
    flexDirection: 'row',
    alignItems: 'center',
    elevation: 3,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.15,
    shadowRadius: 6,
  },
  primaryActionIcon: { color: '#FFF', fontSize: 32, marginRight: 16 },
  primaryActionText: { flex: 1 },
  primaryActionTitle: { color: '#FFF', fontSize: 18, fontWeight: '700' },
  primaryActionSub: { color: '#FFCCCC', fontSize: 12, marginTop: 3 },
  actionRow: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    gap: 10,
    marginTop: 10,
  },
  secondaryAction: {
    flex: 1,
    backgroundColor: '#FFF',
    borderRadius: 10,
    padding: 16,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  secondaryActionIcon: { fontSize: 28, marginBottom: 6 },
  secondaryActionTitle: { fontWeight: '700', fontSize: 14, color: '#1A1A1A' },
  secondaryActionSub: { fontSize: 11, color: '#888', marginTop: 2 },
  draftCard: {
    backgroundColor: '#FFF',
    marginHorizontal: 16,
    marginBottom: 8,
    borderRadius: 8,
    padding: 14,
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#E8E8E8',
  },
  draftCardLeft: { flex: 1 },
  draftCardTitle: { fontWeight: '600', fontSize: 14, color: '#1A1A1A' },
  draftCardSub: { fontSize: 12, color: '#666', marginTop: 2 },
  draftCardDate: { fontSize: 10, color: '#AAA', marginTop: 3 },
  syncBadge: {
    paddingVertical: 3,
    paddingHorizontal: 8,
    borderRadius: 10,
  },
  syncBadgeText: { color: '#FFF', fontSize: 9, fontWeight: '700', letterSpacing: 0.5 },
});
