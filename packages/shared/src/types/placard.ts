import { EnergySourceType, LockoutDeviceType, PlacardStatus } from './enums';

// ============================================================
// Energy Source — describes one hazardous energy source
// ============================================================
export interface IEnergySource {
  id: string;
  type: EnergySourceType;
  description: string;         // e.g. "480V 3-Phase Motor Feed"
  location?: string;           // physical location of source
  voltage?: string;
  pressure?: string;
  magnitude?: string;          // for other types
  isolationPointId?: string;   // reference to isolation point
}

// ============================================================
// Isolation Point — describes one lockout/tagout point
// ============================================================
export interface IIsolationPoint {
  id: string;
  sequence: number;
  energySourceIds: string[];   // which energy sources this isolates
  description: string;         // e.g. "Disconnect D-47 on Panel LP-3"
  deviceType: LockoutDeviceType;
  location: string;
  normalState?: string;         // e.g. "CLOSED", "ENERGIZED"
  isolatedState?: string;       // e.g. "OPEN", "DE-ENERGIZED"
  photoIds: string[];
  notes?: string;
}

// ============================================================
// Procedure Step — one action step in the LOTO procedure
// ============================================================
export interface IProcedureStep {
  id: string;
  sequence: number;
  phase: ProcedurePhase;
  instruction: string;         // English instruction text
  instructionEs?: string;      // Spanish translation
  warnings?: string[];
  isolationPointId?: string;   // linked isolation point if applicable
  photoIds: string[];
  isRequired: boolean;
  notes?: string;
}

export enum ProcedurePhase {
  SHUTDOWN = 'shutdown',
  ISOLATION = 'isolation',
  LOCKOUT = 'lockout',
  STORED_ENERGY_RELEASE = 'stored_energy_release',
  VERIFICATION = 'verification',
  RESTART = 'restart',
}

// ============================================================
// Placard — the core domain entity
// ============================================================
export interface IPlacard {
  _id: string;
  companyId: string;
  siteId: string;

  // Serialized identifier
  placardNumber: string;        // e.g. "SK-COI-LOTO-000042"
  revisionNumber: number;       // 1, 2, 3...
  revisionDate: Date;

  // Equipment linkage
  equipmentId?: string;

  // Machine information
  machineInfo: IMachineInfo;

  // Core procedure content
  energySources: IEnergySource[];
  isolationPoints: IIsolationPoint[];
  procedureSteps: IProcedureStep[];

  // Special notes
  warnings: string[];
  specialCautions: string[];
  requiredPPE: string[];

  // Personnel / approvals
  authorId: string;
  reviewerId?: string;
  approverId?: string;
  reviewDate?: Date;
  approvalDate?: Date;

  // Change control
  changeDescription?: string;
  previousRevisionId?: string;

  status: PlacardStatus;

  // Template used for rendering
  templateId: string;

  // Linked media
  mediaIds: string[];

  // Linked translations
  spanishRevisionId?: string;   // ID of the Spanish version placard

  // QR
  qrToken?: string;

  // AI generation metadata
  aiDraftId?: string;
  wasAIAssisted: boolean;

  createdAt: Date;
  updatedAt: Date;
}

export interface IMachineInfo {
  equipmentId: string;          // internal display ID / asset tag
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
}

export type CreatePlacardDto = Omit<IPlacard, '_id' | 'createdAt' | 'updatedAt' | 'placardNumber' | 'qrToken' | 'revisionNumber'>;
export type UpdatePlacardDto = Partial<Omit<IPlacard, '_id' | 'companyId' | 'placardNumber' | 'createdAt'>>;
