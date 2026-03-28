// ============================================================
// Offline Sync Service
// Handles queued photo uploads and placard draft sync
// when network connectivity is restored.
// ============================================================

import NetInfo from '@react-native-community/netinfo';
import * as FileSystem from 'expo-file-system';
import { apiClient } from '../config/api';
import { useWalkdownStore } from '../store/walkdownStore';
import type { WalkdownDraft } from '../store/walkdownStore';
import { MediaCategory } from '@soteria/shared';

export class SyncService {
  private static isSyncing = false;

  /**
   * Attempt to sync all local drafts that have not been synced.
   * Call this when network becomes available.
   */
  static async syncPendingDrafts(): Promise<void> {
    if (SyncService.isSyncing) return;

    const netState = await NetInfo.fetch();
    if (!netState.isConnected) return;

    SyncService.isSyncing = true;
    const store = useWalkdownStore.getState();

    for (const draft of store.drafts) {
      if (draft.syncStatus === 'synced') continue;

      try {
        store.updateDraft(draft.id, { syncStatus: 'syncing' });

        // Step 1: Upload pending photos
        await SyncService.uploadPendingPhotos(draft);

        // Step 2: Create or update placard on server
        if (!draft.serverPlacardId) {
          await SyncService.createPlacardFromDraft(draft);
        } else {
          await SyncService.updatePlacardFromDraft(draft);
        }

        store.updateDraft(draft.id, { syncStatus: 'synced', syncError: undefined });
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : 'Sync failed';
        store.updateDraft(draft.id, { syncStatus: 'error', syncError: message });
      }
    }

    SyncService.isSyncing = false;
  }

  private static async uploadPendingPhotos(draft: WalkdownDraft): Promise<void> {
    const store = useWalkdownStore.getState();

    for (const photo of draft.photos) {
      if (photo.uploadedMediaId) continue; // already uploaded

      const formData = new FormData();
      formData.append('file', {
        uri: photo.uri,
        name: `photo_${photo.id}.jpg`,
        type: 'image/jpeg',
      } as unknown as Blob);
      formData.append('category', photo.category || MediaCategory.REFERENCE);
      if (draft.siteId) formData.append('siteId', draft.siteId);
      if (draft.equipmentDbId) formData.append('equipmentId', draft.equipmentDbId);

      const { data } = await apiClient.post('/media/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });

      store.markPhotoUploaded(draft.id, photo.id, data.data._id);
    }
  }

  private static async createPlacardFromDraft(draft: WalkdownDraft): Promise<void> {
    const store = useWalkdownStore.getState();

    // Build media IDs from uploaded photos
    const mediaIds = draft.photos
      .filter((p) => p.uploadedMediaId)
      .map((p) => p.uploadedMediaId);

    const payload = {
      siteId: draft.siteId,
      equipmentId: draft.equipmentDbId,
      machineInfo: draft.machineInfo,
      energySources: draft.energySources.map((s) => ({
        id: s.id,
        type: s.type,
        description: s.description,
        voltage: s.voltage,
        pressure: s.pressure,
        location: s.location,
      })),
      isolationPoints: draft.isolationPoints,
      procedureSteps: [],          // Will be populated from AI draft
      warnings: [],
      specialCautions: [],
      requiredPPE: [],
      mediaIds,
      wasAIAssisted: !!draft.aiDraft,
      aiDraftId: draft.aiDraftLogId,
    };

    const { data } = await apiClient.post('/placards', payload);
    store.updateDraft(draft.id, { serverPlacardId: data.data._id });
  }

  private static async updatePlacardFromDraft(draft: WalkdownDraft): Promise<void> {
    if (!draft.serverPlacardId) return;

    const mediaIds = draft.photos
      .filter((p) => p.uploadedMediaId)
      .map((p) => p.uploadedMediaId);

    await apiClient.put(`/placards/${draft.serverPlacardId}`, {
      machineInfo: draft.machineInfo,
      energySources: draft.energySources,
      isolationPoints: draft.isolationPoints,
      mediaIds,
    });
  }

  /**
   * Set up a network listener to auto-sync when connection is restored.
   */
  static startBackgroundSync(): () => void {
    return NetInfo.addEventListener((state) => {
      if (state.isConnected && state.isInternetReachable) {
        SyncService.syncPendingDrafts().catch(console.warn);
      }
    });
  }
}
