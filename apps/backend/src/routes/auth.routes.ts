import { Router } from 'express';
import { login, logout, refresh, getMe, register } from '../controllers/auth.controller';
import { authenticate } from '../middleware/auth/authenticate';
import { authorize } from '../middleware/auth/authorize';
import { UserRole } from '@soteria/shared';

const router = Router();

// POST /api/v1/auth/login
router.post('/login', login);

// POST /api/v1/auth/refresh
router.post('/refresh', refresh);

// POST /api/v1/auth/logout
router.post('/logout', authenticate, logout);

// GET /api/v1/auth/me
router.get('/me', authenticate, getMe);

// POST /api/v1/auth/register  (admin-only)
router.post('/register', authenticate, authorize(UserRole.SITE_ADMIN), register);

export default router;
