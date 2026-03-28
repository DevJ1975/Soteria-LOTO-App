/**
 * Soteria LOTO — Self-Contained Demo Server
 * Uses in-memory storage so no MongoDB is needed.
 * Demonstrates the full REST API and web portal.
 */
import express from 'express';
import cors from 'cors';
import path from 'path';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';

const app = express();
const PORT = 4000;
const JWT_SECRET = 'demo_secret_key_soteria_loto_2024';
const WEB_DIST = path.resolve(__dirname, '../../web/dist');

app.use(cors({ origin: '*' }));
app.use(express.json({ limit: '10mb' }));
app.use(express.static(WEB_DIST));

// ─── In-memory store ────────────────────────────────────────
const hashedPw = bcrypt.hashSync('SoteriaDemo1!', 10);
const COMPANY_ID = 'co_snak_king';
const SITE_ID = 'site_coi';
const ADMIN_ID = 'user_admin';

const store = {
  users: [
    { _id: ADMIN_ID, email: 'admin@snak-king.com', password: hashedPw,
      firstName: 'John', lastName: 'Smith', role: 'approver',
      companyId: COMPANY_ID, siteIds: [SITE_ID], isActive: true },
    { _id: 'user_author', email: 'tech@snak-king.com', password: hashedPw,
      firstName: 'Maria', lastName: 'Garcia', role: 'procedure_author',
      companyId: COMPANY_ID, siteIds: [SITE_ID], isActive: true },
  ],
  sites: [
    { _id: SITE_ID, companyId: COMPANY_ID, name: 'City of Industry', code: 'COI',
      address: { city: 'City of Industry', state: 'CA', zip: '91748' }, isActive: true }
  ],
  equipment: [
    { _id: 'eq_001', companyId: COMPANY_ID, siteId: SITE_ID,
      equipmentId: 'MIX-003', commonName: 'Horizontal Mixer #3',
      formalName: 'Ribbon Blender / Horizontal Mixer', category: 'Mixer',
      manufacturer: 'Munson Machinery', model: 'RC-600', serialNumber: 'MUN-2019-4471',
      location: 'Line 3, East Building', department: 'Mixing',
      electricalVoltage: '480V 3-Phase', pneumaticPressure: '90 PSI',
      status: 'active', placardIds: ['plc_001'], currentPlacardId: 'plc_001',
      createdAt: new Date('2024-01-15') },
    { _id: 'eq_002', companyId: COMPANY_ID, siteId: SITE_ID,
      equipmentId: 'CNV-012', commonName: 'Transfer Conveyor #12',
      formalName: 'Belt Conveyor / Product Transfer', category: 'Conveyor',
      manufacturer: 'Hytrol', model: 'E24', serialNumber: 'HYT-2021-9934',
      location: 'Packaging Line 2', department: 'Packaging',
      electricalVoltage: '208V 3-Phase', status: 'active', placardIds: [],
      createdAt: new Date('2024-03-10') },
    { _id: 'eq_003', companyId: COMPANY_ID, siteId: SITE_ID,
      equipmentId: 'CMP-007', commonName: 'Air Compressor #7',
      formalName: 'Rotary Screw Air Compressor', category: 'Compressor',
      manufacturer: 'Ingersoll Rand', model: 'R11i', serialNumber: 'IR-2020-7823',
      location: 'Utility Room B', department: 'Maintenance',
      electricalVoltage: '460V 3-Phase', pneumaticPressure: '125 PSI',
      status: 'active', placardIds: [], createdAt: new Date('2024-02-20') },
  ],
  placards: [
    {
      _id: 'plc_001', companyId: COMPANY_ID, siteId: SITE_ID,
      placardNumber: 'SK-COI-LOTO-000001', revisionNumber: 2,
      revisionDate: new Date('2024-11-15'), equipmentId: 'eq_001',
      machineInfo: {
        equipmentId: 'MIX-003', commonName: 'Horizontal Mixer #3',
        formalName: 'Ribbon Blender / Horizontal Mixer',
        manufacturer: 'Munson Machinery', model: 'RC-600', serialNumber: 'MUN-2019-4471',
        location: 'Line 3, East Building', department: 'Mixing',
        electricalVoltage: '480V 3-Phase', pneumaticPressure: '90 PSI',
      },
      energySources: [
        { id: 'es1', type: 'electrical', description: '480V 3-Phase Motor Feed', voltage: '480V', location: 'MCC Panel A, Breaker D-47' },
        { id: 'es2', type: 'pneumatic', description: 'Compressed Air Supply to Pneumatic Actuators', pressure: '90 PSI', location: 'South wall, valve P-12' },
        { id: 'es3', type: 'gravity', description: 'Elevated 200lb Hopper Lid — gravity hazard when raised', location: 'Top of mixer housing' },
      ],
      isolationPoints: [
        { id: 'ip1', sequence: 1, description: 'Disconnect D-47 on Panel LP-3 (Main Motor Feed)', deviceType: 'circuit_breaker_lockout', location: 'MCC Panel A, East Wall', normalState: 'ON / CLOSED', isolatedState: 'OFF / OPEN', photoIds: [] },
        { id: 'ip2', sequence: 2, description: 'Pneumatic Isolation Valve P-12 at South Wall Manifold', deviceType: 'ball_valve_lockout', location: 'South wall, 4ft height', normalState: 'OPEN', isolatedState: 'CLOSED', photoIds: [] },
        { id: 'ip3', sequence: 3, description: 'Hopper Lid Mechanical Block — insert safety pin before working under lid', deviceType: 'other', location: 'Top of mixer, hopper hinge pin receptacle', normalState: 'RAISED / UNSUPPORTED', isolatedState: 'BLOCKED WITH SAFETY PIN', photoIds: [] },
      ],
      procedureSteps: [
        { id: 's1', sequence: 1, phase: 'shutdown', instruction: 'Notify all affected personnel that the Horizontal Mixer #3 is being taken out of service for maintenance.', instructionEs: 'Notifique a todo el personal afectado que la Mezcladora Horizontal #3 está siendo sacada de servicio para mantenimiento.', warnings: [], isRequired: true },
        { id: 's2', sequence: 2, phase: 'shutdown', instruction: 'Press the RED STOP button on the local control panel to bring the mixer to a complete stop. Confirm agitator ribbon has stopped rotating.', instructionEs: 'Presione el botón ROJO DE PARO en el panel de control local para detener completamente la mezcladora. Confirme que la cinta agitadora ha dejado de girar.', warnings: [], isRequired: true },
        { id: 's3', sequence: 3, phase: 'isolation', instruction: 'Locate Disconnect D-47 on MCC Panel A (East Wall). Verify switch is in ON position.', instructionEs: 'Localice el Desconectador D-47 en el Panel MCC A (Pared Este). Verifique que el interruptor esté en posición ENCENDIDO.', warnings: [], isRequired: true },
        { id: 's4', sequence: 4, phase: 'lockout', instruction: 'Turn Disconnect D-47 to the OFF position. Apply circuit breaker lockout device. Apply your personal lock. Tag with DANGER tag.', instructionEs: 'Gire el Desconectador D-47 a la posición APAGADO. Aplique el dispositivo de bloqueo del interruptor. Aplique su candado personal. Etiquete con etiqueta de PELIGRO.', warnings: ['Do not use another worker\'s lock under any circumstances.'], isRequired: true },
        { id: 's5', sequence: 5, phase: 'isolation', instruction: 'Locate Pneumatic Isolation Valve P-12 on south wall manifold (4ft height). Valve should be in OPEN position.', instructionEs: 'Localice la Válvula de Aislamiento Neumático P-12 en el manifold de la pared sur (altura 4 pies). La válvula debe estar en posición ABIERTA.', warnings: [], isRequired: true },
        { id: 's6', sequence: 6, phase: 'lockout', instruction: 'Turn Valve P-12 to CLOSED position. Apply ball valve lockout device. Apply your personal lock. Tag with DANGER tag.', instructionEs: 'Gire la Válvula P-12 a la posición CERRADA. Aplique el dispositivo de bloqueo de válvula de bola. Aplique su candado personal. Etiquete con etiqueta de PELIGRO.', warnings: [], isRequired: true },
        { id: 's7', sequence: 7, phase: 'stored_energy_release', instruction: 'Slowly open the manual bleed valve on the pneumatic line downstream of P-12 to release residual air pressure. Confirm pressure gauge reads ZERO before proceeding.', instructionEs: 'Abra lentamente la válvula de purga manual en la línea neumática aguas abajo de P-12 para liberar la presión de aire residual. Confirme que el manómetro lea CERO antes de continuar.', warnings: ['Residual pressure may remain for up to 30 seconds after isolation.'], isRequired: true },
        { id: 's8', sequence: 8, phase: 'stored_energy_release', instruction: 'If mixer hopper lid is raised, insert safety pin through hinge pin receptacle on top of mixer housing to prevent inadvertent lowering.', instructionEs: 'Si la tapa de la tolva de la mezcladora está levantada, inserte el pasador de seguridad a través del receptáculo del pasador de bisagra en la parte superior de la carcasa de la mezcladora para evitar el descenso inadvertido.', warnings: ['200 lb gravity hazard — never work under raised hopper lid without safety pin installed.'], isRequired: true },
        { id: 's9', sequence: 9, phase: 'verification', instruction: 'VERIFY ZERO ENERGY STATE: Attempt to start the mixer using the control panel START button. The mixer shall NOT start. If it starts, re-apply the lockout procedure immediately.', instructionEs: 'VERIFIQUE ESTADO DE ENERGÍA CERO: Intente arrancar la mezcladora usando el botón ARRANCAR del panel de control. La mezcladora NO debe arrancar. Si arranca, vuelva a aplicar el procedimiento de bloqueo inmediatamente.', warnings: ['All authorized employees must perform this verification independently.'], isRequired: true },
        { id: 's10', sequence: 10, phase: 'restart', instruction: 'Upon work completion, ensure all tools, materials, and personnel are clear of the equipment. Remove safety pin from hopper lid hinge if installed.', instructionEs: 'Al completar el trabajo, asegúrese de que todas las herramientas, materiales y personal estén alejados del equipo. Retire el pasador de seguridad de la bisagra de la tapa de la tolva si está instalado.', warnings: [], isRequired: true },
        { id: 's11', sequence: 11, phase: 'restart', instruction: 'Each authorized employee must remove their own personal lock from Disconnect D-47 and Valve P-12. Verify all locks and tags are removed.', instructionEs: 'Cada empleado autorizado debe retirar su propio candado personal del Desconectador D-47 y la Válvula P-12. Verifique que todos los candados y etiquetas hayan sido removidos.', warnings: ['Each employee removes only their own lock.'], isRequired: true },
        { id: 's12', sequence: 12, phase: 'restart', instruction: 'Notify affected personnel that maintenance is complete and the mixer is being returned to service. Re-energize by turning Disconnect D-47 to ON position.', instructionEs: 'Notifique al personal afectado que el mantenimiento está completo y que la mezcladora está siendo devuelta al servicio. Reenergice girando el Desconectador D-47 a la posición ENCENDIDO.', warnings: [], isRequired: true },
      ],
      warnings: [
        'This procedure must be followed exactly as written.',
        'Each authorized employee must apply their own personal lock.',
        'Do not remove any lock other than your own.',
        'Verify zero energy state before performing any work.',
      ],
      specialCautions: ['200 LB GRAVITY HAZARD: Hopper lid must be supported with safety pin when raised.'],
      requiredPPE: ['Safety Glasses', 'Safety-Toe Boots', 'Gloves (Cut-Resistant)', 'Hard Hat (if working near machinery)'],
      authorId: { _id: 'user_author', firstName: 'Maria', lastName: 'Garcia', email: 'tech@snak-king.com' },
      reviewerId: { _id: ADMIN_ID, firstName: 'John', lastName: 'Smith', email: 'admin@snak-king.com' },
      approverId: { _id: ADMIN_ID, firstName: 'John', lastName: 'Smith', email: 'admin@snak-king.com' },
      reviewDate: new Date('2024-11-20'),
      approvalDate: new Date('2024-11-22'),
      changeDescription: 'Rev 2: Added gravity hazard step for hopper lid.',
      status: 'approved', qrToken: 'DemoToken01',
      wasAIAssisted: true, language: 'en',
      createdAt: new Date('2024-11-10'), updatedAt: new Date('2024-11-22'),
    },
    {
      _id: 'plc_002', companyId: COMPANY_ID, siteId: SITE_ID,
      placardNumber: 'SK-COI-LOTO-000002', revisionNumber: 1,
      revisionDate: new Date('2024-12-01'),
      machineInfo: {
        equipmentId: 'CNV-012', commonName: 'Transfer Conveyor #12',
        formalName: 'Belt Conveyor / Product Transfer',
        manufacturer: 'Hytrol', model: 'E24',
        location: 'Packaging Line 2', electricalVoltage: '208V 3-Phase',
      },
      energySources: [
        { id: 'es1', type: 'electrical', description: '208V 3-Phase Drive Motor', voltage: '208V', location: 'Panel PK-2' },
      ],
      isolationPoints: [
        { id: 'ip1', sequence: 1, description: 'Breaker CB-24 on Panel PK-2', deviceType: 'circuit_breaker_lockout', location: 'Panel PK-2, Packaging Line 2', normalState: 'ON', isolatedState: 'OFF', photoIds: [] },
      ],
      procedureSteps: [
        { id: 's1', sequence: 1, phase: 'shutdown', instruction: 'Stop the conveyor using the local E-STOP button.', instructionEs: 'Detenga la banda transportadora usando el botón de PARO DE EMERGENCIA local.', warnings: [], isRequired: true },
        { id: 's2', sequence: 2, phase: 'lockout', instruction: 'Open Breaker CB-24 on Panel PK-2, apply lockout device and personal lock.', instructionEs: 'Abra el Breaker CB-24 en el Panel PK-2, aplique el dispositivo de bloqueo y su candado personal.', warnings: [], isRequired: true },
        { id: 's3', sequence: 3, phase: 'verification', instruction: 'Attempt to start the conveyor to verify zero energy state.', instructionEs: 'Intente arrancar la banda transportadora para verificar el estado de energía cero.', warnings: [], isRequired: true },
      ],
      warnings: ['This procedure must be followed exactly as written.'],
      specialCautions: [],
      requiredPPE: ['Safety Glasses', 'Safety-Toe Boots'],
      authorId: { _id: 'user_author', firstName: 'Maria', lastName: 'Garcia' },
      status: 'pending_approval',
      wasAIAssisted: true, language: 'en',
      createdAt: new Date('2024-12-01'), updatedAt: new Date('2024-12-01'),
    },
    {
      _id: 'plc_003', companyId: COMPANY_ID, siteId: SITE_ID,
      placardNumber: 'SK-COI-LOTO-000003', revisionNumber: 1,
      revisionDate: new Date('2024-12-05'),
      machineInfo: {
        equipmentId: 'CMP-007', commonName: 'Air Compressor #7',
        formalName: 'Rotary Screw Air Compressor',
        manufacturer: 'Ingersoll Rand', model: 'R11i',
        location: 'Utility Room B', electricalVoltage: '460V 3-Phase', pneumaticPressure: '125 PSI',
      },
      energySources: [
        { id: 'es1', type: 'electrical', description: '460V 3-Phase Compressor Motor', voltage: '460V' },
        { id: 'es2', type: 'pneumatic', description: 'Stored compressed air in receiver tank', pressure: '125 PSI' },
        { id: 'es3', type: 'thermal', description: 'Residual heat from compressor components — allow 15 min cooldown' },
      ],
      isolationPoints: [],
      procedureSteps: [],
      warnings: [],
      specialCautions: [],
      requiredPPE: ['Safety Glasses', 'Heat-Resistant Gloves'],
      authorId: { _id: 'user_author', firstName: 'Maria', lastName: 'Garcia' },
      status: 'draft',
      wasAIAssisted: false, language: 'en',
      createdAt: new Date('2024-12-05'), updatedAt: new Date('2024-12-05'),
    },
  ],
  auditEvents: [
    { _id: 'a1', eventType: 'placard_approved', companyId: COMPANY_ID, userId: { email: 'admin@snak-king.com' }, description: 'Placard approved: SK-COI-LOTO-000001 Rev.2', createdAt: new Date('2024-11-22T14:32:00') },
    { _id: 'a2', eventType: 'placard_created', companyId: COMPANY_ID, userId: { email: 'tech@snak-king.com' }, description: 'Placard draft created: SK-COI-LOTO-000002', createdAt: new Date('2024-12-01T09:15:00') },
    { _id: 'a3', eventType: 'ai_draft_generated', companyId: COMPANY_ID, userId: { email: 'tech@snak-king.com' }, description: 'AI draft generated for Transfer Conveyor #12', createdAt: new Date('2024-12-01T09:18:00') },
    { _id: 'a4', eventType: 'placard_submitted', companyId: COMPANY_ID, userId: { email: 'tech@snak-king.com' }, description: 'Placard submitted for approval: SK-COI-LOTO-000002', createdAt: new Date('2024-12-01T10:05:00') },
    { _id: 'a5', eventType: 'user_login', companyId: COMPANY_ID, userId: { email: 'admin@snak-king.com' }, description: 'User admin@snak-king.com logged in', createdAt: new Date('2024-12-05T08:00:00') },
  ],
};

