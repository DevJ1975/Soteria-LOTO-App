import fs from 'fs';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import sharp from 'sharp';
import { MediaAsset } from '../../models/MediaAsset';
import { AuditService } from '../audit.service';
import { AuditEventType, MediaCategory, SUPPORTED_IMAGE_TYPES } from '@soteria/shared';
import { config } from '../../config/env';
import { logger } from '../../utils/logger';

interface UploadParams {
  buffer: Buffer;
  originalFilename: string;
  mimeType: string;
  sizeBytes: number;
  category: MediaCategory;
  companyId: string;
  siteId?: string;
  equipmentId?: string;
  placardId?: string;
  uploadedBy: string;
  caption?: string;
  notes?: string;
}

export class MediaService {
  /**
   * Upload and store a media file.
   * - Validates type and size
   * - Resizes large images for storage efficiency
   * - Stores locally (dev) or to S3 (prod)
   * - Creates MediaAsset record
   */
  static async upload(params: UploadParams) {
    const {
      buffer,
      originalFilename,
      mimeType,
      sizeBytes,
      category,
      companyId,
      uploadedBy,
    } = params;

    if (!SUPPORTED_IMAGE_TYPES.includes(mimeType)) {
      throw new Error(`Unsupported file type: ${mimeType}`);
    }

    const MAX_SIZE = 10 * 1024 * 1024; // 10MB
    if (sizeBytes > MAX_SIZE) {
      throw new Error('File exceeds maximum size of 10MB');
    }

    // Process image with sharp
    const sharpInstance = sharp(buffer);
    const metadata = await sharpInstance.metadata();

    // Resize if over 2400px on longest edge (preserves aspect ratio)
    let processedBuffer = buffer;
    let finalWidth = metadata.width ?? 0;
    let finalHeight = metadata.height ?? 0;

    if (finalWidth > 2400 || finalHeight > 2400) {
      processedBuffer = await sharpInstance
        .resize(2400, 2400, { fit: 'inside', withoutEnlargement: true })
        .jpeg({ quality: 85 })
        .toBuffer();
      const newMeta = await sharp(processedBuffer).metadata();
      finalWidth = newMeta.width ?? finalWidth;
      finalHeight = newMeta.height ?? finalHeight;
    }

    const ext = mimeType === 'image/png' ? 'png' : 'jpg';
    const filename = `${uuidv4()}.${ext}`;
    const storageKey = `${companyId}/${category}/${filename}`;

    let publicUrl: string | undefined;

    if (config.storage.provider === 's3') {
      publicUrl = await MediaService.uploadToS3(processedBuffer, storageKey, mimeType);
    } else {
      publicUrl = await MediaService.saveLocally(processedBuffer, storageKey);
    }

    const asset = await MediaAsset.create({
      companyId,
      siteId: params.siteId,
      equipmentId: params.equipmentId,
      placardId: params.placardId,
      category,
      filename,
      originalFilename,
      mimeType,
      sizeBytes: processedBuffer.byteLength,
      storageKey,
      storageProvider: config.storage.provider,
      publicUrl,
      width: finalWidth,
      height: finalHeight,
      caption: params.caption,
      notes: params.notes,
      uploadedBy,
      uploadedAt: new Date(),
    });

    await AuditService.log({
      eventType: AuditEventType.MEDIA_UPLOADED,
      companyId,
      userId: uploadedBy,
      targetType: 'media',
      targetId: asset._id.toString(),
      description: `Media uploaded: ${originalFilename} (${category})`,
    });

    return asset;
  }

  private static async saveLocally(buffer: Buffer, storageKey: string): Promise<string> {
    const fullPath = path.join(config.storage.localUploadDir, storageKey);
    const dir = path.dirname(fullPath);

    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    fs.writeFileSync(fullPath, buffer);
    return `/uploads/${storageKey}`;
  }

  private static async uploadToS3(
    buffer: Buffer,
    storageKey: string,
    mimeType: string
  ): Promise<string> {
    // Dynamic import to avoid S3 overhead in local dev
    const AWS = await import('aws-sdk');
    const s3 = new AWS.S3({
      accessKeyId: config.storage.aws.accessKeyId,
      secretAccessKey: config.storage.aws.secretAccessKey,
      region: config.storage.aws.region,
    });

    await s3
      .putObject({
        Bucket: config.storage.aws.bucket,
        Key: storageKey,
        Body: buffer,
        ContentType: mimeType,
        // Use presigned URLs rather than public ACL for security
        ServerSideEncryption: 'AES256',
      })
      .promise();

    return `https://${config.storage.aws.bucket}.s3.${config.storage.aws.region}.amazonaws.com/${storageKey}`;
  }

  static async getSignedUrl(storageKey: string, expiresSeconds = 3600): Promise<string> {
    if (config.storage.provider === 'local') {
      return `/uploads/${storageKey}`;
    }

    const AWS = await import('aws-sdk');
    const s3 = new AWS.S3({
      accessKeyId: config.storage.aws.accessKeyId,
      secretAccessKey: config.storage.aws.secretAccessKey,
      region: config.storage.aws.region,
    });

    return s3.getSignedUrlPromise('getObject', {
      Bucket: config.storage.aws.bucket,
      Key: storageKey,
      Expires: expiresSeconds,
    });
  }

  static async delete(assetId: string, userId: string) {
    const asset = await MediaAsset.findById(assetId);
    if (!asset) throw new Error('Media asset not found');

    if (config.storage.provider === 's3') {
      const AWS = await import('aws-sdk');
      const s3 = new AWS.S3({
        accessKeyId: config.storage.aws.accessKeyId,
        secretAccessKey: config.storage.aws.secretAccessKey,
        region: config.storage.aws.region,
      });
      await s3.deleteObject({ Bucket: config.storage.aws.bucket, Key: asset.storageKey }).promise();
    } else {
      const fullPath = path.join(config.storage.localUploadDir, asset.storageKey);
      if (fs.existsSync(fullPath)) fs.unlinkSync(fullPath);
    }

    await asset.deleteOne();

    await AuditService.log({
      eventType: AuditEventType.MEDIA_DELETED,
      companyId: asset.companyId.toString(),
      userId,
      targetType: 'media',
      targetId: assetId,
      description: `Media deleted: ${asset.originalFilename}`,
    });
  }
}
