import { EnergySourceType } from './enums';

// ============================================================
// AI Draft Generation — Input and Output types
// ============================================================

export interface IAIDraftInput {
  // Equipment context
  machineInfo: {
    commonName: string;
    formalName?: string;
    manufacturer?: string;
    model?: string;
    serialNumber?: string;
    location: string;
    electricalVoltage?: string;
    pneumaticPressure?: string;
    hydraulicPressure?: string;
    operationalNotes?: string;
  };

  // User-selected energy sources
  selectedEnergySources: EnergySourceType[];

  // User notes from field walkdown
  fieldNotes?: string;

  // Isolation point descriptions (user-entered)
  isolationPointNotes?: string[];

  // OCR data from nameplate if available
  nameplateOcrText?: string;

  // Photo descriptions if analyzed
  photoDescriptions?: string[];

  // Company/site context
  facilityType?: string;       // e.g. "food manufacturing"
}

export interface IAIDraftOutput {
  // Machine summary
  machineSummary: string;

  // Energy sources identified / confirmed
  energySources: IAIEnergySource[];

  // Proposed isolation points
  isolationPoints: IAIIsolationPoint[];

  // Procedure steps by phase
  shutdownSteps: IAIProcedureStep[];
  isolationSteps: IAIProcedureStep[];
  lockoutSteps: IAIProcedureStep[];
  storedEnergySteps: IAIProcedureStep[];
  verificationSteps: IAIProcedureStep[];
  restartSteps: IAIProcedureStep[];

  // Warnings and cautions
  warnings: string[];
  specialCautions: string[];
  requiredPPE: string[];

  // AI quality metadata
  assumptions: string[];
  missingInfoFlags: string[];
  reviewRequired: string[];
  confidenceScore: number;     // 0-1
  confidenceNotes: string;
}

export interface IAIEnergySource {
  type: EnergySourceType;
  description: string;
  location?: string;
  magnitude?: string;
  aiGenerated: boolean;
}

export interface IAIIsolationPoint {
  sequence: number;
  description: string;
  deviceType: string;
  location: string;
  normalState?: string;
  isolatedState?: string;
  aiGenerated: boolean;
}

export interface IAIProcedureStep {
  sequence: number;
  instruction: string;
  warnings?: string[];
  aiGenerated: boolean;
}

export interface IAIGenerationLog {
  _id: string;
  companyId: string;
  placardId?: string;
  userId: string;
  input: IAIDraftInput;
  output: IAIDraftOutput;
  modelUsed: string;
  promptTokens: number;
  completionTokens: number;
  durationMs: number;
  createdAt: Date;
}