// ─── Auth middleware ─────────────────────────────────────────
function auth(req: any, res: any, next: any) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ success: false, message: 'Authentication required' });
  try {
    const payload = jwt.verify(token, JWT_SECRET) as any;
    req.user = payload;
    next();
  } catch {
    res.status(401).json({ success: false, message: 'Invalid token' });
  }
}

const ok = (res: any, data: any, msg?: string) => res.json({ success: true, data, message: msg });
const paginated = (res: any, data: any[], total: number, page: number, limit: number) =>
  res.json({ success: true, data, pagination: { page, limit, total, totalPages: Math.ceil(total / limit) } });
const err = (res: any, msg: string, code = 400) => res.status(code).json({ success: false, message: msg });

// ─── AUTH ────────────────────────────────────────────────────
app.post('/api/v1/auth/login', (req, res) => {
  const { email, password } = req.body;
  const user = store.users.find(u => u.email === email?.toLowerCase());
  if (!user || !bcrypt.compareSync(password, user.password)) return err(res, 'Invalid email or password', 401);
  const payload = { userId: user._id, email: user.email, role: user.role, companyId: user.companyId, siteIds: user.siteIds };
  const accessToken = jwt.sign(payload, JWT_SECRET, { expiresIn: '8h' });
  const { password: _, ...userOut } = user;
  return ok(res, { accessToken, refreshToken: 'demo_refresh', user: userOut });
});

