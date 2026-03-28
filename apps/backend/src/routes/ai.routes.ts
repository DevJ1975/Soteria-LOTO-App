import { Router } from 'express';
import { authenticate } from '../middleware/auth/authenticate';
import { authorize } from '../middleware/auth/authorize';
import { asyncHandler } from '../utils/asyncHandler';
import { sendSuccess, sendError } from '../utils/apiResponse';
import { AIService } from '../services/ai/ai.service';
import { UserRole } from '@soteria/shared';

const router = Router();
router.use(authenticate, authorize(UserRole.PROCEDURE_AUTHOR));

// POST /api/v1/ai/draft — generate LOTO draft
router.post(
  '/draft',
  asyncHandler(async (req, res) => {
    if (!req.body.machineInfo) {
      return sendError(res, 'machineInfo is required', 400);
    }

    const result = await AIService.generateDraft(
      req.body,
      req.user!.userId,
      req.user!.companyId,
      req.body.placardId
    );

    return sendSuccess(res, result, 'AI draft generated — review all content before proceeding');
  })
);

// POST /api/v1/ai/translate — translate placard content to Spanish
router.post(
  '/translate',
  asyncHandler(async (req, res) => {
    const result = await AIService.translateToSpanish(
      req.body.content,
      req.user!.userId,
      req.user!.companyId
    );
    return sendSuccess(res, result, 'Translation generated — review before use');
  })
);

// POST /api/v1/ai/review — validate draft completeness
router.post(
  '/review',
  asyncHandler(async (req, res) => {
    const result = await AIService.reviewDraft(
      req.body.placard,
      req.user!.userId,
      req.user!.companyId
    );
    return sendSuccess(res, result);
  })
);

export default router;
