import { ApprovalAction, PlacardStatus } from './enums';

export interface IApprovalRecord {
  _id: string;
  placardId: string;
  companyId: string;
  action: ApprovalAction;
  performedById: string;
  fromStatus: PlacardStatus;
  toStatus: PlacardStatus;
  comments?: string;
  createdAt: Date;
}
