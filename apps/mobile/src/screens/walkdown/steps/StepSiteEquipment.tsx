import React, { useEffect, useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, FlatList, TextInput, ActivityIndicator } from 'react-native';
import { useWalkdownStore, WalkdownDraft } from '../../../store/walkdownStore';
import { apiClient } from '../../../config/api';

interface Props { draft: WalkdownDraft; onNext: () => void; }

export function StepSiteEquipment({ draft, onNext }: Props) {
  const updateDraft = useWalkdownStore(s => s.updateDraft);
  const [sites, setSites] = useState<Array<{_id: string; name: string; code: string}>>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    apiClient.get('/sites').then(r => { setSites(r.data.data); setLoading(false); }).catch(() => setLoading(false));
  }, []);

  const selectSite = (site: {_id: string; name: string; code: string}) => {
    updateDraft(draft.id, { siteId: site._id, siteName: site.name });
  };

  if (loading) return <ActivityIndicator style={{ margin: 40 }} />;

  return (
    <View style={styles.container}>
      <Text style={styles.label}>SELECT SITE</Text>
      {sites.map(site => (
        <TouchableOpacity key={site._id} style={[styles.siteBtn, draft.siteId === site._id && styles.siteBtnSelected]}
          onPress={() => selectSite(site)}>
          <Text style={styles.siteName}>{site.name}</Text>
          <Text style={styles.siteCode}>{site.code}</Text>
          {draft.siteId === site._id && <Text style={styles.check}>✓</Text>}
        </TouchableOpacity>
      ))}
      <TouchableOpacity style={[styles.nextBtn, !draft.siteId && styles.nextBtnDisabled]}
        onPress={onNext} disabled={!draft.siteId}>
        <Text style={styles.nextBtnText}>NEXT: MACHINE INFO →</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { padding: 16 },
  label: { fontSize: 11, fontWeight: '700', color: '#888', letterSpacing: 1.5, marginBottom: 10 },
  siteBtn: { backgroundColor: '#FFF', borderWidth: 1.5, borderColor: '#DDD', borderRadius: 8, padding: 16, marginBottom: 8, flexDirection: 'row', alignItems: 'center' },
  siteBtnSelected: { borderColor: '#CC0000', backgroundColor: '#FFF5F5' },
  siteName: { flex: 1, fontWeight: '600', fontSize: 15, color: '#1A1A1A' },
  siteCode: { fontSize: 12, color: '#888', marginRight: 8 },
  check: { color: '#CC0000', fontWeight: '700', fontSize: 16 },
  nextBtn: { backgroundColor: '#1A1A1A', borderRadius: 8, padding: 16, alignItems: 'center', marginTop: 8 },
  nextBtnDisabled: { backgroundColor: '#AAA' },
  nextBtnText: { color: '#FFF', fontWeight: '700', fontSize: 14, letterSpacing: 1 },
});
