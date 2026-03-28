import { EquipmentStatus } from './enums';

export interface IEquipment {
  _id: string;
  companyId: string;
  siteId: string;
  departmentId?: string;
  productionLineId?: string;

  // Identification
  equipmentId: string;      // Internal ID / asset tag
  commonName: string;       // e.g. "Horizontal Mixer #3"
  formalName: string;       // e.g. "Ribbon Blender / Horizontal Mixer"
  category: string;         // e.g. "Mixer", "Conveyor", "Compressor"

  // Nameplate data
  manufacturer?: string;
  model?: string;
  serialNumber?: string;
  yearManufactured?: number;

  // Utility / power data
  electricalVoltage?: string;   // e.g. "480V 3-Phase"
  electricalAmps?: string;
  pneumaticPressure?: string;   // e.g. "90 PSI"
  hydraulicPressure?: string;

  // Notes
  operationalNotes?: string;
  location?: string;            // physical location description

  status: EquipmentStatus;

  // Associated placards (references)
  currentPlacardId?: string;
  placardIds: string[];

  // Photos
  primaryPhotoUrl?: string;

  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
}

export type CreateEquipmentDto = Omit<IEquipment, '_id' | 'createdAt' | 'updatedAt' | 'placardIds'>;
export type UpdateEquipmentDto = Partial<Omit<IEquipment, '_id' | 'companyId' | 'createdAt' | 'updatedAt'>>;
