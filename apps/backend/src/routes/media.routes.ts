import { Router } from 'express';
import multer from 'multer';
import { authenticate } from '../middleware/auth/authenticate';
import { authorize } from '../middleware/auth/authorize';
import { asyncHandler } from '../utils/asyncHandler';
import { sendSuccess, sendCreated, sendError } from '../utils/apiResponse';
import { MediaService } from '../services/media/media.service';
import { MediaCategory, UserRole } from '@soteria/shared';

// In-memory storage — we handle file ourselves
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (_req, file, cb) => {
    if (['image/jpeg', 'image/png', 'image/webp'].includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only JPEG, PNG, and WebP images are allowed'));
    }
  },
});

const router = Router();
router.use(authenticate, authorize(UserRole.PROCEDURE_AUTHOR));

// POST /api/v1/media/upload
router.post(
  '/upload',
  upload.single('file'),
  asyncHandler(async (req, res) => {
    if (!req.file) return sendError(res, 'No file uploaded', 400);

    const { category, equipmentId, placardId, siteId, caption, notes } = req.body;

    if (!category || !Object.values(MediaCategory).includes(category)) {
      return sendError(res, `Invalid category. Must be one of: ${Object.values(MediaCategory).join(', ')}`, 400);
    }

    const asset = await MediaService.upload({
      buffer: req.file.buffer,
      originalFilename: req.file.originalname,
      mimeType: req.file.mimetype,
      sizeBytes: req.file.size,
      category: category as MediaCategory,
      companyId: req.user!.companyId,
      siteId,
      equipmentId,
      placardId,
      uploadedBy: req.user!.userId,
      caption,
      notes,
    });

    return sendCreated(res, asset, 'Media uploaded');
  })
);

// DELETE /api/v1/media/:id
router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    await MediaService.delete(req.params.id, req.user!.userId);
    return sendSuccess(res, null, 'Media deleted');
  })
);

export default router;
