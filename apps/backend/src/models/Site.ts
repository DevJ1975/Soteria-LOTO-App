import mongoose, { Document, Schema } from 'mongoose';

export interface ISiteDocument extends Document {
  companyId: mongoose.Types.ObjectId;
  name: string;
  code: string;
  address?: {
    street?: string;
    city?: string;
    state?: string;
    zip?: string;
  };
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const siteSchema = new Schema<ISiteDocument>(
  {
    companyId: { type: Schema.Types.ObjectId, ref: 'Company', required: true, index: true },
    name: { type: String, required: true, trim: true },
    code: { type: String, required: true, uppercase: true, trim: true },
    address: {
      street: String,
      city: String,
      state: String,
      zip: String,
    },
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true }
);

siteSchema.index({ companyId: 1, code: 1 }, { unique: true });
siteSchema.index({ companyId: 1, isActive: 1 });

export const Site = mongoose.model<ISiteDocument>('Site', siteSchema);

// ─── Department ──────────────────────────────────────────────
export interface IDepartmentDocument extends Document {
  siteId: mongoose.Types.ObjectId;
  companyId: mongoose.Types.ObjectId;
  name: string;
  code: string;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const departmentSchema = new Schema<IDepartmentDocument>(
  {
    siteId: { type: Schema.Types.ObjectId, ref: 'Site', required: true, index: true },
    companyId: { type: Schema.Types.ObjectId, ref: 'Company', required: true, index: true },
    name: { type: String, required: true, trim: true },
    code: { type: String, required: true, uppercase: true, trim: true },
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true }
);

departmentSchema.index({ siteId: 1, code: 1 }, { unique: true });

export const Department = mongoose.model<IDepartmentDocument>('Department', departmentSchema);
