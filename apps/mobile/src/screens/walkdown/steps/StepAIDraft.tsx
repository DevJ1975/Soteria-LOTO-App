// ============================================================
// Step 6 — AI Draft Generation & Review
// Field user triggers AI, sees flags, edits steps before saving
// ============================================================

import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { useWalkdownStore } from '../../../store/walkdownStore';
import type { WalkdownDraft } from '../../../store/walkdownStore';
import { apiClient } from '../../../config/api';

interface Props {
  draft: WalkdownDraft;
  onNext: () => void;
}

export function StepAIDraft({ draft, onNext }: Props) {
  const updateDraft = useWalkdownStore((s) => s.updateDraft);
  const [loading, setLoading] = useState(false);
  const aiDraft = draft.aiDraft as Record<string, unknown> | undefined;

  const generateDraft = async () => {
    setLoading(true);
    try {
      const input = {
        machineInfo: draft.machineInfo,
        selectedEnergySources: draft.energySources.map((s) => s.type),
        fieldNotes: draft.fieldNotes,
        isolationPointNotes: draft.isolationPoints.map((p) => p.description),
        facilityType: 'food manufacturing',
      };

      const { data } = await apiClient.post('/ai/draft', input);
      updateDraft(draft.id, {
        aiDraft: data.data,
        aiDraftLogId: data.data?.logId,
      });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'AI draft failed';
      Alert.alert('AI Unavailable', `${message}\n\nYou can proceed with manual entry.`);
    } finally {
      setLoading(false);
    }
  };

  if (!aiDraft) {
    return (
      <View style={styles.container}>
        <View style={styles.aiInfoBox}>
          <Text style={styles.aiInfoTitle}>AI-Assisted Draft Generation</Text>
          <Text style={styles.aiInfoText}>
            Claude will analyze your equipment information and generate a draft LOTO procedure.
            {'\n\n'}
            This is a DRAFT only — it must be reviewed and approved by a qualified EHS professional
            before use. All AI-generated content will be flagged for your review.
          </Text>
        </View>

        <View style={styles.inputSummary}>
          <Text style={styles.summaryTitle}>USING YOUR FIELD DATA:</Text>
          <SummaryRow label="Machine" value={draft.machineInfo.commonName || 'Not entered'} />
          <SummaryRow label="Location" value={draft.machineInfo.location || 'Not entered'} />
          <SummaryRow
            label="Energy Sources"
            value={`${draft.energySources.length} identified`}
          />
          <SummaryRow
            label="Isolation Points"
            value={`${draft.isolationPoints.length} documented`}
          />
        </View>

        <TouchableOpacity
          style={[styles.generateBtn, loading && styles.generateBtnLoading]}
          onPress={generateDraft}
          disabled={loading}
        >
          {loading ? (
            <View style={styles.loadingRow}>
              <ActivityIndicator color="#FFF" style={{ marginRight: 10 }} />
              <Text style={styles.generateBtnText}>Generating draft...</Text>
            </View>
          ) : (
            <Text style={styles.generateBtnText}>⚡ GENERATE AI DRAFT</Text>
          )}
        </TouchableOpacity>

        <TouchableOpacity style={styles.skipBtn} onPress={onNext}>
          <Text style={styles.skipBtnText}>Skip — proceed with manual entry</Text>
        </TouchableOpacity>
      </View>
    );
  }

  // Show AI draft results
  const confidence = (aiDraft.confidenceScore as number ?? 0) * 100;
  const flags = [
    ...((aiDraft.assumptions as string[]) ?? []),
    ...((aiDraft.missingInfoFlags as string[]) ?? []),
    ...((aiDraft.reviewRequired as string[]) ?? []),
  ];

  return (
    <ScrollView style={styles.container}>
      {/* Confidence indicator */}
      <View style={[
        styles.confidenceBar,
        confidence >= 70 ? styles.confHigh : confidence >= 40 ? styles.confMed : styles.confLow,
      ]}>
        <Text style={styles.confidenceText}>
          AI CONFIDENCE: {confidence.toFixed(0)}%
          {confidence < 50 ? ' — SIGNIFICANT REVIEW REQUIRED' : ''}
        </Text>
      </View>

      {/* Flags that require review */}
      {flags.length > 0 && (
        <View style={styles.flagsBox}>
          <Text style={styles.flagsTitle}>⚠ {flags.length} ITEMS REQUIRE YOUR REVIEW</Text>
          {flags.map((flag, i) => (
            <Text key={i} style={styles.flagItem}>• {flag}</Text>
          ))}
        </View>
      )}

      {/* Generated steps summary */}
      <Text style={styles.sectionTitle}>GENERATED PROCEDURE STEPS</Text>
      <PhaseBlock
        label="Shutdown"
        steps={(aiDraft.shutdownSteps as Array<{ sequence: number; instruction: string }>) ?? []}
      />
      <PhaseBlock
        label="Isolation"
        steps={(aiDraft.isolationSteps as Array<{ sequence: number; instruction: string }>) ?? []}
      />
      <PhaseBlock
        label="Lockout"
        steps={(aiDraft.lockoutSteps as Array<{ sequence: number; instruction: string }>) ?? []}
      />
      <PhaseBlock
        label="Stored Energy Release"
        steps={(aiDraft.storedEnergySteps as Array<{ sequence: number; instruction: string }>) ?? []}
      />
      <PhaseBlock
        label="Verification"
        steps={(aiDraft.verificationSteps as Array<{ sequence: number; instruction: string }>) ?? []}
      />
      <PhaseBlock
        label="Return to Service"
        steps={(aiDraft.restartSteps as Array<{ sequence: number; instruction: string }>) ?? []}
      />

      <View style={styles.actions}>
        <TouchableOpacity
          style={styles.regenerateBtn}
          onPress={() => { updateDraft(draft.id, { aiDraft: undefined }); }}
        >
          <Text style={styles.regenerateBtnText}>Regenerate</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.acceptBtn} onPress={onNext}>
          <Text style={styles.acceptBtnText}>ACCEPT DRAFT & CONTINUE →</Text>
        </TouchableOpacity>
      </View>

      <Text style={styles.disclaimer}>
        AI-generated content must be reviewed and approved by a qualified EHS professional before
        this placard is used for lockout/tagout operations.
      </Text>
    </ScrollView>
  );
}

function SummaryRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.summaryRow}>
      <Text style={styles.summaryLabel}>{label}:</Text>
      <Text style={styles.summaryValue}>{value}</Text>
    </View>
  );
}

function PhaseBlock({ label, steps }: { label: string; steps: Array<{ sequence: number; instruction: string }> }) {
  if (!steps.length) return null;
  return (
    <View style={styles.phaseBlock}>
      <View style={styles.phaseHeader}>
        <Text style={styles.phaseLabel}>{label.toUpperCase()}</Text>
      </View>
      {steps.map((step) => (
        <View key={step.sequence} style={styles.stepRow}>
          <View style={styles.stepNum}><Text style={styles.stepNumText}>{step.sequence}</Text></View>
          <Text style={styles.stepInstruction}>{step.instruction}</Text>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 16 },
  aiInfoBox: {
    backgroundColor: '#E3F2FD',
    borderLeftWidth: 4,
    borderLeftColor: '#1976D2',
    padding: 14,
    borderRadius: 4,
    marginBottom: 16,
  },
  aiInfoTitle: { fontWeight: '700', fontSize: 14, color: '#1565C0', marginBottom: 6 },
  aiInfoText: { fontSize: 13, color: '#1A1A1A', lineHeight: 18 },
  inputSummary: {
    backgroundColor: '#FFF',
    borderRadius: 8,
    padding: 14,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  summaryTitle: { fontSize: 10, fontWeight: '700', color: '#888', letterSpacing: 1, marginBottom: 8 },
  summaryRow: { flexDirection: 'row', marginBottom: 6 },
  summaryLabel: { fontSize: 12, fontWeight: '600', color: '#555', width: 110 },
  summaryValue: { fontSize: 12, color: '#1A1A1A', flex: 1 },
  generateBtn: {
    backgroundColor: '#CC0000',
    borderRadius: 8,
    padding: 18,
    alignItems: 'center',
    marginBottom: 12,
    minHeight: 58,
  },
  generateBtnLoading: { backgroundColor: '#E57373' },
  generateBtnText: { color: '#FFF', fontWeight: '700', fontSize: 15, letterSpacing: 1 },
  loadingRow: { flexDirection: 'row', alignItems: 'center' },
  skipBtn: { padding: 12, alignItems: 'center' },
  skipBtnText: { color: '#666', fontSize: 13 },
  // Results
  confidenceBar: { padding: 10, borderRadius: 4, marginBottom: 12, alignItems: 'center' },
  confHigh: { backgroundColor: '#E8F5E9' },
  confMed: { backgroundColor: '#FFF3CD' },
  confLow: { backgroundColor: '#FFEBEE' },
  confidenceText: { fontWeight: '700', fontSize: 12, color: '#1A1A1A' },
  flagsBox: {
    backgroundColor: '#FFF3CD',
    borderLeftWidth: 4,
    borderLeftColor: '#CC0000',
    padding: 12,
    marginBottom: 16,
    borderRadius: 4,
  },
  flagsTitle: { fontWeight: '700', fontSize: 12, color: '#CC0000', marginBottom: 8 },
  flagItem: { fontSize: 12, color: '#555', marginBottom: 4 },
  sectionTitle: { fontSize: 10, fontWeight: '700', color: '#888', letterSpacing: 1.5, marginBottom: 10 },
  phaseBlock: { marginBottom: 10 },
  phaseHeader: { backgroundColor: '#333', padding: 8, borderRadius: 4, marginBottom: 4 },
  phaseLabel: { color: '#FFF', fontWeight: '700', fontSize: 10, letterSpacing: 1 },
  stepRow: { flexDirection: 'row', alignItems: 'flex-start', backgroundColor: '#FFF', padding: 8, marginBottom: 2, borderRadius: 4 },
  stepNum: { width: 24, height: 24, borderRadius: 12, backgroundColor: '#CC0000', alignItems: 'center', justifyContent: 'center', marginRight: 8 },
  stepNumText: { color: '#FFF', fontWeight: '700', fontSize: 10 },
  stepInstruction: { flex: 1, fontSize: 12, color: '#1A1A1A' },
  actions: { flexDirection: 'row', gap: 10, marginTop: 10, marginBottom: 4 },
  regenerateBtn: { flex: 1, backgroundColor: '#FFF', borderWidth: 1.5, borderColor: '#CC0000', borderRadius: 8, padding: 14, alignItems: 'center' },
  regenerateBtnText: { color: '#CC0000', fontWeight: '600', fontSize: 13 },
  acceptBtn: { flex: 2, backgroundColor: '#1A1A1A', borderRadius: 8, padding: 14, alignItems: 'center' },
  acceptBtnText: { color: '#FFF', fontWeight: '700', fontSize: 12, letterSpacing: 0.5 },
  disclaimer: { fontSize: 9, color: '#AAA', textAlign: 'center', marginTop: 8, marginBottom: 20 },
});
