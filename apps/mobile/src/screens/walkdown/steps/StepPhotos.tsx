import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Image, Alert, ScrollView } from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { useWalkdownStore, WalkdownDraft } from '../../../store/walkdownStore';
import { MediaCategory } from '@soteria/shared';

interface Props { draft: WalkdownDraft; onNext: () => void; }

const PHOTO_SLOTS = [
  { category: MediaCategory.EQUIPMENT_OVERVIEW, label: 'Equipment Overview', sub: 'Wide shot showing full machine' },
  { category: MediaCategory.NAMEPLATE, label: 'Nameplate / Data Plate', sub: 'Manufacturer tag with specs' },
  { category: MediaCategory.ISOLATION_POINT, label: 'Isolation Point(s)', sub: 'Disconnects, valves, plugs' },
  { category: MediaCategory.STORED_ENERGY, label: 'Stored Energy Points', sub: 'Springs, elevated parts, capacitors' },
];

export function StepPhotos({ draft, onNext }: Props) {
  const addPhoto = useWalkdownStore(s => s.addPhoto);
  const removePhoto = useWalkdownStore(s => s.removePhoto);

  const capturePhoto = async (category: string) => {
    const { status } = await ImagePicker.requestCameraPermissionsAsync();
    if (status !== 'granted') { Alert.alert('Camera permission required'); return; }
    const result = await ImagePicker.launchCameraAsync({ quality: 0.8, allowsEditing: false });
    if (!result.canceled && result.assets[0]) {
      addPhoto(draft.id, { uri: result.assets[0].uri, category });
    }
  };

  return (
    <ScrollView style={styles.container}>
      <View style={styles.infoBox}>
        <Text style={styles.infoText}>Capture photos to document the equipment. Required: at least an equipment overview photo.</Text>
      </View>
      {PHOTO_SLOTS.map(slot => {
        const photo = draft.photos.find(p => p.category === slot.category);
        return (
          <View key={slot.category} style={styles.slot}>
            <View style={styles.slotInfo}>
              <Text style={styles.slotLabel}>{slot.label}</Text>
              <Text style={styles.slotSub}>{slot.sub}</Text>
            </View>
            {photo ? (
              <View style={styles.photoPreview}>
                <Image source={{ uri: photo.uri }} style={styles.thumb} />
                <TouchableOpacity style={styles.removeBtn} onPress={() => removePhoto(draft.id, photo.id)}>
                  <Text style={styles.removeBtnText}>✕ Remove</Text>
                </TouchableOpacity>
              </View>
            ) : (
              <TouchableOpacity style={styles.captureBtn} onPress={() => capturePhoto(slot.category)}>
                <Text style={styles.captureBtnIcon}>📷</Text>
                <Text style={styles.captureBtnText}>Capture</Text>
              </TouchableOpacity>
            )}
          </View>
        );
      })}
      <TouchableOpacity style={[styles.nextBtn, !draft.photos.find(p => p.category === MediaCategory.EQUIPMENT_OVERVIEW) && styles.nextBtnWarn]}
        onPress={onNext}>
        <Text style={styles.nextBtnText}>{draft.photos.find(p => p.category === MediaCategory.EQUIPMENT_OVERVIEW) ? 'NEXT: ENERGY SOURCES →' : 'SKIP PHOTOS (not recommended)'}</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  infoBox: { backgroundColor: '#FFF3CD', padding: 10, borderRadius: 6, marginBottom: 14, borderLeftWidth: 3, borderLeftColor: '#FF9800' },
  infoText: { fontSize: 12, color: '#1A1A1A' },
  slot: { backgroundColor: '#FFF', borderRadius: 8, padding: 14, marginBottom: 10, borderWidth: 1, borderColor: '#E0E0E0', flexDirection: 'row', alignItems: 'center' },
  slotInfo: { flex: 1 },
  slotLabel: { fontWeight: '600', fontSize: 13, color: '#1A1A1A' },
  slotSub: { fontSize: 11, color: '#888', marginTop: 2 },
  captureBtn: { backgroundColor: '#F5F5F5', borderRadius: 8, padding: 12, alignItems: 'center', width: 80, borderWidth: 1, borderColor: '#DDD' },
  captureBtnIcon: { fontSize: 22 },
  captureBtnText: { fontSize: 10, color: '#555', marginTop: 3 },
  photoPreview: { alignItems: 'center', width: 80 },
  thumb: { width: 72, height: 54, borderRadius: 6, marginBottom: 4 },
  removeBtn: { padding: 4 },
  removeBtnText: { fontSize: 10, color: '#CC0000' },
  nextBtn: { backgroundColor: '#1A1A1A', borderRadius: 8, padding: 16, alignItems: 'center', marginTop: 8, marginBottom: 32 },
  nextBtnWarn: { backgroundColor: '#FF9800' },
  nextBtnText: { color: '#FFF', fontWeight: '700', fontSize: 13, letterSpacing: 0.5 },
});