app.get('/api/v1/auth/me', auth, (req: any, res) => {
  const user = store.users.find(u => u._id === req.user.userId);
  if (!user) return err(res, 'Not found', 404);
  const { password: _, ...u } = user;
  return ok(res, { ...u, companyId: { _id: COMPANY_ID, name: 'Snak King Corp.', slug: 'SK', settings: { enableBilingual: true } } });
});

app.post('/api/v1/auth/logout', auth, (_req, res) => ok(res, null, 'Logged out'));
app.post('/api/v1/auth/refresh', (_req, res) => {
  const accessToken = jwt.sign({ userId: ADMIN_ID, email: 'admin@snak-king.com', role: 'approver', companyId: COMPANY_ID, siteIds: [SITE_ID] }, JWT_SECRET, { expiresIn: '8h' });
  return ok(res, { accessToken });
});

// ─── SITES ───────────────────────────────────────────────────
app.get('/api/v1/sites', auth, (_req, res) => ok(res, store.sites));

// ─── EQUIPMENT ───────────────────────────────────────────────
app.get('/api/v1/equipment', auth, (req, res) => {
  const q = (req.query.q as string)?.toLowerCase();
  let items = store.equipment.filter(e => e.companyId === COMPANY_ID);
  if (q) items = items.filter(e => e.commonName.toLowerCase().includes(q) || e.equipmentId.toLowerCase().includes(q));
  const page = parseInt(req.query.page as string) || 1;
  const limit = parseInt(req.query.limit as string) || 20;
  return paginated(res, items.slice((page-1)*limit, page*limit), items.length, page, limit);
});

