import { Router } from 'express';
import { authenticate, optionalAuthenticate } from '../middleware/auth/authenticate';
import { asyncHandler } from '../utils/asyncHandler';
import { sendSuccess, sendError } from '../utils/apiResponse';
import { QRService } from '../services/qr.service';
import { Company } from '../models/Company';

const router = Router();

// GET /api/v1/qr/:token — resolve QR token (public or authenticated)
router.get(
  '/:token',
  optionalAuthenticate,
  asyncHandler(async (req, res) => {
    const { token } = req.params;
    const result = await QRService.resolveToken(
      token,
      req.user?.userId,
      req.ip
    );

    if (!result) {
      return sendError(res, 'QR code not found or inactive', 404);
    }

    // Check access mode
    const company = await Company.findById(result.placard.companyId);
    const accessMode = company?.settings?.qrAccessMode ?? 'authenticated';

    if (accessMode === 'authenticated' && !req.user) {
      return sendError(res, 'Authentication required to access this placard', 401);
    }

    return sendSuccess(res, result);
  })
);

// GET /api/v1/qr/:token/image — get QR code image
router.get(
  '/:token/image',
  authenticate,
  asyncHandler(async (req, res) => {
    const buffer = await QRService.generateQRBuffer(req.params.token);
    res.set('Content-Type', 'image/png');
    res.send(buffer);
  })
);

export default router;
