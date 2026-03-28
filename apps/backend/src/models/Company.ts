import mongoose, { Document, Schema } from 'mongoose';

export interface ICompanyDocument extends Document {
  name: string;
  slug: string;
  logoUrl?: string;
  address?: {
    street?: string;
    city?: string;
    state?: string;
    zip?: string;
    country?: string;
  };
  primaryContact?: string;
  isActive: boolean;
  settings: {
    defaultLanguage: string;
    enableBilingual: boolean;
    requireDualApproval: boolean;
    placardSerialPrefix: string;
    defaultTemplateId?: mongoose.Types.ObjectId;
    qrAccessMode: string;
  };
  // Internal counter for generating placard serial numbers per company+site
  placardSequences: Map<string, number>; // key = siteCode, value = last sequence
  createdAt: Date;
  updatedAt: Date;
}

const companySchema = new Schema<ICompanyDocument>(
  {
    name: { type: String, required: true, trim: true },
    slug: { type: String, required: true, unique: true, uppercase: true, trim: true },
    logoUrl: { type: String },
    address: {
      street: String,
      city: String,
      state: String,
      zip: String,
      country: String,
    },
    primaryContact: String,
    isActive: { type: Boolean, default: true, index: true },
    settings: {
      defaultLanguage: { type: String, default: 'en' },
      enableBilingual: { type: Boolean, default: true },
      requireDualApproval: { type: Boolean, default: false },
      placardSerialPrefix: { type: String, default: 'SK' },
      defaultTemplateId: { type: Schema.Types.ObjectId, ref: 'PlacardTemplate' },
      qrAccessMode: {
        type: String,
        enum: ['authenticated', 'tokenized', 'public_readonly'],
        default: 'authenticated',
      },
    },
    placardSequences: {
      type: Map,
      of: Number,
      default: {},
    },
  },
  { timestamps: true }
);

companySchema.index({ slug: 1 });

export const Company = mongoose.model<ICompanyDocument>('Company', companySchema);
