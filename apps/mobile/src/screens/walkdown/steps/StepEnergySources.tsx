// ============================================================
// Step 3 — Energy Source Selection
// Large touch targets for glove-friendly use on shop floor
// ============================================================

import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  TextInput,
  Alert,
} from 'react-native';
import { useWalkdownStore } from '../../../store/walkdownStore';
import type { WalkdownDraft } from '../../../store/walkdownStore';
import { EnergySourceType, ENERGY_SOURCE_LABELS } from '@soteria/shared';
import { v4 as uuidv4 } from 'uuid';

const ENERGY_ICONS: Record<string, string> = {
  electrical: '⚡',
  pneumatic: '💨',
  hydraulic: '💧',
  gravity: '↓',
  spring_tension: '🔄',
  steam: '♨',
  gas: '⚗',
  thermal: '🌡',
  chemical: '⚗',
  vacuum: '◎',
  stored_mechanical: '⚙',
  kinetic: '▷',
  other: '◆',
};

interface Props {
  draft: WalkdownDraft;
  onNext: () => void;
}

export function StepEnergySources({ draft, onNext }: Props) {
  const updateDraft = useWalkdownStore((s) => s.updateDraft);
  const [editingSource, setEditingSource] = useState<{
    id: string;
    type: EnergySourceType;
    description: string;
    voltage?: string;
    pressure?: string;
    location?: string;
  } | null>(null);

  const toggleEnergyType = (type: EnergySourceType) => {
    const existing = draft.energySources.find((s) => s.type === type);
    if (existing) {
      // Remove
      updateDraft(draft.id, {
        energySources: draft.energySources.filter((s) => s.type !== type),
      });
    } else {
      // Add with defaults
      const newSource = {
        id: uuidv4(),
        type,
        description: ENERGY_SOURCE_LABELS[type] ?? type,
        location: '',
      };
      updateDraft(draft.id, {
        energySources: [...draft.energySources, newSource],
      });
      setEditingSource(newSource);
    }
  };

  const saveEditingSource = () => {
    if (!editingSource) return;
    if (!editingSource.description.trim()) {
      Alert.alert('Required', 'Enter a description for this energy source');
      return;
    }
    updateDraft(draft.id, {
      energySources: draft.energySources.map((s) =>
        s.id === editingSource.id ? editingSource : s
      ),
    });
    setEditingSource(null);
  };

  const isSelected = (type: EnergySourceType) =>
    draft.energySources.some((s) => s.type === type);

  if (editingSource) {
    return (
      <View style={styles.editContainer}>
        <Text style={styles.editTitle}>
          {ENERGY_ICONS[editingSource.type]} {ENERGY_SOURCE_LABELS[editingSource.type]}
        </Text>
        <Text style={styles.editLabel}>Description *</Text>
        <TextInput
          style={styles.input}
          value={editingSource.description}
          onChangeText={(v) => setEditingSource({ ...editingSource, description: v })}
          placeholder="e.g. 480V 3-phase motor feed"
          multiline
        />
        {(editingSource.type === EnergySourceType.ELECTRICAL) && (
          <>
            <Text style={styles.editLabel}>Voltage</Text>
            <TextInput
              style={styles.input}
              value={editingSource.voltage}
              onChangeText={(v) => setEditingSource({ ...editingSource, voltage: v })}
              placeholder="e.g. 480V, 120V"
            />
          </>
        )}
        {(editingSource.type === EnergySourceType.PNEUMATIC ||
          editingSource.type === EnergySourceType.HYDRAULIC) && (
          <>
            <Text style={styles.editLabel}>Pressure</Text>
            <TextInput
              style={styles.input}
              value={editingSource.pressure}
              onChangeText={(v) => setEditingSource({ ...editingSource, pressure: v })}
              placeholder="e.g. 90 PSI"
            />
          </>
        )}
        <Text style={styles.editLabel}>Physical Location</Text>
        <TextInput
          style={styles.input}
          value={editingSource.location}
          onChangeText={(v) => setEditingSource({ ...editingSource, location: v })}
          placeholder="e.g. MCC Panel A, East wall"
        />
        <TouchableOpacity style={styles.saveBtn} onPress={saveEditingSource}>
          <Text style={styles.saveBtnText}>SAVE ENERGY SOURCE</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.infoBox}>
        <Text style={styles.infoText}>
          Select ALL hazardous energy sources present on this equipment.
          Tap a selected source to edit its details.
        </Text>
      </View>

      {/* Energy source grid */}
      <View style={styles.grid}>
        {Object.values(EnergySourceType).map((type) => {
          const selected = isSelected(type);
          const source = draft.energySources.find((s) => s.type === type);
          return (
            <TouchableOpacity
              key={type}
              style={[styles.energyTile, selected && styles.energyTileSelected]}
              onPress={() => {
                if (selected && source) {
                  setEditingSource(source);
                } else {
                  toggleEnergyType(type);
                }
              }}
              activeOpacity={0.7}
            >
              <Text style={styles.energyIcon}>{ENERGY_ICONS[type]}</Text>
              <Text style={[styles.energyLabel, selected && styles.energyLabelSelected]}>
                {ENERGY_SOURCE_LABELS[type]}
              </Text>
              {selected && <View style={styles.selectedCheckmark}><Text style={styles.checkmark}>✓</Text></View>}
            </TouchableOpacity>
          );
        })}
      </View>

      {/* Selected sources summary */}
      {draft.energySources.length > 0 && (
        <View style={styles.summary}>
          <Text style={styles.summaryTitle}>
            {draft.energySources.length} ENERGY SOURCE{draft.energySources.length > 1 ? 'S' : ''} IDENTIFIED
          </Text>
          {draft.energySources.map((source) => (
            <TouchableOpacity
              key={source.id}
              style={styles.summaryItem}
              onPress={() => setEditingSource(source)}
            >
              <Text style={styles.summaryIcon}>{ENERGY_ICONS[source.type]}</Text>
              <View style={styles.summaryInfo}>
                <Text style={styles.summaryType}>{ENERGY_SOURCE_LABELS[source.type]}</Text>
                <Text style={styles.summaryDesc}>{source.description}</Text>
                {source.voltage && <Text style={styles.summaryMeta}>{source.voltage}</Text>}
                {source.pressure && <Text style={styles.summaryMeta}>{source.pressure}</Text>}
              </View>
              <Text style={styles.editIcon}>✏</Text>
            </TouchableOpacity>
          ))}
        </View>
      )}

      <TouchableOpacity
        style={[styles.nextBtn, draft.energySources.length === 0 && styles.nextBtnDisabled]}
        onPress={onNext}
        disabled={draft.energySources.length === 0}
      >
        <Text style={styles.nextBtnText}>
          NEXT: ISOLATION POINTS →
        </Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  infoBox: {
    backgroundColor: '#FFF3CD',
    borderLeftWidth: 4,
    borderLeftColor: '#FF9800',
    padding: 12,
    marginBottom: 16,
    borderRadius: 4,
  },
  infoText: { fontSize: 13, color: '#1A1A1A' },
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginBottom: 20 },
  energyTile: {
    width: '30%',
    backgroundColor: '#FFF',
    borderWidth: 1.5,
    borderColor: '#DDDDDD',
    borderRadius: 8,
    padding: 12,
    alignItems: 'center',
    position: 'relative',
    minHeight: 80,
  },
  energyTileSelected: {
    borderColor: '#CC0000',
    backgroundColor: '#FFF5F5',
  },
  energyIcon: { fontSize: 22, marginBottom: 4 },
  energyLabel: { fontSize: 10, color: '#555', textAlign: 'center', fontWeight: '600' },
  energyLabelSelected: { color: '#CC0000' },
  selectedCheckmark: {
    position: 'absolute',
    top: 4,
    right: 6,
  },
  checkmark: { color: '#CC0000', fontSize: 12, fontWeight: '700' },
  summary: {
    backgroundColor: '#FFF',
    borderRadius: 8,
    padding: 14,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  summaryTitle: { fontSize: 10, fontWeight: '700', color: '#888', letterSpacing: 1, marginBottom: 8 },
  summaryItem: { flexDirection: 'row', alignItems: 'center', paddingVertical: 8, borderBottomWidth: 0.5, borderBottomColor: '#EEE' },
  summaryIcon: { fontSize: 20, marginRight: 10 },
  summaryInfo: { flex: 1 },
  summaryType: { fontWeight: '700', fontSize: 13, color: '#1A1A1A' },
  summaryDesc: { fontSize: 12, color: '#555', marginTop: 1 },
  summaryMeta: { fontSize: 11, color: '#888', marginTop: 1 },
  editIcon: { fontSize: 16, color: '#999' },
  // Edit form
  editContainer: { padding: 16 },
  editTitle: { fontSize: 20, fontWeight: '700', color: '#1A1A1A', marginBottom: 20 },
  editLabel: { fontSize: 12, fontWeight: '600', color: '#555', marginBottom: 6, textTransform: 'uppercase' },
  input: {
    backgroundColor: '#FFF',
    borderWidth: 1.5,
    borderColor: '#CCC',
    borderRadius: 6,
    padding: 12,
    fontSize: 15,
    marginBottom: 16,
    minHeight: 48,
  },
  saveBtn: { backgroundColor: '#CC0000', borderRadius: 8, padding: 16, alignItems: 'center', marginTop: 4 },
  saveBtnText: { color: '#FFF', fontWeight: '700', fontSize: 15, letterSpacing: 1 },
  // Next button
  nextBtn: { backgroundColor: '#1A1A1A', borderRadius: 8, padding: 16, alignItems: 'center', marginTop: 8 },
  nextBtnDisabled: { backgroundColor: '#AAAAAA' },
  nextBtnText: { color: '#FFF', fontWeight: '700', fontSize: 14, letterSpacing: 1 },
});