app.get('/api/v1/equipment/:id', auth, (req, res) => {
  const eq = store.equipment.find(e => e._id === req.params.id);
  return eq ? ok(res, eq) : err(res, 'Not found', 404);
});

// ─── PLACARDS ────────────────────────────────────────────────
app.get('/api/v1/placards', auth, (req, res) => {
  const q = (req.query.q as string)?.toLowerCase();
  const status = req.query.status as string;
  let items = store.placards.filter(p => p.companyId === COMPANY_ID);
  if (q) items = items.filter(p => p.placardNumber.toLowerCase().includes(q) || p.machineInfo.commonName.toLowerCase().includes(q));
  if (status) items = items.filter(p => p.status === status);
  const page = parseInt(req.query.page as string) || 1;
  const limit = parseInt(req.query.limit as string) || 20;
  return paginated(res, items.slice((page-1)*limit, page*limit), items.length, page, limit);
});

app.get('/api/v1/placards/:id', auth, (req, res) => {
  const p = store.placards.find(p => p._id === req.params.id);
  return p ? ok(res, p) : err(res, 'Not found', 404);
});

app.post('/api/v1/placards/:id/approve', auth, (req, res) => {
  const idx = store.placards.findIndex(p => p._id === req.params.id);
  if (idx === -1) return err(res, 'Not found', 404);
  (store.placards[idx] as any).status = 'approved';
  (store.placards[idx] as any).approvalDate = new Date();
  (store.placards[idx] as any).qrToken = 'DemoToken0' + (idx + 2);
  store.auditEvents.unshift({ _id: crypto.randomUUID(), eventType: 'placard_approved', companyId: COMPANY_ID, userId: { email: 'admin@snak-king.com' }, description: `Placard approved: ${store.placards[idx].placardNumber}`, createdAt: new Date() });
  return ok(res, store.placards[idx], 'Placard approved');
});

