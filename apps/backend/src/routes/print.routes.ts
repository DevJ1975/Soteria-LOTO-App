import { Router } from 'express';
import { authenticate } from '../middleware/auth/authenticate';
import { asyncHandler } from '../utils/asyncHandler';
import { sendError } from '../utils/apiResponse';
import { PlacardService } from '../services/placard.service';
import { MediaAsset } from '../models/MediaAsset';
import { PlacardTemplate } from '../models/PlacardTemplate';
import { QRService } from '../services/qr.service';
import { PDFService } from '@soteria/placard-engine';
import { PrintFormat } from '@soteria/shared';
import type { IPlacard, IPlacardTemplate } from '@soteria/shared';
import { MediaService } from '../services/media/media.service';
import { AuditService } from '../services/audit.service';
import { AuditEventType } from '@soteria/shared';
import fs from 'fs';
import { config } from '../config/env';
import path from 'path';

const router = Router();
router.use(authenticate);

// GET /api/v1/print/:placardId?format=placard_en|placard_es|dual_sided|qr_posting_sign
router.get(
  '/:placardId',
  asyncHandler(async (req, res) => {
    const { format = 'placard_en' } = req.query;
    const printFormat = format as PrintFormat;

    const placard = await PlacardService.findById(req.params.placardId);
    if (!placard) return sendError(res, 'Placard not found', 404);

    // Fetch template
    const templateDoc = placard.templateId
      ? await PlacardTemplate.findById(placard.templateId)
      : null;

    // Fallback: dynamically import SnakKingPlacardTemplate
    let template: IPlacardTemplate;
    if (templateDoc) {
      template = templateDoc.toObject() as unknown as IPlacardTemplate;
    } else {
      const { SnakKingPlacardTemplate } = await import('@soteria/placard-engine');
      template = { ...SnakKingPlacardTemplate, _id: 'default' } as IPlacardTemplate;
    }

    // Fetch QR buffer if approved
    let qrBuffer: Buffer | undefined;
    if (placard.qrToken) {
      qrBuffer = await QRService.generateQRBuffer(placard.qrToken);
    }

    // Fetch photo buffers
    const photoBuffers: Record<string, Buffer> = {};
    if (placard.mediaIds?.length) {
      const assets = await MediaAsset.find({ _id: { $in: placard.mediaIds } });
      for (const asset of assets) {
        try {
          if (config.storage.provider === 'local') {
            const fullPath = path.join(config.storage.localUploadDir, asset.storageKey);
            if (fs.existsSync(fullPath)) {
              photoBuffers[`${asset.category}_${asset._id}`] = fs.readFileSync(fullPath);
            }
          }
          // For S3: fetch using signed URL or AWS SDK — implementation left for production
        } catch {
          // Skip failed photos
        }
      }
    }

    // Generate PDF
    const pdfBuffer = await PDFService.generate({
      placard: placard.toObject() as unknown as IPlacard,
      template,
      printFormat,
      photoBuffers,
      qrBuffer,
    });

    await AuditService.log({
      eventType: AuditEventType.PDF_EXPORTED,
      companyId: placard.companyId.toString(),
      userId: req.user!.userId,
      targetType: 'placard',
      targetId: placard._id.toString(),
      description: `PDF exported: ${placard.placardNumber} (${printFormat})`,
    });

    const filename = `${placard.placardNumber}-Rev${placard.revisionNumber}-${printFormat}.pdf`;
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.send(pdfBuffer);
  })
);

export default router;
