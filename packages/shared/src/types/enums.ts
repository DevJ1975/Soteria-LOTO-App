// ============================================================
// Enumerations — shared domain vocabulary
// ============================================================

export enum UserRole {
  SUPER_ADMIN = 'super_admin',
  CORPORATE_SAFETY_ADMIN = 'corporate_safety_admin',
  SITE_ADMIN = 'site_admin',
  EHS_MANAGER = 'ehs_manager',
  MAINTENANCE_MANAGER = 'maintenance_manager',
  PROCEDURE_AUTHOR = 'procedure_author',
  REVIEWER = 'reviewer',
  APPROVER = 'approver',
  READ_ONLY = 'read_only',
}

export enum EnergySourceType {
  ELECTRICAL = 'electrical',
  PNEUMATIC = 'pneumatic',
  HYDRAULIC = 'hydraulic',
  GRAVITY = 'gravity',
  SPRING_TENSION = 'spring_tension',
  STEAM = 'steam',
  GAS = 'gas',
  THERMAL = 'thermal',
  CHEMICAL = 'chemical',
  VACUUM = 'vacuum',
  STORED_MECHANICAL = 'stored_mechanical',
  KINETIC = 'kinetic',
  OTHER = 'other',
}

export enum LockoutDeviceType {
  LOCKOUT_HASP = 'lockout_hasp',
  CIRCUIT_BREAKER_LOCKOUT = 'circuit_breaker_lockout',
  GATE_VALVE_LOCKOUT = 'gate_valve_lockout',
  BALL_VALVE_LOCKOUT = 'ball_valve_lockout',
  PLUG_LOCKOUT = 'plug_lockout',
  PNEUMATIC_LOCKOUT = 'pneumatic_lockout',
  HYDRAULIC_LOCKOUT = 'hydraulic_lockout',
  CYLINDER_LOCKOUT = 'cylinder_lockout',
  CABLE_LOCKOUT = 'cable_lockout',
  DANGER_TAG = 'danger_tag',
  OTHER = 'other',
}

export enum PlacardStatus {
  DRAFT = 'draft',
  PENDING_REVIEW = 'pending_review',
  IN_REVIEW = 'in_review',
  PENDING_APPROVAL = 'pending_approval',
  APPROVED = 'approved',
  SUPERSEDED = 'superseded',
  ARCHIVED = 'archived',
  REJECTED = 'rejected',
}

export enum ApprovalAction {
  SUBMIT_FOR_REVIEW = 'submit_for_review',
  APPROVE_REVIEW = 'approve_review',
  REJECT_REVIEW = 'reject_review',
  SUBMIT_FOR_APPROVAL = 'submit_for_approval',
  APPROVE = 'approve',
  REJECT = 'reject',
  ARCHIVE = 'archive',
}

export enum MediaCategory {
  EQUIPMENT_OVERVIEW = 'equipment_overview',
  NAMEPLATE = 'nameplate',
  ISOLATION_POINT = 'isolation_point',
  DISCONNECT = 'disconnect',
  STORED_ENERGY = 'stored_energy',
  FINAL_PLACARD = 'final_placard',
  REFERENCE = 'reference',
}

export enum Language {
  ENGLISH = 'en',
  SPANISH = 'es',
}

export enum PrintFormat {
  PLACARD_ENGLISH = 'placard_en',
  PLACARD_SPANISH = 'placard_es',
  DUAL_SIDED = 'dual_sided',
  FULL_PROCEDURE = 'full_procedure',
  QR_POSTING_SIGN = 'qr_posting_sign',
  COMPACT_CARD = 'compact_card',
}

export enum EquipmentStatus {
  ACTIVE = 'active',
  INACTIVE = 'inactive',
  DECOMMISSIONED = 'decommissioned',
  UNDER_MAINTENANCE = 'under_maintenance',
}

export enum AuditEventType {
  // Auth
  USER_LOGIN = 'user_login',
  USER_LOGOUT = 'user_logout',
  USER_CREATED = 'user_created',
  USER_UPDATED = 'user_updated',
  // Placard lifecycle
  PLACARD_CREATED = 'placard_created',
  PLACARD_UPDATED = 'placard_updated',
  PLACARD_SUBMITTED = 'placard_submitted',
  PLACARD_REVIEWED = 'placard_reviewed',
  PLACARD_APPROVED = 'placard_approved',
  PLACARD_REJECTED = 'placard_rejected',
  PLACARD_ARCHIVED = 'placard_archived',
  // Revision
  REVISION_CREATED = 'revision_created',
  REVISION_SUPERSEDED = 'revision_superseded',
  // Media
  MEDIA_UPLOADED = 'media_uploaded',
  MEDIA_DELETED = 'media_deleted',
  // QR
  QR_SCANNED = 'qr_scanned',
  // Print
  PRINT_REQUESTED = 'print_requested',
  PDF_EXPORTED = 'pdf_exported',
  // AI
  AI_DRAFT_GENERATED = 'ai_draft_generated',
  // Translation
  TRANSLATION_CREATED = 'translation_created',
  TRANSLATION_APPROVED = 'translation_approved',
}

export enum TranslationStatus {
  PENDING = 'pending',
  AUTO_TRANSLATED = 'auto_translated',
  HUMAN_REVIEWED = 'human_reviewed',
  APPROVED = 'approved',
}
