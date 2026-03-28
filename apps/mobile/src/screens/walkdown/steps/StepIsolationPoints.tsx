import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, ScrollView } from 'react-native';
import { useWalkdownStore, WalkdownDraft, WalkdownIsolationPoint } from '../../../store/walkdownStore';
import { LockoutDeviceType, LOCKOUT_DEVICE_LABELS } from '@soteria/shared';
import { v4 as uuidv4 } from 'uuid';

interface Props { draft: WalkdownDraft; onNext: () => void; }

export function StepIsolationPoints({ draft, onNext }: Props) {
  const updateDraft = useWalkdownStore(s => s.updateDraft);
  const [adding, setAdding] = useState(false);
  const [newPoint, setNewPoint] = useState<Partial<WalkdownIsolationPoint>>({ deviceType: LockoutDeviceType.CIRCUIT_BREAKER_LOCKOUT });

  const savePoint = () => {
    if (!newPoint.description?.trim() || !newPoint.location?.trim()) return;
    const point: WalkdownIsolationPoint = {
      id: uuidv4(), sequence: draft.isolationPoints.length + 1,
      description: newPoint.description!, deviceType: newPoint.deviceType ?? LockoutDeviceType.OTHER,
      location: newPoint.location!, normalState: newPoint.normalState, isolatedState: newPoint.isolatedState, photoIds: [],
    };
    updateDraft(draft.id, { isolationPoints: [...draft.isolationPoints, point] });
    setAdding(false);
    setNewPoint({ deviceType: LockoutDeviceType.CIRCUIT_BREAKER_LOCKOUT });
  };

  return (
    <ScrollView style={styles.container}>
      {draft.isolationPoints.map(p => (
        <View key={p.id} style={styles.pointCard}>
          <View style={styles.seqBadge}><Text style={styles.seqText}>{p.sequence}</Text></View>
          <View style={styles.pointInfo}>
            <Text style={styles.pointDesc}>{p.description}</Text>
            <Text style={styles.pointMeta}>{LOCKOUT_DEVICE_LABELS[p.deviceType]} • {p.location}</Text>
            {p.normalState && <Text style={styles.pointState}>{p.normalState} → {p.isolatedState}</Text>}
          </View>
        </View>
      ))}
      {adding ? (
        <View style={styles.addForm}>
          <Text style={styles.formTitle}>New Isolation Point #{draft.isolationPoints.length + 1}</Text>
          <Text style={styles.label}>Description *</Text>
          <TextInput style={styles.input} value={newPoint.description ?? ''} onChangeText={v => setNewPoint(p => ({ ...p, description: v }))} placeholder="e.g. Disconnect D-47 on Panel LP-3" />
          <Text style={styles.label}>Location *</Text>
          <TextInput style={styles.input} value={newPoint.location ?? ''} onChangeText={v => setNewPoint(p => ({ ...p, location: v }))} placeholder="e.g. East wall, Panel LP-3" />
          <Text style={styles.label}>Normal State</Text>
          <TextInput style={styles.input} value={newPoint.normalState ?? ''} onChangeText={v => setNewPoint(p => ({ ...p, normalState: v }))} placeholder="e.g. CLOSED / ENERGIZED" />
          <Text style={styles.label}>Isolated State</Text>
          <TextInput style={styles.input} value={newPoint.isolatedState ?? ''} onChangeText={v => setNewPoint(p => ({ ...p, isolatedState: v }))} placeholder="e.g. OPEN / DE-ENERGIZED" />
          <View style={{ flexDirection: 'row', gap: 8 }}>
            <TouchableOpacity style={styles.cancelBtn} onPress={() => setAdding(false)}><Text style={styles.cancelBtnText}>Cancel</Text></TouchableOpacity>
            <TouchableOpacity style={styles.saveBtn} onPress={savePoint}><Text style={styles.saveBtnText}>SAVE POINT</Text></TouchableOpacity>
          </View>
        </View>
      ) : (
        <TouchableOpacity style={styles.addBtn} onPress={() => setAdding(true)}>
          <Text style={styles.addBtnText}>+ ADD ISOLATION POINT</Text>
        </TouchableOpacity>
      )}
      <TouchableOpacity style={[styles.nextBtn, draft.isolationPoints.length === 0 && styles.nextBtnWarn]} onPress={onNext}>
        <Text style={styles.nextBtnText}>{draft.isolationPoints.length > 0 ? `NEXT: FIELD NOTES → (${draft.isolationPoints.length} points)` : 'NEXT (no points added)'}</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  pointCard: { backgroundColor: '#FFF', borderRadius: 8, padding: 12, marginBottom: 8, flexDirection: 'row', alignItems: 'flex-start', borderWidth: 1, borderColor: '#E0E0E0' },
  seqBadge: { width: 28, height: 28, borderRadius: 14, backgroundColor: '#CC0000', alignItems: 'center', justifyContent: 'center', marginRight: 10, marginTop: 2 },
  seqText: { color: '#FFF', fontWeight: '700', fontSize: 12 },
  pointInfo: { flex: 1 },
  pointDesc: { fontWeight: '600', fontSize: 13, color: '#1A1A1A' },
  pointMeta: { fontSize: 11, color: '#666', marginTop: 2 },
  pointState: { fontSize: 10, color: '#888', marginTop: 2 },
  addForm: { backgroundColor: '#FFF', borderRadius: 8, padding: 14, marginBottom: 10, borderWidth: 1, borderColor: '#DDD' },
  formTitle: { fontWeight: '700', fontSize: 14, color: '#1A1A1A', marginBottom: 12 },
  label: { fontSize: 11, fontWeight: '600', color: '#555', marginBottom: 5, textTransform: 'uppercase' },
  input: { backgroundColor: '#F5F5F5', borderWidth: 1, borderColor: '#CCC', borderRadius: 6, padding: 10, fontSize: 13, marginBottom: 12, minHeight: 44 },
  cancelBtn: { flex: 1, backgroundColor: '#FFF', borderWidth: 1, borderColor: '#CCC', borderRadius: 6, padding: 12, alignItems: 'center' },
  cancelBtnText: { color: '#555', fontWeight: '600' },
  saveBtn: { flex: 2, backgroundColor: '#1A1A1A', borderRadius: 6, padding: 12, alignItems: 'center' },
  saveBtnText: { color: '#FFF', fontWeight: '700', letterSpacing: 0.5 },
  addBtn: { borderWidth: 2, borderColor: '#CC0000', borderRadius: 8, padding: 14, alignItems: 'center', borderStyle: 'dashed', marginBottom: 12 },
  addBtnText: { color: '#CC0000', fontWeight: '700', fontSize: 13 },
  nextBtn: { backgroundColor: '#1A1A1A', borderRadius: 8, padding: 16, alignItems: 'center', marginBottom: 32 },
  nextBtnWarn: { backgroundColor: '#FF9800' },
  nextBtnText: { color: '#FFF', fontWeight: '700', fontSize: 13 },
});
