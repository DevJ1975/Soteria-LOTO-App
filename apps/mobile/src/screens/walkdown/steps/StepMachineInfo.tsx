import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, ScrollView } from 'react-native';
import { useWalkdownStore, WalkdownDraft } from '../../../store/walkdownStore';

interface Props { draft: WalkdownDraft; onNext: () => void; }
interface FieldConfig { key: string; label: string; placeholder: string; required?: boolean; }

const FIELDS: FieldConfig[] = [
  { key: 'equipmentId', label: 'Equipment ID / Asset Tag *', placeholder: 'e.g. MIX-003', required: true },
  { key: 'commonName', label: 'Common Name *', placeholder: 'e.g. Horizontal Mixer #3', required: true },
  { key: 'formalName', label: 'Formal Name *', placeholder: 'e.g. Ribbon Blender / Horizontal Mixer', required: true },
  { key: 'manufacturer', label: 'Manufacturer', placeholder: 'e.g. Munson Machinery' },
  { key: 'model', label: 'Model', placeholder: 'e.g. RC-600' },
  { key: 'serialNumber', label: 'Serial Number', placeholder: 'From nameplate' },
  { key: 'location', label: 'Location *', placeholder: 'e.g. Line 3, East Building', required: true },
  { key: 'department', label: 'Department', placeholder: 'e.g. Mixing' },
  { key: 'electricalVoltage', label: 'Electrical Voltage', placeholder: 'e.g. 480V 3-Phase' },
  { key: 'pneumaticPressure', label: 'Air Pressure (if any)', placeholder: 'e.g. 90 PSI' },
  { key: 'hydraulicPressure', label: 'Hydraulic Pressure (if any)', placeholder: 'e.g. 2000 PSI' },
];

export function StepMachineInfo({ draft, onNext }: Props) {
  const updateDraft = useWalkdownStore(s => s.updateDraft);
  const [info, setInfo] = useState({ ...draft.machineInfo });

  const setField = (key: string, value: string) => setInfo(prev => ({ ...prev, [key]: value }));

  const save = () => {
    const required = FIELDS.filter(f => f.required);
    for (const f of required) {
      if (!info[f.key as keyof typeof info]?.trim()) {
        return;
      }
    }
    updateDraft(draft.id, { machineInfo: info });
    onNext();
  };

  return (
    <ScrollView style={styles.container} keyboardShouldPersistTaps="handled">
      {FIELDS.map(field => (
        <View key={field.key} style={styles.fieldBlock}>
          <Text style={styles.label}>{field.label}</Text>
          <TextInput
            style={styles.input}
            value={info[field.key as keyof typeof info] ?? ''}
            onChangeText={v => setField(field.key, v)}
            placeholder={field.placeholder}
            placeholderTextColor="#AAA"
          />
        </View>
      ))}
      <View style={styles.fieldBlock}>
        <Text style={styles.label}>Operational Notes</Text>
        <TextInput style={[styles.input, { minHeight: 80 }]}
          value={info.operationalNotes ?? ''}
          onChangeText={v => setField('operationalNotes', v)}
          placeholder="Special conditions, known hazards, references..."
          placeholderTextColor="#AAA" multiline />
      </View>
      <TouchableOpacity style={styles.nextBtn} onPress={save}>
        <Text style={styles.nextBtnText}>SAVE & NEXT: PHOTOS →</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  fieldBlock: { marginBottom: 14 },
  label: { fontSize: 11, fontWeight: '600', color: '#555', marginBottom: 5, textTransform: 'uppercase', letterSpacing: 0.5 },
  input: { backgroundColor: '#FFF', borderWidth: 1.5, borderColor: '#CCC', borderRadius: 6, padding: 12, fontSize: 14, color: '#1A1A1A', minHeight: 48 },
  nextBtn: { backgroundColor: '#1A1A1A', borderRadius: 8, padding: 16, alignItems: 'center', marginTop: 4, marginBottom: 32 },
  nextBtnText: { color: '#FFF', fontWeight: '700', fontSize: 14, letterSpacing: 1 },
});
