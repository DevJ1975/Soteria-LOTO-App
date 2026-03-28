// ============================================================
// PDFRenderer — generates LOTO placard PDFs using PDFKit
//
// Rendering order follows the SnakKingPlacardTemplate section config.
// The renderer is template-driven: each section type has a dedicated
// render method. Changing section order in the template config changes
// the PDF layout automatically.
// ============================================================

import PDFDocument from 'pdfkit';
import { PassThrough } from 'stream';
import type { IPlacard, IPlacardTemplate } from '@soteria/shared';
import { ProcedurePhase, PROCEDURE_PHASE_LABELS, PROCEDURE_PHASE_LABELS_ES, TemplateSectionType } from '@soteria/shared';

const PT_PER_INCH = 72;

interface RenderOptions {
  language: 'en' | 'es' | 'dual';
  logoBuffer?: Buffer;
  photoBuffers?: Record<string, Buffer>; // mediaId -> image buffer
  qrBuffer?: Buffer;
}

export class PDFRenderer {
  private doc!: PDFKit.PDFDocument;
  private template: IPlacardTemplate;
  private placard: IPlacard;
  private opts: RenderOptions;
  private layout: IPlacardTemplate['layout'];

  // Running Y position on current page
  private y = 0;
  private pageWidth = 0;
  private pageHeight = 0;
  private marginLeft = 0;
  private marginRight = 0;
  private marginTop = 0;
  private marginBottom = 0;
  private contentWidth = 0;

  constructor(template: IPlacardTemplate, placard: IPlacard, opts: RenderOptions) {
    this.template = template;
    this.placard = placard;
    this.opts = opts;
    this.layout = template.layout as IPlacardTemplate['layout'];
  }

  async render(): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      this.doc = new PDFDocument({
        size: 'LETTER',
        margins: {
          top: (this.layout.marginsInches as { top: number }).top * PT_PER_INCH,
          bottom: (this.layout.marginsInches as { bottom: number }).bottom * PT_PER_INCH,
          left: (this.layout.marginsInches as { left: number }).left * PT_PER_INCH,
          right: (this.layout.marginsInches as { right: number }).right * PT_PER_INCH,
        },
        autoFirstPage: true,
        info: {
          Title: `LOTO Placard — ${this.placard.placardNumber}`,
          Author: 'Soteria LOTO App',
          Subject: 'Machine-Specific Energy Control Procedure',
        },
      });

      const chunks: Buffer[] = [];
      this.doc.on('data', (chunk: Buffer) => chunks.push(chunk));
      this.doc.on('end', () => resolve(Buffer.concat(chunks)));
      this.doc.on('error', reject);

      // Page dimensions
      const pageSize = this.doc.page;
      this.pageWidth = pageSize.width;
      this.pageHeight = pageSize.height;
      this.marginLeft = (this.layout.marginsInches as { left: number }).left * PT_PER_INCH;
      this.marginRight = (this.layout.marginsInches as { right: number }).right * PT_PER_INCH;
      this.marginTop = (this.layout.marginsInches as { top: number }).top * PT_PER_INCH;
      this.marginBottom = (this.layout.marginsInches as { bottom: number }).bottom * PT_PER_INCH;
      this.contentWidth = this.pageWidth - this.marginLeft - this.marginRight;
      this.y = this.marginTop;

      // Draw outer border — industrial document frame
      this.doc
        .rect(
          this.marginLeft - 4,
          this.marginTop - 4,
          this.contentWidth + 8,
          this.pageHeight - this.marginTop - this.marginBottom + 8
        )
        .lineWidth(3)
        .strokeColor(this.layout.primaryColor as string)
        .stroke();

      // Render sections in order
      const enabledSections = [...this.template.sections]
        .filter((s) => s.isEnabled)
        .sort((a, b) => a.order - b.order);

      for (const section of enabledSections) {
        this.renderSection(section);
      }

