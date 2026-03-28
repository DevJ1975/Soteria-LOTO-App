export interface ICompany {
  _id: string;
  name: string;
  slug: string; // used in serialization prefix, e.g. "SK" for Snak King
  logoUrl?: string;
  address?: IAddress;
  primaryContact?: string;
  isActive: boolean;
  settings: ICompanySettings;
  createdAt: Date;
  updatedAt: Date;
}

export interface IAddress {
  street?: string;
  city?: string;
  state?: string;
  zip?: string;
  country?: string;
}

export interface ICompanySettings {
  defaultLanguage: string;
  enableBilingual: boolean;
  requireDualApproval: boolean;
  placardSerialPrefix: string; // e.g. "SK"
  defaultTemplateId?: string;
  qrAccessMode: 'authenticated' | 'tokenized' | 'public_readonly';
}
