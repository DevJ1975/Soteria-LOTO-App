import { AuditEventType } from './enums';

export interface IAuditEvent {
  _id: string;
  eventType: AuditEventType;
  companyId: string;
  userId?: string;
  targetType?: string;         // 'placard' | 'equipment' | 'user' | etc.
  targetId?: string;
  description: string;
  metadata?: Record<string, unknown>;
  ipAddress?: string;
  userAgent?: string;
  createdAt: Date;
}
