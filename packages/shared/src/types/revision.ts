export interface IRevisionRecord {
  _id: string;
  placardId: string;          // current placard ID
  companyId: string;
  revisionNumber: number;
  revisionDate: Date;
  changeDescription: string;
  changedById: string;

  // Snapshot of the placard content at this revision
  // (immutable record)
  snapshot: Record<string, unknown>;

  // Who did what
  authorId: string;
  reviewerId?: string;
  approverId?: string;
  reviewDate?: Date;
  approvalDate?: Date;

  createdAt: Date;
}
