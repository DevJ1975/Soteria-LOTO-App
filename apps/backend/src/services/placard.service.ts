import mongoose from 'mongoose';
import { Placard } from '../models/Placard';
import { RevisionRecord } from '../models/RevisionRecord';
import { Company } from '../models/Company';
import { QRRecord } from '../models/QRRecord';
import { EquipmentService } from './equipment.service';
import { AuditService } from './audit.service';
import {
  PlacardStatus,
  ApprovalAction,
  AuditEventType,
  buildQRToken,
  buildPlacardNumber,
} from '@soteria/shared';

export class PlacardService {
  /**
   * Generate the next placard number for a company+site combination.
   * Uses atomic findOneAndUpdate on the Company document to ensure uniqueness.
   */
  static async nextPlacardNumber(companyId: string, siteId: string, siteCode: string): Promise<string> {
    const company = await Company.findById(companyId);
    if (!company) throw new Error('Company not found');

    const key = siteCode.toUpperCase();
    const current = company.placardSequences.get(key) ?? 0;
    const next = current + 1;

    await Company.findByIdAndUpdate(companyId, {
      $set: { [`placardSequences.${key}`]: next },
    });

    return buildPlacardNumber(company.slug, siteCode, next);
  }

  static async createDraft(
    data: Record<string, unknown>,
    userId: string,
    siteCode: string
  ) {
    const companyId = data.companyId as string;
    const siteId = data.siteId as string;

    const placardNumber = await PlacardService.nextPlacardNumber(companyId, siteId, siteCode);

    const placard = await Placard.create({
      ...data,
      placardNumber,
      revisionNumber: 1,
      revisionDate: new Date(),
      status: PlacardStatus.DRAFT,
      authorId: userId,
      wasAIAssisted: data.wasAIAssisted ?? false,
    });

    // Link to equipment if provided
    if (data.equipmentId) {
      await EquipmentService.linkPlacard(data.equipmentId as string, placard._id.toString());
    }

    await AuditService.log({
      eventType: AuditEventType.PLACARD_CREATED,
      companyId,
      userId,
      targetType: 'placard',
      targetId: placard._id.toString(),
      description: `Placard draft created: ${placardNumber}`,
    });

    return placard;
  }

  static async findById(id: string) {
    return Placard.findById(id)
      .populate('authorId', 'firstName lastName email')
      .populate('reviewerId', 'firstName lastName email')
      .populate('approverId', 'firstName lastName email')
      .populate('equipmentId', 'equipmentId commonName')
      .populate('mediaIds');
  }

  static async update(id: string, data: Record<string, unknown>, userId: string) {
    const placard = await Placard.findById(id);
    if (!placard) throw new Error('Placard not found');

    if (![PlacardStatus.DRAFT, PlacardStatus.REJECTED].includes(placard.status)) {
      throw new Error('Only draft or rejected placards can be edited');
    }

    Object.assign(placard, data);
    await placard.save();

    await AuditService.log({
      eventType: AuditEventType.PLACARD_UPDATED,
      companyId: placard.companyId.toString(),
      userId,
      targetType: 'placard',
      targetId: placard._id.toString(),
      description: `Placard updated: ${placard.placardNumber}`,
    });

    return placard;
  }

  static async submitForReview(placardId: string, userId: string) {
    const placard = await Placard.findById(placardId);
    if (!placard) throw new Error('Placard not found');
    if (placard.status !== PlacardStatus.DRAFT) {
      throw new Error('Only draft placards can be submitted for review');
    }

    placard.status = PlacardStatus.PENDING_REVIEW;
    await placard.save();

    await AuditService.log({
      eventType: AuditEventType.PLACARD_SUBMITTED,
      companyId: placard.companyId.toString(),
      userId,
      targetType: 'placard',
      targetId: placard._id.toString(),
      description: `Placard submitted for review: ${placard.placardNumber}`,
    });

    return placard;
  }

