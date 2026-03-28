import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, ScrollView } from 'react-native';
import { useWalkdownStore, WalkdownDraft } from '../../../store/walkdownStore';

interface Props { draft: WalkdownDraft; onNext: () => void; }

export function StepFieldNotes({ draft, onNext }: Props) {
  const updateDraft = useWalkdownStore(s => s.updateDraft);
  const [notes, setNotes] = useState(draft.fieldNotes ?? '');

  const save = () => {
    updateDraft(draft.id, { fieldNotes: notes });
    onNext();
  };

  return (
    <ScrollView style={styles.container} keyboardShouldPersistTaps="handled">
      <View style={styles.infoBox}>
        <Text style={styles.infoText}>Add any field observations, special hazards, or conditions the AI should consider when generating the draft procedure.</Text>
      </View>
      <Text style={styles.label}>FIELD NOTES FOR AI DRAFT</Text>
      <TextInput style={styles.notesInput} value={notes} onChangeText={setNotes}
        placeholder="e.g. Machine has residual hydraulic pressure in ram cylinder after shutdown. Pneumatic line stays pressurized unless bled manually at south valve. Gravity hazard from 200lb hopper lid..."
        multiline placeholderTextColor="#AAA" />
      <TouchableOpacity style={styles.nextBtn} onPress={save}>
        <Text style={styles.nextBtnText}>NEXT: GENERATE AI DRAFT →</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  infoBox: { backgroundColor: '#E3F2FD', borderLeftWidth: 4, borderLeftColor: '#1976D2', padding: 12, borderRadius: 4, marginBottom: 14 },
  infoText: { fontSize: 13, color: '#1A1A1A' },
  label: { fontSize: 11, fontWeight: '700', color: '#888', letterSpacing: 1.5, marginBottom: 8 },
  notesInput: { backgroundColor: '#FFF', borderWidth: 1.5, borderColor: '#CCC', borderRadius: 8, padding: 14, fontSize: 14, color: '#1A1A1A', minHeight: 200, textAlignVertical: 'top' },
  nextBtn: { backgroundColor: '#CC0000', borderRadius: 8, padding: 16, alignItems: 'center', marginTop: 16, marginBottom: 32 },
  nextBtnText: { color: '#FFF', fontWeight: '700', fontSize: 14, letterSpacing: 1 },
});
