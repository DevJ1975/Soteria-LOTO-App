import mongoose, { Document, Schema } from 'mongoose';
import { EquipmentStatus } from '@soteria/shared';

export interface IEquipmentDocument extends Document {
  companyId: mongoose.Types.ObjectId;
  siteId: mongoose.Types.ObjectId;
  departmentId?: mongoose.Types.ObjectId;
  productionLineId?: mongoose.Types.ObjectId;
  equipmentId: string;
  commonName: string;
  formalName: string;
  category: string;
  manufacturer?: string;
  model?: string;
  serialNumber?: string;
  yearManufactured?: number;
  electricalVoltage?: string;
  electricalAmps?: string;
  pneumaticPressure?: string;
  hydraulicPressure?: string;
  operationalNotes?: string;
  location?: string;
  status: EquipmentStatus;
  currentPlacardId?: mongoose.Types.ObjectId;
  placardIds: mongoose.Types.ObjectId[];
  primaryPhotoUrl?: string;
  createdBy: mongoose.Types.ObjectId;
  createdAt: Date;
  updatedAt: Date;
}

const equipmentSchema = new Schema<IEquipmentDocument>(
  {
    companyId: { type: Schema.Types.ObjectId, ref: 'Company', required: true, index: true },
    siteId: { type: Schema.Types.ObjectId, ref: 'Site', required: true, index: true },
    departmentId: { type: Schema.Types.ObjectId, ref: 'Department' },
    productionLineId: { type: Schema.Types.ObjectId, ref: 'ProductionLine' },
    equipmentId: { type: String, required: true, trim: true },
    commonName: { type: String, required: true, trim: true },
    formalName: { type: String, required: true, trim: true },
    category: { type: String, required: true, trim: true },
    manufacturer: String,
    model: String,
    serialNumber: String,
    yearManufactured: Number,
    electricalVoltage: String,
    electricalAmps: String,
    pneumaticPressure: String,
    hydraulicPressure: String,
    operationalNotes: String,
    location: String,
    status: {
      type: String,
      enum: Object.values(EquipmentStatus),
      default: EquipmentStatus.ACTIVE,
      index: true,
    },
    currentPlacardId: { type: Schema.Types.ObjectId, ref: 'Placard' },
    placardIds: [{ type: Schema.Types.ObjectId, ref: 'Placard' }],
    primaryPhotoUrl: String,
    createdBy: { type: Schema.Types.ObjectId, ref: 'User', required: true },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
  }
);

// Compound uniqueness: equipment ID is unique within a site
equipmentSchema.index({ siteId: 1, equipmentId: 1 }, { unique: true });
equipmentSchema.index({ companyId: 1, status: 1 });
// Text search
equipmentSchema.index({ commonName: 'text', formalName: 'text', equipmentId: 'text' });

export const Equipment = mongoose.model<IEquipmentDocument>('Equipment', equipmentSchema);
