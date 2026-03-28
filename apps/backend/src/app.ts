import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import path from 'path';
import { config } from './config/env';
import { logger } from './utils/logger';
import { sendError } from './utils/apiResponse';
import apiRoutes from './routes/index';

const app = express();

// ─── Security middleware ──────────────────────────────────────
app.use(helmet());
app.use(
  cors({
    origin: config.isDev
      ? ['http://localhost:3000', 'http://localhost:5173']
      : (process.env.ALLOWED_ORIGINS ?? '').split(','),
    credentials: true,
  })
);

// ─── Rate limiting ────────────────────────────────────────────
const limiter = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.max,
  message: { success: false, message: 'Too many requests, please try again later' },
});
app.use(limiter);

// ─── Body parsing ─────────────────────────────────────────────
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ─── HTTP logging ─────────────────────────────────────────────
app.use(
  morgan(config.isDev ? 'dev' : 'combined', {
    stream: { write: (msg) => logger.info(msg.trim()) },
  })
);

// ─── Static uploads (dev only) ────────────────────────────────
if (config.storage.provider === 'local') {
  app.use('/uploads', express.static(path.resolve(config.storage.localUploadDir)));
}

// ─── API routes ───────────────────────────────────────────────
app.use(`/api/${config.apiVersion}`, apiRoutes);

// ─── Health check ─────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', version: config.apiVersion, ts: new Date().toISOString() });
});

// ─── 404 handler ─────────────────────────────────────────────
app.use((_req, res) => {
  sendError(res, 'Route not found', 404);
});

// ─── Global error handler ────────────────────────────────────
app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  logger.error('Unhandled error:', err);

  if (err.name === 'ValidationError') {
    return sendError(res, 'Validation failed', 422, [err.message]);
  }
  if (err.name === 'CastError') {
    return sendError(res, 'Invalid ID format', 400);
  }
  if ((err as NodeJS.ErrnoException).code === 'LIMIT_FILE_SIZE') {
    return sendError(res, 'File too large (max 10MB)', 413);
  }

  return sendError(res, config.isDev ? err.message : 'Internal server error', 500);
});

export default app;
