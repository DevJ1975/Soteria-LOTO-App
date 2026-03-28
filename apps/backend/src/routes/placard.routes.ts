import { Router } from 'express';
import { authenticate } from '../middleware/auth/authenticate';
import { authorize } from '../middleware/auth/authorize';
import { asyncHandler } from '../utils/asyncHandler';
import { sendSuccess, sendCreated, sendError, sendPaginated } from '../utils/apiResponse';
import { PlacardService } from '../services/placard.service';
import { AuditService } from '../services/audit.service';
import { Site } from '../models/Site';
import { UserRole, PlacardStatus } from '@soteria/shared';

const router = Router();
router.use(authenticate);

// GET /api/v1/placards
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const { q, siteId, status, equipmentId, page, limit } = req.query;
    const result = await PlacardService.search(req.user!.companyId, {
      q: q as string,
      siteId: siteId as string,
      status: status as PlacardStatus,
      equipmentId: equipmentId as string,
      page: page ? parseInt(page as string, 10) : 1,
      limit: limit ? parseInt(limit as string, 10) : 20,
    });
    return sendPaginated(res, result.items, result.page, result.limit, result.total);
  })
);

// GET /api/v1/placards/:id
router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const placard = await PlacardService.findById(req.params.id);
    if (!placard) return sendError(res, 'Placard not found', 404);
    return sendSuccess(res, placard);
  })
);

// POST /api/v1/placards — create draft
router.post(
  '/',
  authorize(UserRole.PROCEDURE_AUTHOR),
  asyncHandler(async (req, res) => {
    // Resolve site code for serial number generation
    const site = await Site.findById(req.body.siteId);
    if (!site) return sendError(res, 'Site not found', 404);

    const placard = await PlacardService.createDraft(
      { ...req.body, companyId: req.user!.companyId },
      req.user!.userId,
      site.code
    );
    return sendCreated(res, placard, 'Placard draft created');
  })
);

// PUT /api/v1/placards/:id — update draft
router.put(
  '/:id',
  authorize(UserRole.PROCEDURE_AUTHOR),
  asyncHandler(async (req, res) => {
    const placard = await PlacardService.update(req.params.id, req.body, req.user!.userId);
    return sendSuccess(res, placard, 'Placard updated');
  })
);

// POST /api/v1/placards/:id/submit — submit for review
router.post(
  '/:id/submit',
  authorize(UserRole.PROCEDURE_AUTHOR),
  asyncHandler(async (req, res) => {
    const placard = await PlacardService.submitForReview(req.params.id, req.user!.userId);
    return sendSuccess(res, placard, 'Submitted for review');
  })
);

// POST /api/v1/placards/:id/approve
router.post(
  '/:id/approve',
  authorize(UserRole.APPROVER),
  asyncHandler(async (req, res) => {
    const placard = await PlacardService.approve(
      req.params.id,
      req.user!.userId,
      req.body.comments
    );
    return sendSuccess(res, placard, 'Placard approved');
  })
);

// POST /api/v1/placards/:id/reject
router.post(
  '/:id/reject',
  authorize(UserRole.REVIEWER),
  asyncHandler(async (req, res) => {
    if (!req.body.comments) {
      return sendError(res, 'Rejection comments are required', 400);
    }
    const placard = await PlacardService.reject(
      req.params.id,
      req.user!.userId,
      req.body.comments
    );
    return sendSuccess(res, placard, 'Placard rejected');
  })
);

// POST /api/v1/placards/:id/revise — create new revision
router.post(
  '/:id/revise',
  authorize(UserRole.PROCEDURE_AUTHOR),
  asyncHandler(async (req, res) => {
    if (!req.body.changeDescription) {
      return sendError(res, 'Change description is required for new revision', 400);
    }
    const placard = await PlacardService.createNewRevision(
      req.params.id,
      req.body.changeDescription,
      req.user!.userId
    );
    return sendCreated(res, placard, 'New revision created');
  })
);

// GET /api/v1/placards/:placardNumber/history
router.get(
  '/:placardNumber/history',
  asyncHandler(async (req, res) => {
    const history = await PlacardService.getRevisionHistory(
      req.params.placardNumber,
      req.user!.companyId
    );
    return sendSuccess(res, history);
  })
);

// GET /api/v1/placards/:id/audit
router.get(
  '/:id/audit',
  asyncHandler(async (req, res) => {
    const { page, limit } = req.query;
    const result = await AuditService.getForTarget(
      req.user!.companyId,
      'placard',
      req.params.id,
      page ? parseInt(page as string) : 1,
      limit ? parseInt(limit as string) : 50
    );
    return sendPaginated(res, result.events, result.page, result.limit, result.total);
  })
);

export default router;
