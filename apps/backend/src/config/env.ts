import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

function requireEnv(key: string): string {
  const val = process.env[key];
  if (!val) throw new Error(`Missing required environment variable: ${key}`);
  return val;
}

function optionalEnv(key: string, fallback: string): string {
  return process.env[key] ?? fallback;
}

export const config = {
  env: optionalEnv('NODE_ENV', 'development'),
  port: parseInt(optionalEnv('PORT', '4000'), 10),
  apiVersion: optionalEnv('API_VERSION', 'v1'),

  mongodb: {
    uri: optionalEnv('MONGODB_URI', 'mongodb://localhost:27017/soteria_loto'),
    dbName: optionalEnv('MONGODB_DB_NAME', 'soteria_loto'),
  },

  jwt: {
    secret: optionalEnv('JWT_SECRET', 'dev_secret_change_in_prod_123456789'),
    refreshSecret: optionalEnv('JWT_REFRESH_SECRET', 'dev_refresh_secret_change_in_prod'),
    expiresIn: optionalEnv('JWT_EXPIRES_IN', '15m'),
    refreshExpiresIn: optionalEnv('JWT_REFRESH_EXPIRES_IN', '7d'),
  },

  anthropic: {
    apiKey: optionalEnv('ANTHROPIC_API_KEY', ''),
  },

  storage: {
    provider: optionalEnv('STORAGE_PROVIDER', 'local') as 'local' | 's3',
    localUploadDir: optionalEnv('LOCAL_UPLOAD_DIR', './uploads'),
    aws: {
      accessKeyId: optionalEnv('AWS_ACCESS_KEY_ID', ''),
      secretAccessKey: optionalEnv('AWS_SECRET_ACCESS_KEY', ''),
      region: optionalEnv('AWS_REGION', 'us-west-2'),
      bucket: optionalEnv('AWS_S3_BUCKET', 'soteria-loto-media'),
    },
  },

  qr: {
    baseUrl: optionalEnv('QR_BASE_URL', 'http://localhost:3000/q'),
  },

  rateLimit: {
    windowMs: parseInt(optionalEnv('RATE_LIMIT_WINDOW_MS', '900000'), 10),
    max: parseInt(optionalEnv('RATE_LIMIT_MAX', '200'), 10),
  },

  logging: {
    level: optionalEnv('LOG_LEVEL', 'debug'),
  },

  isDev: optionalEnv('NODE_ENV', 'development') === 'development',
  isProd: optionalEnv('NODE_ENV', 'development') === 'production',
} as const;
