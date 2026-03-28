import mongoose, { Document, Schema } from 'mongoose';
import { AuditEventType } from '@soteria/shared';

export interface IAuditEventDocument extends Document {
  eventType: AuditEventType;
  companyId: mongoose.Types.ObjectId;
  userId?: mongoose.Types.ObjectId;
  targetType?: string;
  targetId?: string;
  description: string;
  metadata?: Record<string, unknown>;
  ipAddress?: string;
  userAgent?: string;
  createdAt: Date;
}

const auditEventSchema = new Schema<IAuditEventDocument>(
  {
    eventType: { type: String, enum: Object.values(AuditEventType), required: true, index: true },
    companyId: { type: Schema.Types.ObjectId, ref: 'Company', required: true, index: true },
    userId: { type: Schema.Types.ObjectId, ref: 'User', index: true },
    targetType: String,
    targetId: String,
    description: { type: String, required: true },
    metadata: { type: Schema.Types.Mixed },
    ipAddress: String,
    userAgent: String,
  },
  {
    timestamps: { createdAt: true, updatedAt: false },
    // Audit events are immutable — no updates allowed
    strict: true,
  }
);

// Time-series style indexes for efficient range queries
auditEventSchema.index({ companyId: 1, createdAt: -1 });
auditEventSchema.index({ companyId: 1, targetType: 1, targetId: 1, createdAt: -1 });
auditEventSchema.index({ companyId: 1, userId: 1, createdAt: -1 });

export const AuditEvent = mongoose.model<IAuditEventDocument>('AuditEvent', auditEventSchema);
