import mongoose, { Document, Schema } from 'mongoose';

export interface IRevisionRecordDocument extends Document {
  placardId: mongoose.Types.ObjectId;
  companyId: mongoose.Types.ObjectId;
  revisionNumber: number;
  revisionDate: Date;
  changeDescription: string;
  changedById: mongoose.Types.ObjectId;
  snapshot: Record<string, unknown>;
  authorId: mongoose.Types.ObjectId;
  reviewerId?: mongoose.Types.ObjectId;
  approverId?: mongoose.Types.ObjectId;
  reviewDate?: Date;
  approvalDate?: Date;
  createdAt: Date;
}

const revisionRecordSchema = new Schema<IRevisionRecordDocument>(
  {
    placardId: { type: Schema.Types.ObjectId, ref: 'Placard', required: true, index: true },
    companyId: { type: Schema.Types.ObjectId, ref: 'Company', required: true, index: true },
    revisionNumber: { type: Number, required: true },
    revisionDate: { type: Date, required: true },
    changeDescription: { type: String, required: true },
    changedById: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    snapshot: { type: Schema.Types.Mixed, required: true },
    authorId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    reviewerId: { type: Schema.Types.ObjectId, ref: 'User' },
    approverId: { type: Schema.Types.ObjectId, ref: 'User' },
    reviewDate: Date,
    approvalDate: Date,
  },
  {
    timestamps: { createdAt: true, updatedAt: false },
  }
);

revisionRecordSchema.index({ placardId: 1, revisionNumber: 1 }, { unique: true });

export const RevisionRecord = mongoose.model<IRevisionRecordDocument>(
  'RevisionRecord',
  revisionRecordSchema
);
