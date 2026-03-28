import mongoose, { Document, Schema } from 'mongoose';
import { TemplateSectionType } from '@soteria/shared';

export interface IPlacardTemplateDocument extends Document {
  name: string;
  displayName: string;
  description?: string;
  companyId?: mongoose.Types.ObjectId;
  isActive: boolean;
  layout: Record<string, unknown>;
  sections: Array<{
    id: string;
    type: string;
    label: string;
    labelEs?: string;
    isEnabled: boolean;
    order: number;
    config: Record<string, unknown>;
  }>;
  branding: Record<string, unknown>;
  printConfig: Record<string, unknown>;
  createdBy: mongoose.Types.ObjectId;
  createdAt: Date;
  updatedAt: Date;
}

const templateSchema = new Schema<IPlacardTemplateDocument>(
  {
    name: { type: String, required: true, unique: true, trim: true },
    displayName: { type: String, required: true },
    description: String,
    companyId: { type: Schema.Types.ObjectId, ref: 'Company', index: true },
    isActive: { type: Boolean, default: true },
    layout: { type: Schema.Types.Mixed, required: true },
    sections: [
      {
        id: String,
        type: { type: String, enum: Object.values(TemplateSectionType) },
        label: String,
        labelEs: String,
        isEnabled: { type: Boolean, default: true },
        order: Number,
        config: { type: Schema.Types.Mixed, default: {} },
        _id: false,
      },
    ],
    branding: { type: Schema.Types.Mixed, default: {} },
    printConfig: { type: Schema.Types.Mixed, default: {} },
    createdBy: { type: Schema.Types.ObjectId, ref: 'User', required: true },
  },
  { timestamps: true }
);

export const PlacardTemplate = mongoose.model<IPlacardTemplateDocument>(
  'PlacardTemplate',
  templateSchema
);
