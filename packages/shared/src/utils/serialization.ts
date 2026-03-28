// ============================================================
// Placard Serial Number Generator
// Format: {COMPANY_SLUG}-{SITE_CODE}-LOTO-{SEQ6}
// Example: SK-COI-LOTO-000042
// ============================================================

export function buildPlacardNumber(
  companySlug: string,
  siteCode: string,
  sequence: number
): string {
  const seq = String(sequence).padStart(6, '0');
  return `${companySlug.toUpperCase()}-${siteCode.toUpperCase()}-LOTO-${seq}`;
}

export function parsePlacardNumber(placardNumber: string): {
  companySlug: string;
  siteCode: string;
  sequence: number;
} | null {
  const match = placardNumber.match(/^([A-Z]+)-([A-Z]+)-LOTO-(\d+)$/);
  if (!match) return null;
  return {
    companySlug: match[1],
    siteCode: match[2],
    sequence: parseInt(match[3], 10),
  };
}

export function buildRevisionLabel(revisionNumber: number): string {
  return `Rev. ${revisionNumber.toString().padStart(2, '0')}`;
}

export function buildQRToken(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
  let token = '';
  for (let i = 0; i < 12; i++) {
    token += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return token;
}
