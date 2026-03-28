// ============================================================
// Placard Template Definition
// ============================================================

export interface IPlacardTemplate {
  _id: string;
  name: string;                // e.g. "SnakKingPlacardTemplate"
  displayName: string;         // e.g. "Snak King Industrial Placard"
  description?: string;
  companyId?: string;          // null = global/shared template
  isActive: boolean;

  // Layout config
  layout: ITemplateLayout;

  // Section order and config
  sections: ITemplateSection[];

  // Branding
  branding: ITemplateBranding;

  // Print config
  printConfig: ITemplatePrintConfig;

  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface ITemplateLayout {
  pageSize: 'letter' | 'legal' | 'a4';
  orientation: 'portrait' | 'landscape';
  marginsInches: { top: number; right: number; bottom: number; left: number };
  columnCount: 1 | 2;
  primaryColor: string;        // hex
  accentColor: string;         // hex
  headerColor: string;
  textColor: string;
  borderStyle: 'solid' | 'double' | 'none';
  fontFamily: string;
  fontSize: {
    heading: number;
    subheading: number;
    body: number;
    caption: number;
    small: number;
  };
}

export interface ITemplateSection {
  id: string;
  type: TemplateSectionType;
  label: string;
  labelEs?: string;
  isEnabled: boolean;
  order: number;
  config: Record<string, unknown>;
}

export enum TemplateSectionType {
  HEADER = 'header',
  MACHINE_INFO = 'machine_info',
  WARNING_BANNER = 'warning_banner',
  ENERGY_SOURCES = 'energy_sources',
  ISOLATION_POINTS = 'isolation_points',
  PROCEDURE_STEPS = 'procedure_steps',
  PHOTOS = 'photos',
  SPECIAL_CAUTIONS = 'special_cautions',
  PPE_REQUIREMENTS = 'ppe_requirements',
  VERIFICATION = 'verification',
  SIGNATURES = 'signatures',
  REVISION_METADATA = 'revision_metadata',
  QR_CODE = 'qr_code',
  FOOTER = 'footer',
}

export interface ITemplateBranding {
  logoUrl?: string;
  companyName?: string;
  headerTitle: string;         // e.g. "LOCKOUT / TAGOUT PROCEDURE"
  showCompanyLogo: boolean;
  showSiteInfo: boolean;
}

export interface ITemplatePrintConfig {
  supportsEnglishOnly: boolean;
  supportsSpanishOnly: boolean;
  supportsDualSided: boolean;
  supportsQRPostingSign: boolean;
  supportsCompactCard: boolean;
  defaultPrintFormat: string;
  lamination: boolean;         // visual cue for lamination-safe layout
}