      this.doc.end();
    });
  }

  // ─── Section Dispatcher ──────────────────────────────────

  private renderSection(section: IPlacardTemplate['sections'][0]): void {
    switch (section.type) {
      case TemplateSectionType.HEADER:
        this.renderHeader(section);
        break;
      case TemplateSectionType.MACHINE_INFO:
        this.renderMachineInfo(section);
        break;
      case TemplateSectionType.ENERGY_SOURCES:
        this.renderEnergySources(section);
        break;
      case TemplateSectionType.PHOTOS:
        this.renderPhotos(section);
        break;
      case TemplateSectionType.WARNING_BANNER:
        this.renderWarningBanner(section);
        break;
      case TemplateSectionType.PPE_REQUIREMENTS:
        this.renderPPE(section);
        break;
      case TemplateSectionType.PROCEDURE_STEPS:
        this.renderProcedureSteps(section);
        break;
      case TemplateSectionType.VERIFICATION:
        this.renderVerification(section);
        break;
      case TemplateSectionType.SIGNATURES:
        this.renderSignatures(section);
        break;
      case TemplateSectionType.REVISION_METADATA:
        this.renderRevisionFooter(section);
        break;
      case TemplateSectionType.QR_CODE:
        this.renderQRCode(section);
        break;
    }
  }

  // ─── Header Section ───────────────────────────────────────

  private renderHeader(section: IPlacardTemplate['sections'][0]): void {
    const cfg = section.config as Record<string, unknown>;
    const x = this.marginLeft;
    const headerHeight = 85;

    // Header background — dark industrial
    this.doc.rect(x, this.y, this.contentWidth, headerHeight).fill(this.layout.headerColor as string);

    // DANGER badge on the left
    const dangerBadgeWidth = 130;
    this.doc
      .rect(x, this.y, dangerBadgeWidth, headerHeight)
      .fill(this.layout.primaryColor as string);

    this.doc
      .font('Helvetica-Bold')
      .fontSize((this.layout.fontSize as Record<string, number>).dangerHeader)
      .fillColor('#FFFFFF')
      .text('DANGER', x + 8, this.y + 8, { width: dangerBadgeWidth - 16, align: 'center' });

    this.doc
      .font('Helvetica-Bold')
      .fontSize(11)
      .fillColor('#FFFFFF')
      .text('PELIGRO', x + 8, this.y + 44, { width: dangerBadgeWidth - 16, align: 'center' });

    this.doc
      .font('Helvetica')
      .fontSize(9)
      .fillColor('#FFFFFF')
      .text('LOCKOUT/TAGOUT', x + 8, this.y + 62, { width: dangerBadgeWidth - 16, align: 'center' });

    // Title area — right of danger badge
    const titleX = x + dangerBadgeWidth + 10;
    const titleWidth = this.contentWidth - dangerBadgeWidth - 10 - (cfg.showCompanyLogo ? 110 : 10);

    this.doc
      .font('Helvetica-Bold')
      .fontSize(14)
      .fillColor('#FFFFFF')
      .text('MACHINE-SPECIFIC ENERGY CONTROL PROCEDURE', titleX, this.y + 10, {
        width: titleWidth,
        align: 'left',
      });

    this.doc
      .font('Helvetica')
      .fontSize(9)
      .fillColor('#FFD700')
      .text('PROCEDIMIENTO ESPECÍFICO DE CONTROL DE ENERGÍA', titleX, this.y + 32, {
        width: titleWidth,
        align: 'left',
      });

    // Site info
    const siteText = `Site: ${this.placard.machineInfo?.location ?? ''}`;
    this.doc
      .font('Helvetica')
      .fontSize(8)
      .fillColor('#CCCCCC')
      .text(siteText, titleX, this.y + 50, { width: titleWidth });

    // Logo — top right
    if (cfg.showCompanyLogo && this.opts.logoBuffer) {
      const logoX = x + this.contentWidth - 105;
      const logoY = this.y + 8;
      try {
        this.doc.image(this.opts.logoBuffer, logoX, logoY, { fit: [100, 68] });
      } catch {
        // Logo failed to load — skip silently
      }
    }

    this.y += headerHeight + 4;

    // Warning banner
    if (cfg.showWarningBanner) {
      const branding = this.template.branding as Record<string, unknown>;
      const bannerH = 32;
      this.doc
        .rect(x, this.y, this.contentWidth, bannerH)
        .fill('#FFD700');

      this.doc
        .font('Helvetica-Bold')
        .fontSize(8)
        .fillColor('#1A1A1A')
        .text(
          `⚠  ${branding.warningBannerText as string}`,
          x + 6,
          this.y + 5,
          { width: this.contentWidth - 12, align: 'center' }
        );

      if (this.opts.language === 'dual' || this.opts.language === 'es') {
        this.doc
          .font('Helvetica')
          .fontSize(7)
          .fillColor('#1A1A1A')
          .text(
            branding.warningBannerTextEs as string,
            x + 6,
            this.y + 18,
            { width: this.contentWidth - 12, align: 'center' }
          );
      }

      this.y += bannerH + 6;
    }
  }

  // ─── Machine Info Section ─────────────────────────────────

  private renderMachineInfo(_section: IPlacardTemplate['sections'][0]): void {
    const x = this.marginLeft;
    this.renderSectionHeader('MACHINE IDENTIFICATION', 'IDENTIFICACIÓN DE LA MÁQUINA');

    const photoWidth = 160;
    const infoWidth = this.contentWidth - photoWidth - 8;
    const blockH = 145;
    const blockY = this.y;

    // Photo block (left)
    this.doc
      .rect(x, blockY, photoWidth, blockH)
      .lineWidth(1)
      .strokeColor('#CCCCCC')
      .stroke();

    // Find equipment overview photo
    const overviewPhoto = Object.entries(this.opts.photoBuffers ?? {}).find(([id]) =>
      id.includes('overview')
    );

    if (overviewPhoto) {
      try {
        this.doc.image(overviewPhoto[1], x + 2, blockY + 2, { fit: [photoWidth - 4, blockH - 4] });
      } catch {
        this.doc.font('Helvetica').fontSize(8).fillColor('#999999')
          .text('Equipment Photo', x + 4, blockY + blockH / 2 - 10, { width: photoWidth - 8, align: 'center' });
      }
    } else {
      this.doc.font('Helvetica').fontSize(8).fillColor('#AAAAAA')
        .text('[Equipment Photo]', x + 4, blockY + blockH / 2 - 10, { width: photoWidth - 8, align: 'center' });
    }

    // Info table (right)
    const info = this.placard.machineInfo;
    const infoX = x + photoWidth + 8;
    const fields = [
      ['Equipment ID', info?.equipmentId ?? ''],
      ['Machine Name', info?.commonName ?? ''],
      ['Formal Name', info?.formalName ?? ''],
      ['Manufacturer', info?.manufacturer ?? ''],
      ['Model', info?.model ?? ''],
      ['Serial No.', info?.serialNumber ?? ''],
      ['Location', info?.location ?? ''],
      ['Dept.', info?.department ?? ''],
      ['Voltage', info?.electricalVoltage ?? ''],
      ['Air Pressure', info?.pneumaticPressure ?? ''],
    ];

    let rowY = blockY;
    const rowH = blockH / fields.length;

    for (const [label, value] of fields) {
      // Alternating row
      const isOdd = fields.indexOf([label, value]) % 2 === 1;
      if (isOdd) {
        this.doc.rect(infoX, rowY, infoWidth, rowH).fill('#F5F5F5');
      }

      this.doc
        .font('Helvetica-Bold')
        .fontSize(7)
        .fillColor('#555555')
        .text(label + ':', infoX + 3, rowY + 2, { width: 70 });

      this.doc
        .font('Helvetica')
        .fontSize(7.5)
        .fillColor('#1A1A1A')
        .text(value || '—', infoX + 76, rowY + 2, { width: infoWidth - 80 });

      rowY += rowH;
    }

    // Border around info block
    this.doc
      .rect(infoX, blockY, infoWidth, blockH)
      .lineWidth(0.5)
      .strokeColor('#CCCCCC')
      .stroke();

    this.y = blockY + blockH + 6;
  }

  // ─── Energy Sources Section ────────────────────────────────

  private renderEnergySources(_section: IPlacardTemplate['sections'][0]): void {
    const x = this.marginLeft;
    this.renderSectionHeader('HAZARDOUS ENERGY SOURCES', 'FUENTES DE ENERGÍA PELIGROSA');

    const sources = this.placard.energySources ?? [];
    if (sources.length === 0) {
      this.doc.font('Helvetica').fontSize(8).fillColor('#999999')
        .text('No energy sources specified.', x, this.y);
      this.y += 16;
      return;
    }

    // Table header
    const cols = [
      { label: 'TYPE / TIPO', width: 90 },
      { label: 'DESCRIPTION / DESCRIPCIÓN', width: 0 }, // flex
      { label: 'MAGNITUDE', width: 70 },
      { label: 'LOCATION / UBICACIÓN', width: 110 },
    ];
    const flexColWidth = this.contentWidth - cols.reduce((s, c) => s + c.width, 0);
    cols[1].width = flexColWidth;

    const rowH = 14;
    let colX = x;

    // Header row
    this.doc.rect(x, this.y, this.contentWidth, rowH).fill(this.layout.primaryColor as string);
    for (const col of cols) {
      this.doc
        .font('Helvetica-Bold')
        .fontSize(7)
        .fillColor('#FFFFFF')
        .text(col.label, colX + 2, this.y + 3, { width: col.width - 4 });
      colX += col.width;
    }
    this.y += rowH;

    // Data rows
    sources.forEach((source, idx) => {
      const rowBg = idx % 2 === 0 ? '#FFFFFF' : '#F9F9F9';
      this.doc.rect(x, this.y, this.contentWidth, rowH).fill(rowBg);

      colX = x;
      const values = [
        (source.type ?? '').toUpperCase().replace('_', ' '),
        source.description ?? '',
        source.voltage ?? source.pressure ?? (source as Record<string, unknown>).magnitude as string ?? '',
        (source as Record<string, unknown>).location as string ?? '',
      ];

      values.forEach((val, i) => {
        this.doc
          .font('Helvetica')
          .fontSize(7.5)
          .fillColor('#1A1A1A')
          .text(String(val), colX + 2, this.y + 3, { width: cols[i].width - 4 });
        colX += cols[i].width;
      });

      this.y += rowH;
    });

    // Table border
    this.doc
      .rect(x, this.y - rowH * (sources.length + 1), this.contentWidth, rowH * (sources.length + 1))
      .lineWidth(0.5)
      .strokeColor('#CCCCCC')
      .stroke();

    this.y += 6;
  }

  // ─── Photos Section ────────────────────────────────────────

  private renderPhotos(section: IPlacardTemplate['sections'][0]): void {
    const cfg = section.config as Record<string, unknown>;
    const maxPhotos = (cfg.maxPhotos as number) ?? 4;
    const photoH = (cfg.photoMaxHeight as number) ?? 90;

    const availablePhotos = Object.entries(this.opts.photoBuffers ?? {}).slice(0, maxPhotos);
    if (availablePhotos.length === 0) return;

    const x = this.marginLeft;
    this.renderSectionHeader(section.label, section.labelEs);

    const photoW = Math.floor((this.contentWidth - (availablePhotos.length - 1) * 6) / availablePhotos.length);
    let photoX = x;

    for (const [_id, buf] of availablePhotos) {
      this.doc.rect(photoX, this.y, photoW, photoH).lineWidth(0.5).strokeColor('#CCCCCC').stroke();
      try {
        this.doc.image(buf, photoX + 2, this.y + 2, { fit: [photoW - 4, photoH - 4] });
      } catch {
        // skip bad image
      }
      photoX += photoW + 6;
    }

    this.y += photoH + 8;
  }

  // ─── Warning Banner ───────────────────────────────────────

  private renderWarningBanner(_section: IPlacardTemplate['sections'][0]): void {
    const warnings = this.placard.warnings ?? [];
    const cautions = this.placard.specialCautions ?? [];
    const all = [...warnings, ...cautions];
    if (all.length === 0) return;

    const x = this.marginLeft;
    const bannerH = all.length * 12 + 16;

    this.doc
      .rect(x, this.y, this.contentWidth, bannerH)
      .fill('#FFF3CD');

    this.doc
      .rect(x, this.y, 4, bannerH)
      .fill(this.layout.primaryColor as string);

    this.doc
      .font('Helvetica-Bold')
      .fontSize(8)
      .fillColor('#856404')
      .text('⚠ WARNINGS / ADVERTENCIAS', x + 10, this.y + 5);

    let warnY = this.y + 17;
    for (const w of all) {
      this.doc.font('Helvetica').fontSize(7.5).fillColor('#1A1A1A')
        .text(`• ${w}`, x + 10, warnY, { width: this.contentWidth - 20 });
      warnY += 12;
    }

    this.y += bannerH + 6;
  }

  // ─── PPE Requirements ─────────────────────────────────────

  private renderPPE(_section: IPlacardTemplate['sections'][0]): void {
    const ppe = this.placard.requiredPPE ?? [];
    if (ppe.length === 0) return;

    const x = this.marginLeft;
    this.renderSectionHeader('REQUIRED PPE', 'EPP REQUERIDO');

    const ppeText = ppe.join('   •   ');
    this.doc
      .font('Helvetica-Bold')
      .fontSize(8)
      .fillColor('#1A1A1A')
      .text(ppeText, x, this.y, { width: this.contentWidth });
    this.y += 16;
  }

  // ─── Procedure Steps ──────────────────────────────────────

  private renderProcedureSteps(section: IPlacardTemplate['sections'][0]): void {
    const cfg = section.config as Record<string, unknown>;
    const steps = this.placard.procedureSteps ?? [];
    if (steps.length === 0) return;

    const x = this.marginLeft;
    this.renderSectionHeader(section.label, section.labelEs);

    // Group by phase
    const phases = Object.values(ProcedurePhase);

    for (const phase of phases) {
      const phaseSteps = steps.filter((s) => (s as Record<string, unknown>).phase === phase);
      if (phaseSteps.length === 0) continue;

      const phaseLabel = this.opts.language === 'es'
        ? PROCEDURE_PHASE_LABELS_ES[phase]
        : PROCEDURE_PHASE_LABELS[phase];

      // Phase header
      const phaseHeaderH = 14;
      this.doc.rect(x, this.y, this.contentWidth, phaseHeaderH).fill('#333333');
      this.doc
        .font('Helvetica-Bold')
        .fontSize(8)
        .fillColor('#FFFFFF')
        .text(phaseLabel.toUpperCase(), x + 8, this.y + 3);
      this.y += phaseHeaderH;

      for (const step of phaseSteps) {
        const s = step as Record<string, unknown>;
        const instruction = this.opts.language === 'es'
          ? (s.instructionEs as string || s.instruction as string)
          : (s.instruction as string);

        // Estimate step height
        const lines = this.estimateLines(instruction, this.contentWidth - 50, 8.5);
        const stepH = Math.max(20, lines * 11 + 8);

        // Step background
        this.doc.rect(x, this.y, this.contentWidth, stepH).fill('#F5F5F5');
        // Left accent bar
        this.doc.rect(x, this.y, 3, stepH).fill(this.layout.primaryColor as string);

        // Step number circle
        const numX = x + 10;
        const numY = this.y + stepH / 2 - 7;
        this.doc.circle(numX, numY + 7, 8).fill(this.layout.primaryColor as string);
        this.doc
          .font('Helvetica-Bold')
          .fontSize(8)
          .fillColor('#FFFFFF')
          .text(String(s.sequence), numX - 4, numY + 1, { width: 16, align: 'center' });

        // Instruction text
        this.doc
          .font('Helvetica')
          .fontSize(8.5)
          .fillColor('#1A1A1A')
          .text(instruction, x + 28, this.y + 5, { width: this.contentWidth - 36 });

        // Spanish text below if dual mode
        if (this.opts.language === 'dual' && s.instructionEs) {
          this.doc
            .font('Helvetica')
            .fontSize(7.5)
            .fillColor('#666666')
            .text(s.instructionEs as string, x + 28, this.y + 5 + lines * 11, {
              width: this.contentWidth - 36,
            });
        }

        // Warnings
        if ((s.warnings as string[])?.length > 0) {
          (s.warnings as string[]).forEach((w) => {
            this.doc.font('Helvetica').fontSize(7).fillColor('#CC0000')
              .text(`⚠ ${w}`, x + 28, this.y + stepH - 10, { width: this.contentWidth - 36 });
          });
        }

        this.y += stepH + 2;

        // Page break check
        if (this.y > this.pageHeight - this.marginBottom - 60) {
          this.doc.addPage();
          this.y = this.marginTop;
        }
      }

      this.y += 4;
    }
  }

  // ─── Verification Section ─────────────────────────────────

  private renderVerification(section: IPlacardTemplate['sections'][0]): void {
    const cfg = section.config as Record<string, unknown>;
    const x = this.marginLeft;
    const text = this.opts.language === 'es'
      ? (cfg.verificationTextEs as string)
      : (cfg.verificationText as string);

    const blockH = 36;
    this.doc.rect(x, this.y, this.contentWidth, blockH).fill('#E8F5E9');
    this.doc.rect(x, this.y, 4, blockH).fill('#2E7D32');

    this.doc
      .font('Helvetica-Bold')
      .fontSize(8)
      .fillColor('#1B5E20')
      .text('✓ VERIFICATION — ZERO ENERGY STATE', x + 10, this.y + 5);

    this.doc
      .font('Helvetica')
      .fontSize(7.5)
      .fillColor('#1A1A1A')
      .text(text ?? '', x + 10, this.y + 18, { width: this.contentWidth - 20 });

    this.y += blockH + 6;
  }

  // ─── Signatures ───────────────────────────────────────────

  private renderSignatures(_section: IPlacardTemplate['sections'][0]): void {
    const x = this.marginLeft;
    this.renderSectionHeader('PROCEDURE AUTHORIZATION', 'AUTORIZACIÓN');

    const colW = this.contentWidth / 3;
    const sigH = 40;
    const sigY = this.y;
    const labels = [
      ['Prepared By / Preparado Por', this.placard.authorId as unknown as string],
      ['Reviewed By / Revisado Por', this.placard.reviewerId as unknown as string],
      ['Approved By / Aprobado Por', this.placard.approverId as unknown as string],
    ];

    labels.forEach(([label], i) => {
      const colX = x + i * colW;
      this.doc.rect(colX, sigY, colW - 4, sigH).lineWidth(0.5).strokeColor('#CCCCCC').stroke();
      this.doc.font('Helvetica').fontSize(6.5).fillColor('#555555')
        .text(label, colX + 3, sigY + 3, { width: colW - 10 });
      // Signature line
      this.doc.moveTo(colX + 5, sigY + 28).lineTo(colX + colW - 10, sigY + 28)
        .lineWidth(0.5).strokeColor('#999999').stroke();
    });

    this.y += sigH + 6;
  }

  // ─── Revision Footer ──────────────────────────────────────

  private renderRevisionFooter(_section: IPlacardTemplate['sections'][0]): void {
    const x = this.marginLeft;
    const footerH = 24;
    const footerY = this.pageHeight - this.marginBottom - footerH - 30; // fixed position near bottom

    this.doc.rect(x, footerY, this.contentWidth - 80, footerH).fill('#1A1A1A');

    const formatDate = (d: Date | undefined) => d ? new Date(d).toLocaleDateString('en-US') : '—';

    const fields = [
      `Placard No.: ${this.placard.placardNumber ?? ''}`,
      `Rev: ${this.placard.revisionNumber ?? ''}`,
      `Rev Date: ${formatDate(this.placard.revisionDate)}`,
      `Approved: ${formatDate(this.placard.approvalDate)}`,
      this.placard.wasAIAssisted ? 'AI-Assisted Draft' : '',
    ].filter(Boolean);

    this.doc
      .font('Helvetica')
      .fontSize(7)
      .fillColor('#FFFFFF')
      .text(fields.join('    |    '), x + 6, footerY + 8, {
        width: this.contentWidth - 90,
        ellipsis: true,
      });
  }

  // ─── QR Code ──────────────────────────────────────────────

  private renderQRCode(section: IPlacardTemplate['sections'][0]): void {
    if (!this.opts.qrBuffer) return;

    const cfg = section.config as Record<string, unknown>;
    const size = (cfg.size as number) ?? 72;
    const x = this.marginLeft + this.contentWidth - size - 2;
    const y = this.pageHeight - this.marginBottom - size - 30;

    try {
      this.doc.image(this.opts.qrBuffer, x, y, { fit: [size, size] });
    } catch {
      // QR image failed
    }

    if (cfg.showScanLabel) {
      this.doc
        .font('Helvetica')
        .fontSize(6)
        .fillColor('#1A1A1A')
        .text(cfg.scanLabel as string, x - 4, y + size + 2, { width: size + 8, align: 'center' });
    }
  }

  // ─── Helpers ──────────────────────────────────────────────

  private renderSectionHeader(label: string, labelEs?: string): void {
    const x = this.marginLeft;
    const headerH = 14;

    this.doc.rect(x, this.y, this.contentWidth, headerH).fill('#333333');
    this.doc
      .font('Helvetica-Bold')
      .fontSize(8.5)
      .fillColor('#FFFFFF')
      .text(label.toUpperCase(), x + 6, this.y + 3);

    if (labelEs && (this.opts.language === 'dual' || this.opts.language === 'es')) {
      this.doc
        .font('Helvetica')
        .fontSize(7.5)
        .fillColor('#CCCCCC')
        .text(` / ${labelEs}`, x + 6 + this.doc.widthOfString(label.toUpperCase()) + 4, this.y + 3);
    }

    this.y += headerH + 3;
  }

  private estimateLines(text: string, width: number, fontSize: number): number {
    const charsPerLine = Math.floor(width / (fontSize * 0.55));
    return Math.max(1, Math.ceil(text.length / charsPerLine));
  }
}
