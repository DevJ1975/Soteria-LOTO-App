import QRCode from 'qrcode';
import { QRRecord } from '../models/QRRecord';
import { Placard } from '../models/Placard';
import { AuditService } from './audit.service';
import { AuditEventType, buildQRToken } from '@soteria/shared';
import { config } from '../config/env';

export class QRService {
  /**
   * Generate QR code PNG buffer for a placard token.
   */
  static async generateQRBuffer(token: string): Promise<Buffer> {
    const url = `${config.qr.baseUrl}/${token}`;
    return QRCode.toBuffer(url, {
      type: 'png',
      width: 300,
      margin: 2,
      color: { dark: '#000000', light: '#FFFFFF' },
      errorCorrectionLevel: 'H',
    });
  }

  /**
   * Generate QR code as a data URL (base64) for embedding in PDFs.
   */
  static async generateQRDataUrl(token: string): Promise<string> {
    const url = `${config.qr.baseUrl}/${token}`;
    return QRCode.toDataURL(url, {
      type: 'image/png',
      width: 300,
      margin: 2,
      errorCorrectionLevel: 'H',
    });
  }

  /**
   * Resolve a QR token to the current approved placard.
   */
  static async resolveToken(
    token: string,
    scannedByUserId?: string,
    ipAddress?: string
  ) {
    const qrRecord = await QRRecord.findOne({ token, isActive: true });
    if (!qrRecord) return null;

    // Find the current approved version (QR token is on the approved placard)
    const placard = await Placard.findById(qrRecord.placardId)
      .populate('authorId', 'firstName lastName')
      .populate('approverId', 'firstName lastName')
      .populate('mediaIds');

    if (!placard) return null;

    // Increment scan counter
    await QRRecord.findByIdAndUpdate(qrRecord._id, {
      $inc: { scanCount: 1 },
      lastScannedAt: new Date(),
      ...(scannedByUserId && { lastScannedBy: scannedByUserId }),
    });

    // Audit
    await AuditService.log({
      eventType: AuditEventType.QR_SCANNED,
      companyId: qrRecord.companyId.toString(),
      userId: scannedByUserId,
      targetType: 'placard',
      targetId: placard._id.toString(),
      description: `QR scanned for placard: ${placard.placardNumber}`,
      ipAddress,
    });

    return { placard, qrRecord };
  }

  /**
   * Create a QR token for an approved placard.
   */
  static async createForPlacard(placardId: string, companyId: string): Promise<string> {
    const token = buildQRToken();
    await QRRecord.create({ token, placardId, companyId });
    return token;
  }
}
