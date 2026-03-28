import { Router } from 'express';
import { authenticate } from '../middleware/auth/authenticate';
import { authorize } from '../middleware/auth/authorize';
import { asyncHandler } from '../utils/asyncHandler';
import { sendSuccess, sendCreated, sendError } from '../utils/apiResponse';
import { Site, Department } from '../models/Site';
import { UserRole } from '@soteria/shared';

const router = Router();
router.use(authenticate);

// GET /api/v1/sites
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const sites = await Site.find({
      companyId: req.user!.companyId,
      isActive: true,
    }).sort({ name: 1 });
    return sendSuccess(res, sites);
  })
);

// POST /api/v1/sites
router.post(
  '/',
  authorize(UserRole.SITE_ADMIN),
  asyncHandler(async (req, res) => {
    const site = await Site.create({ ...req.body, companyId: req.user!.companyId });
    return sendCreated(res, site, 'Site created');
  })
);

// GET /api/v1/sites/:siteId/departments
router.get(
  '/:siteId/departments',
  asyncHandler(async (req, res) => {
    const departments = await Department.find({
      siteId: req.params.siteId,
      companyId: req.user!.companyId,
    }).sort({ name: 1 });
    return sendSuccess(res, departments);
  })
);

// POST /api/v1/sites/:siteId/departments
router.post(
  '/:siteId/departments',
  authorize(UserRole.SITE_ADMIN),
  asyncHandler(async (req, res) => {
    const dept = await Department.create({
      ...req.body,
      siteId: req.params.siteId,
      companyId: req.user!.companyId,
    });
    return sendCreated(res, dept, 'Department created');
  })
);

export default router;