app.post('/api/v1/placards/:id/reject', auth, (req, res) => {
  const idx = store.placards.findIndex(p => p._id === req.params.id);
  if (idx === -1) return err(res, 'Not found', 404);
  (store.placards[idx] as any).status = 'rejected';
  return ok(res, store.placards[idx], 'Placard rejected');
});

// ─── QR ──────────────────────────────────────────────────────
app.get('/api/v1/qr/:token', (req, res) => {
  const placard = store.placards.find(p => (p as any).qrToken === req.params.token);
  if (!placard) return err(res, 'Not found', 404);
  return ok(res, { placard, qrRecord: { token: req.params.token, scanCount: 12 } });
});

// ─── AUDIT ────────────────────────────────────────────────────
app.get('/api/v1/audit', auth, (req, res) => {
  const page = parseInt(req.query.page as string) || 1;
  const limit = parseInt(req.query.limit as string) || 100;
  const items = [...store.auditEvents].sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  return paginated(res, items.slice((page-1)*limit, page*limit), items.length, page, limit);
});

// ─── AI (demo stub) ──────────────────────────────────────────
app.post('/api/v1/ai/draft', auth, (req, res) => {
  const { machineInfo } = req.body;
  return ok(res, {
    machineSummary: `${machineInfo?.commonName ?? 'Equipment'} — AI-generated procedure draft`,
    energySources: [{ type: 'electrical', description: 'Main motor feed', aiGenerated: true }],
    shutdownSteps: [{ sequence: 1, instruction: 'Bring equipment to a complete stop using normal shutdown procedure.', aiGenerated: true }],
    isolationSteps: [{ sequence: 1, instruction: 'Locate and open main disconnect.', aiGenerated: true }],
    lockoutSteps: [{ sequence: 1, instruction: 'Apply lockout device and personal lock to disconnect.', aiGenerated: true }],
    storedEnergySteps: [{ sequence: 1, instruction: 'Release all stored energy — bleed pneumatics, support gravity loads.', aiGenerated: true }],
    verificationSteps: [{ sequence: 1, instruction: 'Attempt to start equipment to verify zero energy state.', aiGenerated: true }],
    restartSteps: [{ sequence: 1, instruction: 'Remove all locks, notify affected personnel, return to service.', aiGenerated: true }],
    warnings: ['This is an AI-generated draft — must be reviewed by qualified EHS professional before use.'],
    assumptions: ['Assumed single electrical energy source — verify all energy sources present'],
    missingInfoFlags: ['Specific disconnect number not confirmed', 'Verify all stored energy types'],
    reviewRequired: ['Human verification of all isolation points required before approval'],
    confidenceScore: 0.62,
    confidenceNotes: 'Moderate confidence — missing specific disconnect IDs and site verification',
  }, 'AI draft generated — review all content before proceeding');
});

// ─── Serve web frontend for all other routes ─────────────────
app.get('*', (req, res) => {
  if (req.path.startsWith('/api/')) return err(res, 'Not found', 404);
  res.sendFile(path.join(WEB_DIST, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`\n╔══════════════════════════════════════════════════╗`);
  console.log(`║       SOTERIA LOTO — DEMO SERVER RUNNING         ║`);
  console.log(`╠══════════════════════════════════════════════════╣`);
  console.log(`║  Web Admin Portal:  http://localhost:${PORT}        ║`);
  console.log(`║  API Health:        http://localhost:${PORT}/health  ║`);
  console.log(`╠══════════════════════════════════════════════════╣`);
  console.log(`║  Login:  admin@snak-king.com / SoteriaDemo1!     ║`);
  console.log(`║  Also:   tech@snak-king.com  / SoteriaDemo1!     ║`);
  console.log(`╠══════════════════════════════════════════════════╣`);
  console.log(`║  Demo data preloaded:                            ║`);
  console.log(`║    3 equipment records                           ║`);
  console.log(`║    3 placards (approved / pending / draft)       ║`);
  console.log(`║    Full 12-step LOTO procedure (English+Spanish) ║`);
  console.log(`╚══════════════════════════════════════════════════╝\n`);
});
