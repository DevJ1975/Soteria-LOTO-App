// ============================================================
// WalkdownWizard — 8-step guided field walkdown flow
//
// Step 0: Site & Equipment Selection
// Step 1: Machine Information Entry
// Step 2: Photo Capture — Equipment Overview & Nameplate
// Step 3: Energy Source Selection
// Step 4: Isolation Point Capture (with photos)
// Step 5: Field Notes & Special Conditions
// Step 6: AI Draft Generation & Review
// Step 7: Review & Save / Submit
// ============================================================

import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useWalkdownStore } from '../../store/walkdownStore';

// Step components
import { StepSiteEquipment } from './steps/StepSiteEquipment';
import { StepMachineInfo } from './steps/StepMachineInfo';
import { StepPhotos } from './steps/StepPhotos';
import { StepEnergySources } from './steps/StepEnergySources';
import { StepIsolationPoints } from './steps/StepIsolationPoints';
import { StepFieldNotes } from './steps/StepFieldNotes';
import { StepAIDraft } from './steps/StepAIDraft';
import { StepReviewSave } from './steps/StepReviewSave';

const STEPS = [
  { title: 'Site & Equipment', subtitle: 'Select or create equipment record' },
  { title: 'Machine Info', subtitle: 'Enter nameplate and machine details' },
  { title: 'Photos', subtitle: 'Capture equipment and isolation point photos' },
  { title: 'Energy Sources', subtitle: 'Identify all hazardous energy sources' },
  { title: 'Isolation Points', subtitle: 'Document lockout devices and locations' },
  { title: 'Field Notes', subtitle: 'Add notes, special conditions, PPE' },
  { title: 'AI Draft', subtitle: 'Generate AI-assisted procedure draft' },
  { title: 'Review & Save', subtitle: 'Review draft and save to system' },
];

export function WalkdownWizard() {
  const { draftId, step } = useLocalSearchParams<{ draftId: string; step: string }>();
  const router = useRouter();
  const currentStep = parseInt(step ?? '0', 10);
  const updateDraft = useWalkdownStore((s) => s.updateDraft);
  const drafts = useWalkdownStore((s) => s.drafts);
  const draft = drafts.find((d) => d.id === draftId);

  if (!draft) {
    return (
      <View style={styles.errorContainer}>
        <Text style={styles.errorText}>Draft not found</Text>
        <TouchableOpacity onPress={() => router.replace('/')}>
          <Text style={styles.errorLink}>Return to Dashboard</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const goToStep = (newStep: number) => {
    updateDraft(draftId, { currentStep: newStep });
    router.push(`/walkdown/${draftId}/step/${newStep}`);
  };

  const goNext = () => {
    if (currentStep < STEPS.length - 1) goToStep(currentStep + 1);
  };

  const goBack = () => {
    if (currentStep > 0) goToStep(currentStep - 1);
    else router.replace('/');
  };

  const stepInfo = STEPS[currentStep];

  return (
    <View style={styles.container}>
      {/* Progress header */}
      <View style={styles.progressHeader}>
        <View style={styles.progressTop}>
          <TouchableOpacity onPress={goBack} style={styles.backBtn}>
            <Text style={styles.backBtnText}>← Back</Text>
          </TouchableOpacity>
          <Text style={styles.stepCount}>
            Step {currentStep + 1} of {STEPS.length}
          </Text>
          <TouchableOpacity onPress={() => router.replace('/')} style={styles.saveExitBtn}>
            <Text style={styles.saveExitText}>Save & Exit</Text>
          </TouchableOpacity>
        </View>

        {/* Step title */}
        <View style={styles.stepTitleBlock}>
          <Text style={styles.stepTitle}>{stepInfo.title}</Text>
          <Text style={styles.stepSubtitle}>{stepInfo.subtitle}</Text>
        </View>

        {/* Progress dots */}
        <View style={styles.progressDots}>
          {STEPS.map((_, idx) => (
            <View
              key={idx}
              style={[
                styles.dot,
                idx < currentStep && styles.dotCompleted,
                idx === currentStep && styles.dotActive,
              ]}
            />
          ))}
        </View>
      </View>

      {/* Step content */}
      <ScrollView style={styles.stepContent} keyboardShouldPersistTaps="handled">
        {currentStep === 0 && <StepSiteEquipment draft={draft} onNext={goNext} />}
        {currentStep === 1 && <StepMachineInfo draft={draft} onNext={goNext} />}
        {currentStep === 2 && <StepPhotos draft={draft} onNext={goNext} />}
        {currentStep === 3 && <StepEnergySources draft={draft} onNext={goNext} />}
        {currentStep === 4 && <StepIsolationPoints draft={draft} onNext={goNext} />}
        {currentStep === 5 && <StepFieldNotes draft={draft} onNext={goNext} />}
        {currentStep === 6 && <StepAIDraft draft={draft} onNext={goNext} />}
        {currentStep === 7 && <StepReviewSave draft={draft} />}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#F5F5F5' },
  progressHeader: {
    backgroundColor: '#1A1A1A',
    paddingTop: 52,
    paddingBottom: 14,
    paddingHorizontal: 16,
  },
  progressTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  backBtn: { paddingVertical: 4, paddingRight: 12 },
  backBtnText: { color: '#CCCCCC', fontSize: 14 },
  stepCount: { color: '#AAAAAA', fontSize: 12 },
  saveExitBtn: { paddingVertical: 4, paddingLeft: 12 },
  saveExitText: { color: '#FF9800', fontSize: 13, fontWeight: '600' },
  stepTitleBlock: { marginBottom: 10 },
  stepTitle: { color: '#FFFFFF', fontSize: 18, fontWeight: '700' },
  stepSubtitle: { color: '#AAAAAA', fontSize: 12, marginTop: 2 },
  progressDots: { flexDirection: 'row', gap: 6 },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#555555',
  },
  dotCompleted: { backgroundColor: '#4CAF50' },
  dotActive: { backgroundColor: '#CC0000', width: 20 },
  stepContent: { flex: 1 },
  errorContainer: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 },
  errorText: { fontSize: 18, color: '#1A1A1A', marginBottom: 12 },
  errorLink: { color: '#CC0000', fontSize: 15 },
});
