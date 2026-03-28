import { Router } from 'express';
import authRoutes from './auth.routes';
import siteRoutes from './site.routes';
import equipmentRoutes from './equipment.routes';
import placardRoutes from './placard.routes';
import mediaRoutes from './media.routes';
import aiRoutes from './ai.routes';
import qrRoutes from './qr.routes';
import auditRoutes from './audit.routes';
import printRoutes from './print.routes';

const router = Router();

router.use('/auth', authRoutes);
router.use('/sites', siteRoutes);
router.use('/equipment', equipmentRoutes);
router.use('/placards', placardRoutes);
router.use('/media', mediaRoutes);
router.use('/ai', aiRoutes);
router.use('/qr', qrRoutes);
router.use('/audit', auditRoutes);
router.use('/print', printRoutes);

export default router;
