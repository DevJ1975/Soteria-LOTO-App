export interface ISite {
  _id: string;
  companyId: string;
  name: string;
  code: string; // short code used in serialization, e.g. "COI" for City of Industry
  address?: {
    street?: string;
    city?: string;
    state?: string;
    zip?: string;
  };
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface IDepartment {
  _id: string;
  siteId: string;
  companyId: string;
  name: string;
  code: string;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface IProductionLine {
  _id: string;
  departmentId: string;
  siteId: string;
  companyId: string;
  name: string;
  code: string;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}
