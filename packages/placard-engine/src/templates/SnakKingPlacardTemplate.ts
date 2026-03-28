// ============================================================
// Phase 8 — SnakKingPlacardTemplate
//
// Visual intent:
// - Industrial documentation feel, NOT a modern app UI
// - Bold DANGER/LOCKOUT header in safety red/yellow
// - Structured 2-column layout for machine details
// - Clear step blocks with sequence numbers
// - Energy source table with icons/symbols
// - Photo blocks embedded directly in placard
// - Heavy borders and section rules (shop-floor readable)
// - Bilingual sections (English top, Spanish bottom in dual mode)
// - Revision metadata in a footer bar
// - QR code in bottom-right corner
// - Lamination-safe margins (0.375" all sides)
// ============================================================

import type { IPlacardTemplate } from '@soteria/shared';
import { TemplateSectionType } from '@soteria/shared';

export const SnakKingPlacardTemplate: Omit<IPlacardTemplate, '_id' | 'createdBy' | 'createdAt' | 'updatedAt'> = {
  name: 'SnakKingPlacardTemplate',
  displayName: 'Snak King Industrial LOTO Placard',
  description:
    'Industrial-style LOTO placard designed for Snak King manufacturing facilities. ' +
    'Features bold safety header, structured machine info block, energy source table, ' +
    'numbered step blocks, embedded photos, revision footer, and QR code.',
  companyId: undefined, // Will be set to Snak King company ID on seed
  isActive: true,

  layout: {
    pageSize: 'letter',       // 8.5" × 11"
    orientation: 'portrait',
    marginsInches: {
      top: 0.375,
      right: 0.375,
      bottom: 0.375,
      left: 0.375,
    },
    columnCount: 1,

    // Color palette — Cal/OSHA DANGER red and safety yellow/black
    primaryColor: '#CC0000',    // DANGER red
    accentColor: '#FFD700',     // Caution yellow
    headerColor: '#1A1A1A',     // Near-black header background
    sectionHeaderBg: '#333333', // Dark gray section headers
    sectionHeaderText: '#FFFFFF',
    textColor: '#1A1A1A',
    borderColor: '#333333',
    stepBlockBg: '#F5F5F5',     // Light gray step background
    warningBg: '#FFF3CD',       // Amber warning background
    energyTableHeaderBg: '#CC0000',
    energyTableHeaderText: '#FFFFFF',

    borderStyle: 'solid',
    borderWidth: 2,

    fontFamily: 'Helvetica',    // PDFKit built-in sans-serif
    fontSize: {
      dangerHeader: 28,          // "DANGER — LOCKOUT / TAGOUT"
      subHeader: 13,             // "LOCKOUT/TAGOUT PROCEDURE"
      machineName: 16,           // Large machine name
      sectionHeader: 10,         // "ENERGY SOURCES", "PROCEDURE STEPS", etc.
      body: 9,
      stepInstruction: 9,
      stepNumber: 11,
      caption: 8,
      small: 7,
      footerText: 7,
    },
  },

  branding: {
    headerTitle: 'DANGER — LOCKOUT / TAGOUT',
    subTitle: 'MACHINE-SPECIFIC ENERGY CONTROL PROCEDURE',
    companyName: 'Snak King Corp.',
    showCompanyLogo: true,
    showSiteInfo: true,
    // Logo is inserted top-right in the header block
    logoPosition: 'header_right',
    // Safety warning banner under header
    warningBannerText:
      'DO NOT start, energize, or use this equipment until this lockout/tagout procedure is complete and all locks are removed.',
    warningBannerTextEs:
      'NO inicie, energice ni use este equipo hasta que este procedimiento de bloqueo/etiquetado esté completo y todos los candados hayan sido removidos.',
  },

  // ─── Section order ─────────────────────────────────────────
  // This is the EXACT section order as rendered top-to-bottom
  // on the SnakKing placard.
  sections: [
    {
      id: 'header',
      type: TemplateSectionType.HEADER,
      label: 'Header',
      isEnabled: true,
      order: 1,
      config: {
        showDangerBadge: true,
        dangerBadgeColor: '#CC0000',
        showWarningBanner: true,
        logoMaxHeight: 48,
      },
    },
    {
      id: 'machine_info',
      type: TemplateSectionType.MACHINE_INFO,
      label: 'Machine Identification',
      labelEs: 'Identificación de la Máquina',
      isEnabled: true,
      order: 2,
      config: {
        // Two-column grid: left = machine photo, right = info table
        layout: 'photo_left_info_right',
        photoCategory: 'equipment_overview',
        photoMaxHeight: 140,
        infoFields: [
          { key: 'equipmentId', label: 'Equipment ID', labelEs: 'ID de Equipo' },
          { key: 'commonName', label: 'Machine Name', labelEs: 'Nombre de Máquina' },
          { key: 'manufacturer', label: 'Manufacturer', labelEs: 'Fabricante' },
          { key: 'model', label: 'Model', labelEs: 'Modelo' },
          { key: 'serialNumber', label: 'Serial No.', labelEs: 'No. Serie' },
          { key: 'location', label: 'Location', labelEs: 'Ubicación' },
          { key: 'department', label: 'Department', labelEs: 'Departamento' },
          { key: 'electricalVoltage', label: 'Voltage', labelEs: 'Voltaje' },
          { key: 'pneumaticPressure', label: 'Air Pressure', labelEs: 'Presión de Aire' },
        ],
        showNameplatephoto: true,
      },
    },
    {
      id: 'energy_sources',
      type: TemplateSectionType.ENERGY_SOURCES,
      label: 'Hazardous Energy Sources',
      labelEs: 'Fuentes de Energía Peligrosa',
      isEnabled: true,
      order: 3,
      config: {
        // Rendered as a compact table: Type | Description | Magnitude | Location
        layout: 'table',
        showEnergyIcons: true,
        tableColumns: ['type', 'description', 'magnitude', 'location'],
        headerBg: '#CC0000',
        headerText: '#FFFFFF',
        alternateRowBg: '#F9F9F9',
      },
    },
    {
      id: 'isolation_photos',
      type: TemplateSectionType.PHOTOS,
      label: 'Isolation Points — Photo Reference',
      labelEs: 'Puntos de Aislamiento — Referencia Fotográfica',
      isEnabled: true,
      order: 4,
      config: {
        photoCategories: ['isolation_point', 'disconnect'],
        maxPhotos: 4,
        // Horizontal strip layout: 2-3 photos side by side with captions
        layout: 'horizontal_strip',
        photoMaxHeight: 90,
        showCaptions: true,
      },
    },
    {
      id: 'warning_banner',
      type: TemplateSectionType.WARNING_BANNER,
      label: 'Warnings',
      labelEs: 'Advertencias',
      isEnabled: true,
      order: 5,
      config: {
        bg: '#FFF3CD',
        borderColor: '#CC0000',
        borderWidth: 2,
        showWarningIcon: true,
      },
    },
    {
      id: 'ppe_requirements',
      type: TemplateSectionType.PPE_REQUIREMENTS,
      label: 'Required PPE',
      labelEs: 'EPP Requerido',
      isEnabled: true,
      order: 6,
      config: {
        layout: 'horizontal_icons',
        showIcons: false,       // text-only for laminated placard clarity
      },
    },
    {
      id: 'procedure_steps',
      type: TemplateSectionType.PROCEDURE_STEPS,
      label: 'Lockout / Tagout Procedure',
      labelEs: 'Procedimiento de Bloqueo / Etiquetado',
      isEnabled: true,
      order: 7,
      config: {
        // Grouped by phase with bold phase headers
        groupByPhase: true,
        showPhaseHeaders: true,
        stepNumberStyle: 'circle',   // circled numbers like a manufacturing placard
        stepBg: '#F5F5F5',
        stepBorderLeft: '#CC0000',
        stepBorderWidth: 3,
        // In bilingual mode: English instruction, Spanish below in gray
        bilingualLayout: 'stacked',  // English on top, Spanish below each step
        phaseHeaderBg: '#333333',
        phaseHeaderText: '#FFFFFF',
      },
    },
    {
      id: 'verification',
      type: TemplateSectionType.VERIFICATION,
      label: 'Verification — Zero Energy State',
      labelEs: 'Verificación — Estado de Energía Cero',
      isEnabled: true,
      order: 8,
      config: {
        bg: '#E8F5E9',
        borderColor: '#2E7D32',
        verificationText:
          'After applying all locks, attempt to start/operate the equipment to verify isolation before beginning work.',
        verificationTextEs:
          'Después de aplicar todos los candados, intente arrancar/operar el equipo para verificar el aislamiento antes de comenzar el trabajo.',
      },
    },
    {
      id: 'signatures',
      type: TemplateSectionType.SIGNATURES,
      label: 'Procedure Authorization',
      labelEs: 'Autorización de Procedimiento',
      isEnabled: true,
      order: 9,
      config: {
        // Signature lines: Author | Reviewer | Approver
        showAuthor: true,
        showReviewer: true,
        showApprover: true,
        layout: 'three_column',
      },
    },
    {
      id: 'revision_metadata',
      type: TemplateSectionType.REVISION_METADATA,
      label: 'Revision Information',
      isEnabled: true,
      order: 10,
      config: {
        // Footer bar: Placard No. | Rev | Rev Date | Site
        layout: 'footer_bar',
        bg: '#1A1A1A',
        textColor: '#FFFFFF',
        fields: ['placardNumber', 'revisionNumber', 'revisionDate', 'approvalDate', 'site'],
        showAIAssistedFlag: true,
      },
    },
    {
      id: 'qr_code',
      type: TemplateSectionType.QR_CODE,
      label: 'QR Code',
      isEnabled: true,
      order: 11,
      config: {
        position: 'footer_right',
        size: 72,               // 72pt = 1 inch QR code on the placard
        showUrl: false,
        showScanLabel: true,
        scanLabel: 'Scan for digital copy',
        scanLabelEs: 'Escanee para copia digital',
      },
    },
  ],

  printConfig: {
    supportsEnglishOnly: true,
    supportsSpanishOnly: true,
    supportsDualSided: true,
    supportsQRPostingSign: true,
    supportsCompactCard: false,
    defaultPrintFormat: 'placard_en',
    lamination: true,          // Layout respects lamination-safe margins
  },
};
