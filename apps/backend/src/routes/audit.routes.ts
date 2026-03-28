import { Router } from 'express';
import { authenticate } from '../middleware/auth/authenticate';
import { authorize } from '../middleware/auth/authorize';
import { asyncHandler } from '../utils/asyncHandler';
import { sendPaginated } from '../utils/apiResponse';
import { AuditService } from '../services/audit.service';
import { UserRole } from '@soteria/shared';

const router = Router();
router.use(authenticate, authorize(UserRole.EHS_MANAGER));

// GET /api/v1/audit?page=&limit=
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const { page, limit } = req.query;
    const result = await AuditService.getForCompany(
      req.user!.companyId,
      page ? parseInt(page as string) : 1,
      limit ? parseInt(limit as string) : 100
    );
    return sendPaginated(res, result.events, result.page, result.limit, result.total);
  })
);

export default router;
