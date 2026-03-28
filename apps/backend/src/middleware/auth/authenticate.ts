import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../../config/env';
import { sendError } from '../../utils/apiResponse';
import { IAuthPayload, UserRole } from '@soteria/shared';

// Extend Express Request to carry authenticated user
declare global {
  namespace Express {
    interface Request {
      user?: IAuthPayload;
    }
  }
}

export function authenticate(req: Request, res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith('Bearer ')) {
    sendError(res, 'Authentication required', 401);
    return;
  }

  const token = authHeader.split(' ')[1];

  try {
    const payload = jwt.verify(token, config.jwt.secret) as IAuthPayload;
    req.user = payload;
    next();
  } catch (err) {
    if (err instanceof jwt.TokenExpiredError) {
      sendError(res, 'Token expired', 401);
    } else {
      sendError(res, 'Invalid token', 401);
    }
  }
}

/**
 * Optional auth — attaches user if token present, does not fail if missing.
 * Used for QR code endpoints that allow anonymous access when configured.
 */
export function optionalAuthenticate(req: Request, res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return next();
  }

  const token = authHeader.split(' ')[1];
  try {
    const payload = jwt.verify(token, config.jwt.secret) as IAuthPayload;
    req.user = payload;
  } catch {
    // Token invalid but access may still be allowed for public QR
  }
  next();
}
