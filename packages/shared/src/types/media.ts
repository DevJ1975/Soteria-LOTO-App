import { MediaCategory } from './enums';

export interface IMediaAsset {
  _id: string;
  companyId: string;
  siteId?: string;
  equipmentId?: string;
  placardId?: string;

  category: MediaCategory;
  filename: string;
  originalFilename: string;
  mimeType: string;
  sizeBytes: number;

  // Storage
  storageKey: string;          // S3 key or local path
  storageProvider: 's3' | 'local';
  publicUrl?: string;          // signed or public URL

  // Image metadata
  width?: number;
  height?: number;

  // Annotation
  annotations?: IPhotoAnnotation[];
  caption?: string;
  notes?: string;

  uploadedBy: string;
  uploadedAt: Date;
  createdAt: Date;
}

export interface IPhotoAnnotation {
  id: string;
  x: number;                   // percentage 0-100
  y: number;                   // percentage 0-100
  label: string;
  color?: string;
}
