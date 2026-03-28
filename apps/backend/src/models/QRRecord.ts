import mongoose, { Document, Schema } from 'mongoose';

export interface IQRRecordDocument extends Document {
  token: string;
  placardId: mongoose.Types.ObjectId;
  companyId: mongoose.Types.ObjectId;
  isActive: boolean;
  scanCount: number;
  lastScannedAt?: Date;
  lastScannedBy?: mongoose.Types.ObjectId;
  createdAt: Date;
  updatedAt: Date;
}

const qrRecordSchema = new Schema<IQRRecordDocument>(
  {
    token: { type: String, required: true, unique: true, index: true },
    placardId: { type: Schema.Types.ObjectId, ref: 'Placard', required: true, index: true },
    companyId: { type: Schema.Types.ObjectId, ref: 'Company', required: true, index: true },
    isActive: { type: Boolean, default: true, index: true },
    scanCount: { type: Number, default: 0 },
    lastScannedAt: Date,
    lastScannedBy: { type: Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true }
);

export const QRRecord = mongoose.model<IQRRecordDocument>('QRRecord', qrRecordSchema);
