import mongoose from 'mongoose';
import { Equipment } from '../models/Equipment';
import { AuditService } from './audit.service';
import { AuditEventType, EquipmentStatus } from '@soteria/shared';

export class EquipmentService {
  static async create(data: Record<string, unknown>, userId: string) {
    const equipment = await Equipment.create({ ...data, createdBy: userId });
    await AuditService.log({
      eventType: AuditEventType.PLACARD_CREATED,
      companyId: equipment.companyId.toString(),
      userId,
      targetType: 'equipment',
      targetId: equipment._id.toString(),
      description: `Equipment created: ${equipment.commonName} (${equipment.equipmentId})`,
    });
    return equipment;
  }

  static async findById(id: string) {
    return Equipment.findById(id)
      .populate('siteId', 'name code')
      .populate('departmentId', 'name code')
      .populate('currentPlacardId', 'placardNumber revisionNumber status');
  }

  static async search(
    companyId: string,
    query: {
      q?: string;
      siteId?: string;
      status?: EquipmentStatus;
      category?: string;
      page?: number;
      limit?: number;
    }
  ) {
    const { q, siteId, status, category, page = 1, limit = 20 } = query;
    const skip = (page - 1) * limit;

    const filter: Record<string, unknown> = { companyId };
    if (siteId) filter.siteId = new mongoose.Types.ObjectId(siteId);
    if (status) filter.status = status;
    if (category) filter.category = { $regex: category, $options: 'i' };
    if (q) filter.$text = { $search: q };

    const [items, total] = await Promise.all([
      Equipment.find(filter)
        .sort(q ? { score: { $meta: 'textScore' } } : { commonName: 1 })
        .skip(skip)
        .limit(limit)
        .populate('siteId', 'name code'),
      Equipment.countDocuments(filter),
    ]);

    return { items, total, page, limit };
  }

  static async update(id: string, data: Record<string, unknown>, userId: string) {
    const equipment = await Equipment.findByIdAndUpdate(
      id,
      { $set: data },
      { new: true, runValidators: true }
    );
    if (!equipment) throw new Error('Equipment not found');
    return equipment;
  }

  static async linkPlacard(equipmentId: string, placardId: string) {
    await Equipment.findByIdAndUpdate(equipmentId, {
      currentPlacardId: placardId,
      $addToSet: { placardIds: placardId },
    });
  }
}
