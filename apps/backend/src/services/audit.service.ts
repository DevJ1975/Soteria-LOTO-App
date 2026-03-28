import { AuditEvent } from '../models/AuditEvent';
import { AuditEventType } from '@soteria/shared';

interface LogParams {
  eventType: AuditEventType;
  companyId: string;
  userId?: string;
  targetType?: string;
  targetId?: string;
  description: string;
  metadata?: Record<string, unknown>;
  ipAddress?: string;
  userAgent?: string;
}

export class AuditService {
  /**
   * Write an immutable audit event.
   * Fire-and-forget — never throws (logs to stderr on failure).
   */
  static async log(params: LogParams): Promise<void> {
    try {
      await AuditEvent.create(params);
    } catch (err) {
      console.error('[AuditService] Failed to write audit event:', err);
    }
  }

  static async getForTarget(
    companyId: string,
    targetType: string,
    targetId: string,
    page = 1,
    limit = 50
  ) {
    const skip = (page - 1) * limit;
    const [events, total] = await Promise.all([
      AuditEvent.find({ companyId, targetType, targetId })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate('userId', 'firstName lastName email'),
      AuditEvent.countDocuments({ companyId, targetType, targetId }),
    ]);
    return { events, total, page, limit };
  }

  static async getForCompany(companyId: string, page = 1, limit = 100) {
    const skip = (page - 1) * limit;
    const [events, total] = await Promise.all([
      AuditEvent.find({ companyId })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate('userId', 'firstName lastName email'),
      AuditEvent.countDocuments({ companyId }),
    ]);
    return { events, total, page, limit };
  }
}
