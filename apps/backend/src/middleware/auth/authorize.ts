import { Request, Response, NextFunction } from 'express';
import { UserRole } from '@soteria/shared';
import { sendError } from '../../utils/apiResponse';

// Role hierarchy: higher index = more privileged
const ROLE_HIERARCHY: UserRole[] = [
  UserRole.READ_ONLY,
  UserRole.PROCEDURE_AUTHOR,
  UserRole.REVIEWER,
  UserRole.APPROVER,
  UserRole.MAINTENANCE_MANAGER,
  UserRole.EHS_MANAGER,
  UserRole.SITE_ADMIN,
  UserRole.CORPORATE_SAFETY_ADMIN,
  UserRole.SUPER_ADMIN,
];

function hasRoleOrHigher(userRole: UserRole, requiredRole: UserRole): boolean {
  const userIdx = ROLE_HIERARCHY.indexOf(userRole);
  const reqIdx = ROLE_HIERARCHY.indexOf(requiredRole);
  return userIdx >= reqIdx;
}

/**
 * Authorize by minimum role level.
 * Example: authorize(UserRole.REVIEWER) allows REVIEWER, APPROVER, ADMIN, etc.
 */
export function authorize(...allowedRoles: UserRole[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user) {
      sendError(res, 'Authentication required', 401);
      return;
    }

    const userRole = req.user.role;
    const allowed = allowedRoles.some((role) => hasRoleOrHigher(userRole, role));

    if (!allowed) {
      sendError(res, 'Insufficient permissions', 403);
      return;
    }

    next();
  };
}

/**
 * Authorize by exact roles only (no hierarchy).
 */
export function authorizeExact(...allowedRoles: UserRole[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user) {
      sendError(res, 'Authentication required', 401);
      return;
    }

    if (!allowedRoles.includes(req.user.role)) {
      sendError(res, 'Insufficient permissions', 403);
      return;
    }

    next();
  };
}

/**
 * Ensure the request is scoped to the user's company.
 * Checks that :companyId param or body.companyId matches the authenticated user's company.
 */
export function requireSameCompany(req: Request, res: Response, next: NextFunction): void {
  if (!req.user) {
    sendError(res, 'Authentication required', 401);
    return;
  }

  const companyId =
    req.params.companyId || req.body?.companyId || (req.query.companyId as string);

  if (companyId && companyId !== req.user.companyId && req.user.role !== UserRole.SUPER_ADMIN) {
    sendError(res, 'Access to this company is not permitted', 403);
    return;
  }

  next();
}
