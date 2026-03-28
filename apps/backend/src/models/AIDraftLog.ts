import mongoose, { Document, Schema } from 'mongoose';

export interface IAIDraftLogDocument extends Document {
  companyId: mongoose.Types.ObjectId;
  placardId?: mongoose.Types.ObjectId;
  userId: mongoose.Types.ObjectId;
  input: Record<string, unknown>;
  output: Record<string, unknown>;
  modelUsed: string;
  promptTokens: number;
  completionTokens: number;
  durationMs: number;
  createdAt: Date;
}

const aiDraftLogSchema = new Schema<IAIDraftLogDocument>(
  {
    companyId: { type: Schema.Types.ObjectId, ref: 'Company', required: true, index: true },
    placardId: { type: Schema.Types.ObjectId, ref: 'Placard' },
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    input: { type: Schema.Types.Mixed, required: true },
    output: { type: Schema.Types.Mixed, required: true },
    modelUsed: { type: String, required: true },
    promptTokens: { type: Number, default: 0 },
    completionTokens: { type: Number, default: 0 },
    durationMs: { type: Number, default: 0 },
  },
  {
    timestamps: { createdAt: true, updatedAt: false },
  }
);

aiDraftLogSchema.index({ companyId: 1, createdAt: -1 });

export const AIDraftLog = mongoose.model<IAIDraftLogDocument>('AIDraftLog', aiDraftLogSchema);
