# Soteria LOTO App

**Field-first Lockout/Tagout Procedure Management Platform**

Cal/OSHA Title 8 §3314 — Machine-Specific Energy Control Procedures

---

## Architecture Overview

```
soteria-loto-app/
├── apps/
│   ├── backend/          Node.js + Express + TypeScript API
│   ├── mobile/           React Native + Expo field app
│   └── web/              React web admin portal (Vite)
├── packages/
│   ├── shared/           Shared TypeScript types, constants, utilities
│   └── placard-engine/   PDF renderer + SnakKingPlacardTemplate
└── infra/
    └── docker/           Docker Compose for local dev
```

## Quick Start

### Prerequisites
- Node.js 20+
- MongoDB 7+ (or use Docker Compose)
- Yarn 1.22+

### 1. Clone and install
```bash
git clone https://github.com/devj1975/soteria-loto-app.git
cd soteria-loto-app
yarn install
```

### 2. Configure environment
```bash
cp apps/backend/.env.example apps/backend/.env
# Edit .env — set MONGODB_URI, JWT_SECRET, ANTHROPIC_API_KEY
```

### 3. Start MongoDB (Docker)
```bash
cd infra/docker && docker-compose up mongo -d
```

### 4. Seed database
```bash
cd apps/backend
yarn ts-node src/scripts/seed.ts
```
Default admin: `admin@snak-king.com` / `ChangeMe123!`

### 5. Start backend
```bash
cd apps/backend && yarn dev
# API: http://localhost:4000/api/v1
# Health: http://localhost:4000/health
```

### 6. Start web admin
```bash
cd apps/web && yarn dev
# Web: http://localhost:5173
```

### 7. Start mobile app
```bash
cd apps/mobile && yarn start
# Scan QR with Expo Go app
```

---

## Core Features

### Mobile Field App (React Native + Expo)
- 8-step guided walkdown wizard
- Camera-based photo capture for equipment, nameplates, isolation points
- Energy source selection with field detail entry
- Isolation point documentation
- AI-assisted procedure draft generation (Claude)
- Offline-first with local persistence and background sync

### Web Admin Portal (React + Vite)
- Placard list, search, and filter
- Approval queue with approve/reject workflow
- Placard detail view with PDF print buttons
- Equipment master management
- Site management
- Immutable audit trail

### Backend API (Node.js + Express)
- JWT auth with refresh token rotation
- Role-based access control (9 roles)
- Full CRUD for equipment, sites, placards
- AI draft generation via Claude API
- PDF generation with SnakKingPlacardTemplate
- QR code generation and token resolution
- Media upload with Sharp image processing
- Revision control with immutable snapshots
- Fire-and-forget audit logging

---

## Serialization Format

```
SK-COI-LOTO-000042
^  ^   ^    ^
|  |   |    └─ 6-digit zero-padded sequence (per site)
|  |   └────── "LOTO" literal
|  └────────── Site code (e.g. COI = City of Industry)
└───────────── Company slug (e.g. SK = Snak King)
```

---

## Placard Template — SnakKingPlacardTemplate

The first template (`SnakKingPlacardTemplate`) is designed to closely mimic an
existing Snak King industrial LOTO placard:

**Visual design intent:**
- Bold DANGER/PELIGRO header in safety red
- Company logo top-right
- Yellow warning banner below header
- 2-column machine info block (photo left, data table right)
- Red-header energy source table
- Horizontal photo strip for isolation points
- Red-accented numbered step blocks, grouped by procedure phase
- English instruction with Spanish below each step (bilingual mode)
- Green verification block
- Dark footer bar with revision metadata
- QR code bottom-right (1 inch, high error correction)
- Lamination-safe 0.375" margins

**Print formats:**
- English only PDF
- Spanish only PDF
- Dual-sided English/Spanish PDF
- QR posting sign

---

## API Reference

