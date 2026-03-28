import React, { useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, ScrollView, Alert, ActivityIndicator } from 'react-native';
import { useRouter } from 'expo-router';
import { useWalkdownStore, WalkdownDraft } from '../../../store/walkdownStore';
import { SyncService } from '../../../services/sync.service';

interface Props { draft: WalkdownDraft; }

export function StepReviewSave({ draft }: Props) {
  const router = useRouter();
  const updateDraft = useWalkdownStore(s => s.updateDraft);
  const [saving, setSaving] = useState(false);

  const saveAndSync = async () => {
    setSaving(true);
    try {
      await SyncService.syncPendingDrafts();
      Alert.alert('Saved!', `Placard draft saved${draft.serverPlacardId ? ' and synced to server' : ' locally'}. It can be reviewed and approved in the web admin portal.`, [
        { text: 'Return to Dashboard', onPress: () => router.replace('/') }
      ]);
    } catch {
      Alert.alert('Saved Locally', 'Draft saved to this device. Will sync when connected.');
      router.replace('/');
    } finally {
      setSaving(false);
    }
  };

  return (
    <ScrollView style={styles.container}>
      <View style={styles.checkCard}>
        <Text style={styles.checkTitle}>DRAFT SUMMARY</Text>
        <Row label="Machine" value={draft.machineInfo.commonName || 'Not set'} />
        <Row label="Equipment ID" value={draft.machineInfo.equipmentId || 'Not set'} />
        <Row label="Location" value={draft.machineInfo.location || 'Not set'} />
        <Row label="Energy Sources" value={`${draft.energySources.length}`} />
        <Row label="Isolation Points" value={`${draft.isolationPoints.length}`} />
        <Row label="Photos" value={`${draft.photos.length}`} />
        <Row label="AI Draft" value={draft.aiDraft ? 'Generated ✓' : 'Not generated'} />
        <Row label="Sync Status" value={draft.syncStatus.toUpperCase()} />
      </View>
      <View style={styles.noteBox}>
        <Text style={styles.noteText}>After saving, the placard will be available in the web admin portal for review and approval. The placard cannot be used for LOTO operations until it is reviewed and approved by an authorized person.</Text>
      </View>
      <TouchableOpacity style={styles.saveBtn} onPress={saveAndSync} disabled={saving}>
        {saving ? <ActivityIndicator color="#FFF" /> : <Text style={styles.saveBtnText}>💾 SAVE DRAFT</Text>}
      </TouchableOpacity>
      <TouchableOpacity style={styles.cancelBtn} onPress={() => router.replace('/')}>
        <Text style={styles.cancelBtnText}>Return to Dashboard without saving</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.row}>
      <Text style={styles.rowLabel}>{label}</Text>
      <Text style={styles.rowValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  checkCard: { backgroundColor: '#FFF', borderRadius: 8, padding: 16, marginBottom: 14, borderWidth: 1, borderColor: '#E0E0E0' },
  checkTitle: { fontSize: 10, fontWeight: '700', color: '#888', letterSpacing: 1.5, marginBottom: 12 },
  row: { flexDirection: 'row', paddingVertical: 6, borderBottomWidth: 0.5, borderBottomColor: '#EEE' },
  rowLabel: { flex: 1, fontSize: 12, fontWeight: '600', color: '#555' },
  rowValue: { fontSize: 12, color: '#1A1A1A', fontWeight: '500' },
  noteBox: { backgroundColor: '#FFF3CD', padding: 12, borderRadius: 6, marginBottom: 16, borderLeftWidth: 3, borderLeftColor: '#FF9800' },
  noteText: { fontSize: 12, color: '#1A1A1A', lineHeight: 18 },
  saveBtn: { backgroundColor: '#CC0000', borderRadius: 8, padding: 18, alignItems: 'center', marginBottom: 10, minHeight: 56 },
  saveBtnText: { color: '#FFF', fontWeight: '700', fontSize: 15, letterSpacing: 1 },
  cancelBtn: { padding: 12, alignItems: 'center' },
  cancelBtnText: { color: '#888', fontSize: 13 },
});
