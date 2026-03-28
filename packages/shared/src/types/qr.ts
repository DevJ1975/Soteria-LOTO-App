export interface IQRRecord {
  _id: string;
  token: string;               // unique random token in QR URL
  placardId: string;           // resolves to this placard
  companyId: string;
  isActive: boolean;
  scanCount: number;
  lastScannedAt?: Date;
  lastScannedBy?: string;
  createdAt: Date;
  updatedAt: Date;
}