```
POST   /api/v1/auth/login
POST   /api/v1/auth/refresh
POST   /api/v1/auth/logout
GET    /api/v1/auth/me

GET    /api/v1/sites
POST   /api/v1/sites
GET    /api/v1/sites/:id/departments

GET    /api/v1/equipment?q=&siteId=&status=&page=&limit=
POST   /api/v1/equipment
GET    /api/v1/equipment/:id
PUT    /api/v1/equipment/:id

GET    /api/v1/placards?q=&status=&siteId=&page=&limit=
POST   /api/v1/placards
GET    /api/v1/placards/:id
PUT    /api/v1/placards/:id
POST   /api/v1/placards/:id/submit
POST   /api/v1/placards/:id/approve
POST   /api/v1/placards/:id/reject
POST   /api/v1/placards/:id/revise
GET    /api/v1/placards/:placardNumber/history
GET    /api/v1/placards/:id/audit

POST   /api/v1/ai/draft
POST   /api/v1/ai/translate
POST   /api/v1/ai/review

POST   /api/v1/media/upload
DELETE /api/v1/media/:id

GET    /api/v1/qr/:token
GET    /api/v1/qr/:token/image

GET    /api/v1/print/:placardId?format=placard_en|placard_es|dual_sided|qr_posting_sign

GET    /api/v1/audit
```

---

## Roles

| Role | Description |
|------|-------------|
| `super_admin` | Full platform access |
| `corporate_safety_admin` | Cross-site admin |
| `site_admin` | Site-level admin |
| `ehs_manager` | EHS workflow + reports |
| `maintenance_manager` | Equipment + placard view |
| `procedure_author` | Create and edit drafts |
| `reviewer` | Review and flag placards |
| `approver` | Final approval authority |
| `read_only` | View approved placards only |

---

## 60-Day Build Roadmap

### Sprint 1 (Days 1–14): Foundation ✓
- [x] Monorepo structure
- [x] Shared type library
- [x] Backend: auth, RBAC, MongoDB models
- [x] Backend: equipment, site, placard APIs
- [x] Backend: AI service with Claude prompts
- [x] Backend: media upload pipeline
- [x] Backend: QR service
- [x] PDF engine: SnakKingPlacardTemplate
- [x] Mobile: project structure + navigation
- [x] Mobile: login screen
- [x] Mobile: walkdown wizard (8 steps)
- [x] Mobile: offline store + sync service
- [x] Web: admin layout + routing
- [x] Web: approval queue
- [x] Web: placard list + detail

### Sprint 2 (Days 15–28): Polish & Integration
- [ ] Mobile: QR scanner screen
- [ ] Mobile: placard search screen
- [ ] Web: full placard editor
- [ ] Web: equipment CRUD
- [ ] Web: site/department management
- [ ] Spanish translation workflow
- [ ] Dual-sided PDF with pdf-lib merge
- [ ] Photo annotation tool

### Sprint 3 (Days 29–42): Testing & Hardening
- [ ] Unit tests (Jest)
- [ ] Integration tests
- [ ] Offline/sync edge case handling
- [ ] Performance optimization
- [ ] Security audit
- [ ] Mobile beta build (EAS)

### Sprint 4 (Days 43–56): Production Prep
- [ ] S3 media storage integration
- [ ] Production Docker setup
- [ ] Observability (Winston + structured logging)
- [ ] Error monitoring (Sentry stub)
- [ ] CI/CD pipeline
- [ ] User acceptance testing

### Sprint 5 (Days 57–60): Launch
- [ ] Production deployment
- [ ] Admin user onboarding
- [ ] Field pilot
- [ ] Feedback integration

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Mobile | React Native 0.73 + Expo 50 |
| Web Admin | React 18 + Vite + TanStack Query |
| Backend | Node.js 20 + Express 4 + TypeScript |
| Database | MongoDB 7 + Mongoose 8 |
| AI | Anthropic Claude API (claude-sonnet-4-6) |
| PDF | PDFKit 0.14 |
| QR | qrcode npm package |
| Media | Sharp + S3 (or local) |
| Auth | JWT + bcryptjs |
| State (mobile) | Zustand + AsyncStorage |
| Offline | expo-sqlite + NetInfo |

---

## Important Notes

1. **AI is a drafting tool only** — all AI-generated content must be reviewed and approved by a qualified EHS professional before use in LOTO operations.

2. **Compliance disclaimer** — this software supports documentation workflows but does not constitute legal or compliance advice. Consult with your EHS/legal team for Cal/OSHA compliance requirements.

3. **Placard template** — the `SnakKingPlacardTemplate` is designed to match an existing Snak King placard style. Additional templates can be created in the `PlacardTemplate` collection.

4. **Multi-tenancy** — the system is designed for multi-company use. Each company has its own slug, site codes, and placard sequences. The `SnakKingPlacardTemplate` can be cloned and customized for additional clients.
