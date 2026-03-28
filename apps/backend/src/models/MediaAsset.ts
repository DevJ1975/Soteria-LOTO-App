import mongoose, { Document, Schema } from 'mongoose';
import { MediaCategory } from '@soteria/shared';

export interface IMediaAssetDocument extends Document {
  companyId: mongoose.Types.ObjectId;
  siteId?: mongoose.Types.ObjectId;
  equipmentId?: mongoose.Types.ObjectId;
  placardId?: mongoose.Types.ObjectId;
  category: MediaCategory;
  filename: string;
  originalFilename: string;
  mimeType: string;
  sizeBytes: number;
  storageKey: string;
  storageProvider: 's3' | 'local';
  publicUrl?: string;
  width?: number;
  height?: number;
  annotations?: Array<{
    id: string;
    x: number;
    y: number;
    label: string;
    color?: string;
  }>;
  caption?: string;
  notes?: string;
  uploadedBy: mongoose.Types.ObjectId;
  uploadedAt: Date;
  createdAt: Date;
}

const mediaAssetSchema = new Schema<IMediaAssetDocument>(
  {
    companyId: { type: Schema.Types.ObjectId, ref: 'Company', required: true, index: true },
    siteId: { type: Schema.Types.ObjectId, ref: 'Site' },
    equipmentId: { type: Schema.Types.ObjectId, ref: 'Equipment', index: true },
    placardId: { type: Schema.Types.ObjectId, ref: 'Placard', index: true },
    category: {
      type: String,
      enum: Object.values(MediaCategory),
      required: true,
    },
    filename: { type: String, required: true },
    originalFilename: { type: String, required: true },
    mimeType: { type: String, required: true },
    sizeBytes: { type: Number, required: true },
    storageKey: { type: String, required: true },
    storageProvider: { type: String, enum: ['s3', 'local'], required: true },
    publicUrl: String,
    width: Number,
    height: Number,
    annotations: [
      {
        id: String,
        x: Number,
        y: Number,
        label: String,
        color: String,
        _id: false,
      },
    ],
    caption: String,
    notes: String,
    uploadedBy: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    uploadedAt: { type: Date, default: Date.now },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

mediaAssetSchema.index({ companyId: 1, category: 1 });

export const MediaAsset = mongoose.model<IMediaAssetDocument>('MediaAsset', mediaAssetSchema);
