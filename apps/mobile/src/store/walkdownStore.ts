// ============================================================
// Walkdown Draft Store — persists field walkdown state locally
// Uses Zustand for in-memory state, AsyncStorage for persistence
// ============================================================

import { create } from 'zustand';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { v4 as uuidv4 } from 'uuid';
import type { EnergySourceType, LockoutDeviceType } from '@soteria/shared';

export interface WalkdownPhoto {
  id: string;
  uri: string;                  // local file URI
  category: string;
  caption?: string;
  uploadedMediaId?: string;     // set after successful upload
}

export interface WalkdownEnergySource {
  id: string;
  type: EnergySourceType;
  description: string;
  voltage?: string;
  pressure?: string;
  location?: string;
}

export interface WalkdownIsolationPoint {
  id: string;
  sequence: number;
  description: string;
  deviceType: LockoutDeviceType;
  location: string;
  normalState?: string;
  isolatedState?: string;
  photoIds: string[];
}

export interface WalkdownDraft {
  id: string;                   // local draft ID
  createdAt: string;
  updatedAt: string;
  currentStep: number;          // wizard step 0-7

  // Step 1 — Site/Equipment selection
  siteId?: string;
  siteName?: string;
  equipmentId?: string;         // DB ID if existing equipment
  equipmentDbId?: string;

  // Step 2 — Machine information
  machineInfo: {
    equipmentId: string;
    commonName: string;
    formalName: string;
    manufacturer?: string;
    model?: string;
    serialNumber?: string;
    location: string;
    department?: string;
    productionLine?: string;
    electricalVoltage?: string;
    pneumaticPressure?: string;
    hydraulicPressure?: string;
    operationalNotes?: string;
  };

  // Step 3 — Photos
  photos: WalkdownPhoto[];

  // Step 4 — Energy sources
  energySources: WalkdownEnergySource[];

  // Step 5 — Isolation points
  isolationPoints: WalkdownIsolationPoint[];

  // Step 6 — Field notes
  fieldNotes?: string;

  // Step 7 — AI draft result
  aiDraft?: Record<string, unknown>;
  aiDraftLogId?: string;

  // Sync status
  serverPlacardId?: string;     // set after sync to server
  syncStatus: 'local' | 'syncing' | 'synced' | 'error';
  syncError?: string;
}

const STORAGE_KEY = 'soteria_walkdown_drafts';

interface WalkdownState {
  drafts: WalkdownDraft[];
  activeDraftId: string | null;

  // Draft management
  createDraft: () => string;
  setActiveDraft: (id: string) => void;
  updateDraft: (id: string, updates: Partial<WalkdownDraft>) => void;
  deleteDraft: (id: string) => void;
  getActiveDraft: () => WalkdownDraft | undefined;

  // Photos
  addPhoto: (draftId: string, photo: Omit<WalkdownPhoto, 'id'>) => string;
  removePhoto: (draftId: string, photoId: string) => void;
  markPhotoUploaded: (draftId: string, photoId: string, mediaId: string) => void;

  // Persistence
  loadFromStorage: () => Promise<void>;
  saveToStorage: () => Promise<void>;
}

export const useWalkdownStore = create<WalkdownState>((set, get) => ({
  drafts: [],
  activeDraftId: null,

  createDraft: () => {
    const id = uuidv4();
    const draft: WalkdownDraft = {
      id,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      currentStep: 0,
      machineInfo: {
        equipmentId: '',
        commonName: '',
        formalName: '',
        location: '',
      },
      photos: [],
      energySources: [],
      isolationPoints: [],
      syncStatus: 'local',
    };

    set((state) => ({ drafts: [...state.drafts, draft], activeDraftId: id }));
    get().saveToStorage();
    return id;
  },

  setActiveDraft: (id) => set({ activeDraftId: id }),

  updateDraft: (id, updates) => {
    set((state) => ({
      drafts: state.drafts.map((d) =>
        d.id === id ? { ...d, ...updates, updatedAt: new Date().toISOString() } : d
      ),
    }));
    get().saveToStorage();
  },

  deleteDraft: (id) => {
    set((state) => ({
      drafts: state.drafts.filter((d) => d.id !== id),
      activeDraftId: state.activeDraftId === id ? null : state.activeDraftId,
    }));
    get().saveToStorage();
  },

  getActiveDraft: () => {
    const { drafts, activeDraftId } = get();
    return drafts.find((d) => d.id === activeDraftId);
  },

  addPhoto: (draftId, photo) => {
    const id = uuidv4();
    set((state) => ({
      drafts: state.drafts.map((d) =>
        d.id === draftId
          ? { ...d, photos: [...d.photos, { ...photo, id }], updatedAt: new Date().toISOString() }
          : d
      ),
    }));
    get().saveToStorage();
    return id;
  },

  removePhoto: (draftId, photoId) => {
    set((state) => ({
      drafts: state.drafts.map((d) =>
        d.id === draftId
          ? { ...d, photos: d.photos.filter((p) => p.id !== photoId) }
          : d
      ),
    }));
    get().saveToStorage();
  },

  markPhotoUploaded: (draftId, photoId, mediaId) => {
    set((state) => ({
      drafts: state.drafts.map((d) =>
        d.id === draftId
          ? {
              ...d,
              photos: d.photos.map((p) =>
                p.id === photoId ? { ...p, uploadedMediaId: mediaId } : p
              ),
            }
          : d
      ),
    }));
    get().saveToStorage();
  },

  loadFromStorage: async () => {
    try {
      const raw = await AsyncStorage.getItem(STORAGE_KEY);
      if (raw) {
        const drafts = JSON.parse(raw) as WalkdownDraft[];
        set({ drafts });
      }
    } catch {
      // Storage read failed — start fresh
    }
  },

  saveToStorage: async () => {
    try {
      const { drafts } = get();
      await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(drafts));
    } catch {
      // Non-critical — local save failed
    }
  },
}));
