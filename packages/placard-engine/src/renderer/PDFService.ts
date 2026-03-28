// ============================================================
// PDFService — high-level interface for generating placard PDFs
// Handles template resolution, photo/QR fetching, and rendering
// ============================================================

import { PDFRenderer } from './PDFRenderer';
import type { IPlacard, IPlacardTemplate, PrintFormat } from '@soteria/shared';

export interface PDFGenerationOptions {
  placard: IPlacard;
  template: IPlacardTemplate;
  printFormat: PrintFormat;
  logoBuffer?: Buffer;
  photoBuffers?: Record<string, Buffer>;
  qrBuffer?: Buffer;
}

export class PDFService {
  /**
   * Generate a placard PDF buffer.
   *
   * printFormat determines language/layout:
   * - placard_en:  English single side
   * - placard_es:  Spanish single side
   * - dual_sided:  English + Spanish (two pages)
   * - qr_posting_sign: QR code + machine name only
   */
  static async generate(opts: PDFGenerationOptions): Promise<Buffer> {
    const { placard, template, printFormat, logoBuffer, photoBuffers, qrBuffer } = opts;

    switch (printFormat) {
      case 'placard_en':
        return new PDFRenderer(template, placard, {
          language: 'en',
          logoBuffer,
          photoBuffers,
          qrBuffer,
        }).render();

      case 'placard_es': {
        // Build Spanish placard: swap step instructions to Spanish versions
        const esPlaycard = PDFService.applySpanishContent(placard);
        return new PDFRenderer(template, esPlaycard, {
          language: 'es',
          logoBuffer,
          photoBuffers,
          qrBuffer,
        }).render();
      }

      case 'dual_sided': {
        // Page 1 = English, Page 2 = Spanish
        // PDFKit doesn't trivially support multi-document merge,
        // so we generate both and return the English version with
        // a note. In production, use pdf-lib to merge.
        // TODO: merge English + Spanish PDFs with pdf-lib
        return new PDFRenderer(template, placard, {
          language: 'dual',
          logoBuffer,
          photoBuffers,
          qrBuffer,
        }).render();
      }

      case 'qr_posting_sign':
        return PDFService.generateQRPostingSign(placard, qrBuffer);

      default:
        return new PDFRenderer(template, placard, {
          language: 'en',
          logoBuffer,
          photoBuffers,
          qrBuffer,
        }).render();
    }
  }

  /**
   * Generate a simple QR posting sign PDF.
   * This is a minimal 8.5x11 page with QR code, placard number,
   * and machine name — designed for printing and posting on a door/panel.
   */
  private static async generateQRPostingSign(
    placard: IPlacard,
    qrBuffer?: Buffer
  ): Promise<Buffer> {
    // Dynamic import to avoid circular dep
    const PDFDocument = (await import('pdfkit')).default;
    return new Promise((resolve, reject) => {
      const doc = new PDFDocument({ size: 'LETTER', margins: { top: 72, bottom: 72, left: 72, right: 72 } });
      const chunks: Buffer[] = [];
      doc.on('data', (c: Buffer) => chunks.push(c));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      // Header
      doc.rect(72, 72, 468, 60).fill('#CC0000');
      doc.font('Helvetica-Bold').fontSize(22).fillColor('#FFFFFF')
        .text('LOCKOUT / TAGOUT', 72, 82, { width: 468, align: 'center' });
      doc.font('Helvetica').fontSize(12).fillColor('#FFFFFF')
        .text('BLOQUEO / ETIQUETADO', 72, 110, { width: 468, align: 'center' });

      // Machine info
      doc.font('Helvetica-Bold').fontSize(18).fillColor('#1A1A1A')
        .text(placard.machineInfo?.commonName ?? '', 72, 160, { width: 468, align: 'center' });
      doc.font('Helvetica').fontSize(11).fillColor('#555555')
        .text(placard.machineInfo?.location ?? '', 72, 190, { width: 468, align: 'center' });
      doc.font('Helvetica').fontSize(10).fillColor('#555555')
        .text(`Placard: ${placard.placardNumber}  |  Rev. ${placard.revisionNumber}`, 72, 210, { width: 468, align: 'center' });

      // QR Code
      if (qrBuffer) {
        doc.image(qrBuffer, 215, 240, { fit: [180, 180] });
      }

      doc.font('Helvetica').fontSize(10).fillColor('#1A1A1A')
        .text('Scan for current procedure / Escanee para el procedimiento actual', 72, 440, { width: 468, align: 'center' });

      doc.end();
    });
  }

  /**
   * Apply Spanish translations to a placard for rendering.
   * Swaps English instructions for Spanish where available.
   */
  private static applySpanishContent(placard: IPlacard): IPlacard {
    const clone = JSON.parse(JSON.stringify(placard)) as IPlacard;
    clone.procedureSteps = clone.procedureSteps?.map((step) => ({
      ...step,
      instruction: (step as Record<string, unknown>).instructionEs as string || step.instruction,
    }));
    return clone;
  }
}
