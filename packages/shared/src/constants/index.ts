// ============================================================
// Shared Constants
// ============================================================

export const PLACARD_SERIAL_FORMAT = '{COMPANY}-{SITE}-LOTO-{SEQ6}';
// Example: SK-COI-LOTO-000042

export const REVISION_NUMBER_INITIAL = 1;

export const ENERGY_SOURCE_LABELS: Record<string, string> = {
  electrical: 'Electrical',
  pneumatic: 'Pneumatic',
  hydraulic: 'Hydraulic',
  gravity: 'Gravity',
  spring_tension: 'Spring Tension',
  steam: 'Steam',
  gas: 'Gas',
  thermal: 'Thermal',
  chemical: 'Chemical',
  vacuum: 'Vacuum',
  stored_mechanical: 'Stored Mechanical',
  kinetic: 'Kinetic',
  other: 'Other',
};

export const ENERGY_SOURCE_LABELS_ES: Record<string, string> = {
  electrical: 'Eléctrica',
  pneumatic: 'Neumática',
  hydraulic: 'Hidráulica',
  gravity: 'Gravedad',
  spring_tension: 'Tensión de Resorte',
  steam: 'Vapor',
  gas: 'Gas',
  thermal: 'Térmica',
  chemical: 'Química',
  vacuum: 'Vacío',
  stored_mechanical: 'Mecánica Almacenada',
  kinetic: 'Cinética',
  other: 'Otra',
};

export const PROCEDURE_PHASE_LABELS: Record<string, string> = {
  shutdown: 'Shutdown / Preparation',
  isolation: 'Energy Isolation',
  lockout: 'Lockout Application',
  stored_energy_release: 'Stored Energy Release',
  verification: 'Verification / Zero Energy',
  restart: 'Return to Service',
};

export const PROCEDURE_PHASE_LABELS_ES: Record<string, string> = {
  shutdown: 'Apagado / Preparación',
  isolation: 'Aislamiento de Energía',
  lockout: 'Aplicación de Candado',
  stored_energy_release: 'Liberación de Energía Almacenada',
  verification: 'Verificación / Energía Cero',
  restart: 'Retorno al Servicio',
};

export const LOCKOUT_DEVICE_LABELS: Record<string, string> = {
  lockout_hasp: 'Lockout Hasp',
  circuit_breaker_lockout: 'Circuit Breaker Lockout',
  gate_valve_lockout: 'Gate Valve Lockout',
  ball_valve_lockout: 'Ball Valve Lockout',
  plug_lockout: 'Plug Lockout',
  pneumatic_lockout: 'Pneumatic Lockout',
  hydraulic_lockout: 'Hydraulic Lockout',
  cylinder_lockout: 'Cylinder Lockout',
  cable_lockout: 'Cable Lockout',
  danger_tag: 'Danger Tag',
  other: 'Other',
};

export const DEFAULT_WARNINGS_EN = [
  'This procedure must be followed exactly as written.',
  'Do not attempt maintenance without proper lockout/tagout training.',
  'Each authorized employee must apply their own personal lock.',
  'Verify zero energy state before performing work.',
];

export const DEFAULT_WARNINGS_ES = [
  'Este procedimiento debe seguirse exactamente como está escrito.',
  'No intente realizar mantenimiento sin el entrenamiento adecuado de bloqueo/etiquetado.',
  'Cada empleado autorizado debe aplicar su propio candado personal.',
  'Verifique el estado de energía cero antes de realizar el trabajo.',
];

export const QR_BASE_URL_ENV_KEY = 'QR_BASE_URL';
export const DEFAULT_QR_BASE_URL = 'https://app.soteria-loto.com/q';

export const MAX_PHOTOS_PER_PLACARD = 12;
export const MAX_PHOTO_SIZE_BYTES = 10 * 1024 * 1024; // 10MB

export const SUPPORTED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