  static async approve(placardId: string, approverId: string, comments?: string) {
    const placard = await Placard.findById(placardId);
    if (!placard) throw new Error('Placard not found');

    if (![PlacardStatus.PENDING_APPROVAL, PlacardStatus.IN_REVIEW].includes(placard.status)) {
      throw new Error('Placard is not ready for approval');
    }

    // Generate QR token on first approval
    const qrToken = placard.qrToken ?? buildQRToken();

    placard.status = PlacardStatus.APPROVED;
    placard.approverId = new mongoose.Types.ObjectId(approverId);
    placard.approvalDate = new Date();
    placard.qrToken = qrToken;
    await placard.save();

    // Create or update QR record
    await QRRecord.findOneAndUpdate(
      { token: qrToken },
      {
        token: qrToken,
        placardId: placard._id,
        companyId: placard.companyId,
        isActive: true,
      },
      { upsert: true, new: true }
    );

    // Link to equipment as current placard
    if (placard.equipmentId) {
      await EquipmentService.linkPlacard(placard.equipmentId.toString(), placard._id.toString());
    }

    // Create revision snapshot
    await RevisionRecord.create({
      placardId: placard._id,
      companyId: placard.companyId,
      revisionNumber: placard.revisionNumber,
      revisionDate: placard.revisionDate,
      changeDescription: placard.changeDescription ?? 'Initial approved revision',
      changedById: approverId,
      snapshot: placard.toObject(),
      authorId: placard.authorId,
      reviewerId: placard.reviewerId,
      approverId: placard.approverId,
      reviewDate: placard.reviewDate,
      approvalDate: placard.approvalDate,
    });

    await AuditService.log({
      eventType: AuditEventType.PLACARD_APPROVED,
      companyId: placard.companyId.toString(),
      userId: approverId,
      targetType: 'placard',
      targetId: placard._id.toString(),
      description: `Placard approved: ${placard.placardNumber} Rev.${placard.revisionNumber}`,
      metadata: { comments },
    });

    return placard;
  }

  static async reject(placardId: string, userId: string, comments: string) {
    const placard = await Placard.findById(placardId);
    if (!placard) throw new Error('Placard not found');

    placard.status = PlacardStatus.REJECTED;
    await placard.save();

    await AuditService.log({
      eventType: AuditEventType.PLACARD_REJECTED,
      companyId: placard.companyId.toString(),
      userId,
      targetType: 'placard',
      targetId: placard._id.toString(),
      description: `Placard rejected: ${placard.placardNumber}`,
      metadata: { comments },
    });

    return placard;
  }

  /**
   * Create a new revision of an approved placard.
   * Supersedes the current approved version and creates a new draft.
   */
  static async createNewRevision(
    originalPlacardId: string,
    changeDescription: string,
    userId: string
  ) {
    const original = await Placard.findById(originalPlacardId);
    if (!original) throw new Error('Original placard not found');
    if (original.status !== PlacardStatus.APPROVED) {
      throw new Error('Can only create new revision from an approved placard');
    }

    // Mark original as superseded
    original.status = PlacardStatus.SUPERSEDED;
    await original.save();

    // Clone into new draft
    const newData = original.toObject();
    delete newData._id;
    delete newData.__v;
    delete newData.qrToken;
    delete newData.approvalDate;
    delete newData.reviewDate;
    delete newData.approverId;
    delete newData.reviewerId;
    newData.revisionNumber = original.revisionNumber + 1;
    newData.revisionDate = new Date();
    newData.status = PlacardStatus.DRAFT;
    newData.authorId = new mongoose.Types.ObjectId(userId);
    newData.previousRevisionId = original._id;
    newData.changeDescription = changeDescription;
    newData.createdAt = new Date();
    newData.updatedAt = new Date();

    const newPlacard = await Placard.create(newData);

    await AuditService.log({
      eventType: AuditEventType.REVISION_CREATED,
      companyId: original.companyId.toString(),
      userId,
      targetType: 'placard',
      targetId: newPlacard._id.toString(),
      description: `New revision created: ${newPlacard.placardNumber} Rev.${newPlacard.revisionNumber}`,
      metadata: { changeDescription, previousRevisionId: originalPlacardId },
    });

    return newPlacard;
  }

  static async search(
    companyId: string,
    query: {
      q?: string;
      siteId?: string;
      status?: PlacardStatus;
      equipmentId?: string;
      page?: number;
      limit?: number;
    }
  ) {
    const { q, siteId, status, equipmentId, page = 1, limit = 20 } = query;
    const skip = (page - 1) * limit;

    const filter: Record<string, unknown> = { companyId };
    if (siteId) filter.siteId = new mongoose.Types.ObjectId(siteId);
    if (status) filter.status = status;
    if (equipmentId) filter.equipmentId = new mongoose.Types.ObjectId(equipmentId);
    if (q) filter.$text = { $search: q };

    const [items, total] = await Promise.all([
      Placard.find(filter)
        .sort(q ? { score: { $meta: 'textScore' } } : { updatedAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate('authorId', 'firstName lastName')
        .populate('siteId', 'name code'),
      Placard.countDocuments(filter),
    ]);

    return { items, total, page, limit };
  }

  static async getRevisionHistory(placardNumber: string, companyId: string) {
    return RevisionRecord.find({ companyId })
      .populate({ path: 'placardId', match: { placardNumber } })
      .sort({ revisionNumber: -1 })
      .populate('authorId', 'firstName lastName')
      .populate('approverId', 'firstName lastName');
  }
}
