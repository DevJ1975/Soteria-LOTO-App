import { TranslationStatus } from './enums';

export interface ITranslation {
  _id: string;
  placardId: string;           // source (English) placard ID
  language: string;            // ISO 639-1, e.g. "es"
  status: TranslationStatus;
  translatedById?: string;
  reviewedById?: string;
  approvedById?: string;
  approvedAt?: Date;

  // Translated field map: fieldPath -> translated string
  // e.g. "procedureSteps.0.instruction" -> "Apague el equipo..."
  fields: Record<string, string>;

  // AI translation metadata
  aiGenerated: boolean;
  aiConfidence?: number;        // 0-1

  createdAt: Date;
  updatedAt: Date;
}
