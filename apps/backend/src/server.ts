import app from './app';
import { config } from './config/env';
import { connectDatabase, disconnectDatabase } from './config/database';
import { logger } from './utils/logger';

async function start() {
  await connectDatabase();

  const server = app.listen(config.port, () => {
    logger.info(`Soteria LOTO Backend running on port ${config.port} [${config.env}]`);
    logger.info(`API: http://localhost:${config.port}/api/${config.apiVersion}`);
  });

  // Graceful shutdown
  const shutdown = async (signal: string) => {
    logger.info(`${signal} received — shutting down gracefully`);
    server.close(async () => {
      await disconnectDatabase();
      logger.info('Server closed');
      process.exit(0);
    });

    // Force kill after 10s
    setTimeout(() => {
      logger.error('Force shutdown after timeout');
      process.exit(1);
    }, 10000);
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('unhandledRejection', (reason) => {
    logger.error('Unhandled rejection:', reason);
  });
}

start().catch((err) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
