import { Router } from 'express';
import { authenticate } from '../middleware/auth/authenticate';
import { authorize } from '../middleware/auth/authorize';
import { asyncHandler } from '../utils/asyncHandler';
import { sendSuccess, sendCreated, sendError, sendPaginated } from '../utils/apiResponse';
import { EquipmentService } from '../services/equipment.service';
import { UserRole, EquipmentStatus } from '@soteria/shared';

const router = Router();

// All equipment routes require authentication
router.use(authenticate);

// GET /api/v1/equipment?siteId=&q=&status=&page=&limit=
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const { q, siteId, status, category, page, limit } = req.query;
    const companyId = req.user!.companyId;

    const result = await EquipmentService.search(companyId, {
      q: q as string,
      siteId: siteId as string,
      status: status as EquipmentStatus,
      category: category as string,
      page: page ? parseInt(page as string, 10) : 1,
      limit: limit ? parseInt(limit as string, 10) : 20,
    });

    return sendPaginated(res, result.items, result.page, result.limit, result.total);
  })
);

// GET /api/v1/equipment/:id
router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const equipment = await EquipmentService.findById(req.params.id);
    if (!equipment) return sendError(res, 'Equipment not found', 404);
    return sendSuccess(res, equipment);
  })
);

// POST /api/v1/equipment
router.post(
  '/',
  authorize(UserRole.PROCEDURE_AUTHOR),
  asyncHandler(async (req, res) => {
    const equipment = await EquipmentService.create(
      { ...req.body, companyId: req.user!.companyId },
      req.user!.userId
    );
    return sendCreated(res, equipment, 'Equipment created');
  })
);

// PUT /api/v1/equipment/:id
router.put(
  '/:id',
  authorize(UserRole.PROCEDURE_AUTHOR),
  asyncHandler(async (req, res) => {
    const equipment = await EquipmentService.update(req.params.id, req.body, req.user!.userId);
    return sendSuccess(res, equipment, 'Equipment updated');
  })
);

export default router;
