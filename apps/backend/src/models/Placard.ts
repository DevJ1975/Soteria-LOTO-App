import mongoose, { Document, Schema } from 'mongoose';
import { PlacardStatus, EnergySourceType, LockoutDeviceType, ProcedurePhase } from '@soteria/shared';

// ─── Sub-document schemas ─────────────────────────────────────

const energySourceSchema = new Schema(
  {
    id: { type: String, required: true },
    type: { type: String, enum: Object.values(EnergySourceType), required: true },
    description: { type: String, required: true },
    location: String,
    voltage: String,
    pressure: String,
    magnitude: String,
    isolationPointId: String,
  },
  { _id: false }
);

const isolationPointSchema = new Schema(
  {
    id: { type: String, required: true },
    sequence: { type: Number, required: true },
    energySourceIds: [String],
    description: { type: String, required: true },
    deviceType: { type: String, enum: Object.values(LockoutDeviceType), required: true },
    location: { type: String, required: true },
    normalState: String,
    isolatedState: String,
    photoIds: [String],
    notes: String,
  },
  { _id: false }
);

const procedureStepSchema = new Schema(
  {
    id: { type: String, required: true },
    sequence: { type: Number, required: true },
    phase: { type: String, enum: Object.values(ProcedurePhase), required: true },
    instruction: { type: String, required: true },
    instructionEs: String,
    warnings: [String],
    isolationPointId: String,
    photoIds: [String],
    isRequired: { type: Boolean, default: true },
    notes: String,
  },
  { _id: false }
);

const machineInfoSchema = new Schema(
  {
    equipmentId: { type: String, required: true },
    commonName: { type: String, required: true },
    formalName: { type: String, required: true },
    manufacturer: String,
    model: String,
    serialNumber: String,
    location: { type: String, required: true },
    department: String,
    productionLine: String,
    electricalVoltage: String,
    pneumaticPressure: String,
    hydraulicPressure: String,
    operationalNotes: String,
  },
  { _id: false }
);

// ─── Main Placard document ────────────────────────────────────

export interface IPlacardDocument extends Document {
  companyId: mongoose.Types.ObjectId;
  siteId: mongoose.Types.ObjectId;
  placardNumber: string;
  revisionNumber: number;
  revisionDate: Date;
  equipmentId?: mongoose.Types.ObjectId;
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
  energySources: mongoose.Types.DocumentArray<mongoose.Document>;
  isolationPoints: mongoose.Types.DocumentArray<mongoose.Document>;
  procedureSteps: mongoose.Types.DocumentArray<mongoose.Document>;
  warnings: string[];
  specialCautions: string[];
  requiredPPE: string[];
  authorId: mongoose.Types.ObjectId;
  reviewerId?: mongoose.Types.ObjectId;
  approverId?: mongoose.Types.ObjectId;
  reviewDate?: Date;
  approvalDate?: Date;
  changeDescription?: string;
  previousRevisionId?: mongoose.Types.ObjectId;
  status: PlacardStatus;
  templateId: mongoose.Types.ObjectId;
  mediaIds: mongoose.Types.ObjectId[];
  spanishRevisionId?: mongoose.Types.ObjectId;
  qrToken?: string;
  aiDraftId?: mongoose.Types.ObjectId;
  wasAIAssisted: boolean;
  language: string;
  createdAt: Date;
  updatedAt: Date;
}

const placardSchema = new Schema<IPlacardDocument>(
  {
    companyId: { type: Schema.Types.ObjectId, ref: 'Company', required: true, index: true },
    siteId: { type: Schema.Types.ObjectId, ref: 'Site', required: true, index: true },
    placardNumber: { type: String, required: true, index: true },
    revisionNumber: { type: Number, required: true, default: 1 },
    revisionDate: { type: Date, required: true, default: Date.now },
    equipmentId: { type: Schema.Types.ObjectId, ref: 'Equipment' },
    machineInfo: { type: machineInfoSchema, required: true },
    energySources: { type: [energySourceSchema], default: [] },
    isolationPoints: { type: [isolationPointSchema], default: [] },
    procedureSteps: { type: [procedureStepSchema], default: [] },
    warnings: { type: [String], default: [] },
    specialCautions: { type: [String], default: [] },
    requiredPPE: { type: [String], default: [] },
    authorId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    reviewerId: { type: Schema.Types.ObjectId, ref: 'User' },
    approverId: { type: Schema.Types.ObjectId, ref: 'User' },
    reviewDate: Date,
    approvalDate: Date,
    changeDescription: String,
    previousRevisionId: { type: Schema.Types.ObjectId, ref: 'Placard' },
    status: {
      type: String,
      enum: Object.values(PlacardStatus),
      default: PlacardStatus.DRAFT,
      index: true,
    },
    templateId: { type: Schema.Types.ObjectId, ref: 'PlacardTemplate' },
    mediaIds: [{ type: Schema.Types.ObjectId, ref: 'MediaAsset' }],
    spanishRevisionId: { type: Schema.Types.ObjectId, ref: 'Placard' },
    qrToken: { type: String, unique: true, sparse: true, index: true },
    aiDraftId: { type: Schema.Types.ObjectId, ref: 'AIDraftLog' },
    wasAIAssisted: { type: Boolean, default: false },
    language: { type: String, default: 'en', enum: ['en', 'es'] },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
  }
);

// Unique placard number within a company
placardSchema.index({ companyId: 1, placardNumber: 1, revisionNumber: 1 }, { unique: true });
placardSchema.index({ companyId: 1, status: 1 });
placardSchema.index({ equipmentId: 1, status: 1 });
// Full text search
placardSchema.index({
  placardNumber: 'text',
  'machineInfo.commonName': 'text',
  'machineInfo.formalName': 'text',
  'machineInfo.equipmentId': 'text',
});

export const Placard = mongoose.model<IPlacardDocument>('Placard', placardSchema);
