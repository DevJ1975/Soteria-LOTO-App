import { Request, Response } from 'express';
import { AuthService } from '../services/auth.service';
import { sendSuccess, sendError } from '../utils/apiResponse';
import { asyncHandler } from '../utils/asyncHandler';
import { User } from '../models/User';
import { UserRole } from '@soteria/shared';

export const login = asyncHandler(async (req: Request, res: Response) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return sendError(res, 'Email and password are required', 400);
  }

  try {
    const result = await AuthService.login(email, password, req.ip);
    return sendSuccess(res, result, 'Login successful');
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Login failed';
    return sendError(res, message, 401);
  }
});

export const refresh = asyncHandler(async (req: Request, res: Response) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    return sendError(res, 'Refresh token required', 400);
  }

  try {
    const result = await AuthService.refresh(refreshToken);
    return sendSuccess(res, result);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Token refresh failed';
    return sendError(res, message, 401);
  }
});

export const logout = asyncHandler(async (req: Request, res: Response) => {
  if (req.user) {
    await AuthService.logout(req.user.userId);
  }
  return sendSuccess(res, null, 'Logged out successfully');
});

export const getMe = asyncHandler(async (req: Request, res: Response) => {
  if (!req.user) return sendError(res, 'Not authenticated', 401);

  const user = await User.findById(req.user.userId).populate('companyId', 'name slug settings');
  if (!user) return sendError(res, 'User not found', 404);

  return sendSuccess(res, user);
});

export const register = asyncHandler(async (req: Request, res: Response) => {
  // Only SUPER_ADMIN or SITE_ADMIN can create users via API
  const { email, password, firstName, lastName, role, companyId, siteIds } = req.body;

  const existing = await User.findOne({ email: email?.toLowerCase() });
  if (existing) {
    return sendError(res, 'Email already in use', 409);
  }

  const user = await User.create({
    email,
    password,
    firstName,
    lastName,
    role: role ?? UserRole.PROCEDURE_AUTHOR,
    companyId,
    siteIds: siteIds ?? [],
  });

  return sendSuccess(res, user, 'User created', 201);
});
