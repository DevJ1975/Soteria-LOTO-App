// ============================================================
// Database Seed Script
// Creates initial company, site, admin user, and default template
// Run: ts-node src/scripts/seed.ts
// ============================================================

import mongoose from 'mongoose';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

import { Company } from '../models/Company';
import { Site } from '../models/Site';
import { User } from '../models/User';
import { PlacardTemplate } from '../models/PlacardTemplate';
import { UserRole } from '@soteria/shared';

async function seed() {
  await mongoose.connect(process.env.MONGODB_URI ?? 'mongodb://localhost:27017/soteria_loto');
  console.log('Connected to MongoDB');

  // ─── Company ──────────────────────────────────────────────
  let company = await Company.findOne({ slug: 'SK' });
  if (!company) {
    company = await Company.create({
      name: 'Snak King Corp.',
      slug: 'SK',
      isActive: true,
      settings: {
        defaultLanguage: 'en',
        enableBilingual: true,
        requireDualApproval: false,
        placardSerialPrefix: 'SK',
        qrAccessMode: 'authenticated',
      },
      placardSequences: {},
    });
    console.log('Created company: Snak King Corp. (SK)');
  }

  // ─── Site ─────────────────────────────────────────────────
  let site = await Site.findOne({ companyId: company._id, code: 'COI' });
  if (!site) {
    site = await Site.create({
      companyId: company._id,
      name: 'City of Industry',
      code: 'COI',
      address: { city: 'City of Industry', state: 'CA' },
      isActive: true,
    });
    console.log('Created site: City of Industry (COI)');
  }

  // ─── Super Admin User ─────────────────────────────────────
  const adminEmail = process.env.SEED_ADMIN_EMAIL ?? 'admin@snak-king.com';
  let admin = await User.findOne({ email: adminEmail });
  if (!admin) {
    admin = await User.create({
      email: adminEmail,
      password: process.env.SEED_ADMIN_PASSWORD ?? 'ChangeMe123!',
      firstName: 'System',
      lastName: 'Administrator',
      role: UserRole.SUPER_ADMIN,
      companyId: company._id,
      siteIds: [site._id],
      isActive: true,
    });
    console.log(`Created admin user: ${adminEmail}`);
  }

  // ─── Placard Template ─────────────────────────────────────
  const { SnakKingPlacardTemplate } = await import('@soteria/placard-engine');
  let template = await PlacardTemplate.findOne({ name: 'SnakKingPlacardTemplate' });
  if (!template) {
    template = await PlacardTemplate.create({
      ...SnakKingPlacardTemplate,
      companyId: company._id,
      createdBy: admin._id,
    });

    // Set as default template for company
    await Company.findByIdAndUpdate(company._id, {
      'settings.defaultTemplateId': template._id,
    });

    console.log('Created SnakKingPlacardTemplate');
  }

  console.log('\n✓ Seed complete');
  console.log(`  Company: ${company.name} (${company.slug})`);
  console.log(`  Site: ${site.name} (${site.code})`);
  console.log(`  Admin: ${adminEmail}`);
  console.log(`  Template: SnakKingPlacardTemplate`);

  await mongoose.disconnect();
}

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
