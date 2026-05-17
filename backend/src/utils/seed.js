/**
 * Seed script: creates default users + loads the menu from `backend/data/menu.xlsx`.
 * Run with: npm run seed
 */
require('dotenv').config();
const fs = require('fs');
const connectDB = require('../config/db');
const User = require('../models/User');
const MenuItem = require('../models/MenuItem');
const Category = require('../models/Category');
const { loadFromFile, defaultMenuPath } = require('./menuImporter');

async function run() {
  await connectDB();

  // --- Users ---
  const seedUsers = [
    { name: 'Admin', email: 'admin@hunger.cafe', password: 'admin123', role: 'admin' },
    { name: 'Cashier 1', email: 'cashier@hunger.cafe', password: 'cashier123', role: 'cashier' },
    { name: 'Kitchen 1', email: 'kitchen@hunger.cafe', password: 'kitchen123', role: 'kitchen' },
  ];
  for (const u of seedUsers) {
    const exists = await User.findOne({ email: u.email });
    if (exists) {
      console.log(`User exists: ${u.email}`);
      continue;
    }
    const passwordHash = await User.hashPassword(u.password);
    await User.create({ ...u, passwordHash });
    console.log(`Created user: ${u.email} (${u.role})`);
  }

  // --- Menu items from data/menu.xlsx ---
  const menuPath = defaultMenuPath();
  if (!fs.existsSync(menuPath)) {
    console.warn(`\nNo menu file found at ${menuPath} — skipping menu seed.`);
  } else {
    const items = loadFromFile(menuPath);
    console.log(`\nLoaded ${items.length} menu items from ${menuPath}`);

    // --- Categories (derived from menu) ---
    const cats = [...new Set(items.map((i) => i.category))].sort();
    for (let i = 0; i < cats.length; i++) {
      await Category.updateOne(
        { name: cats[i] },
        { $setOnInsert: { name: cats[i], sortOrder: i } },
        { upsert: true }
      );
    }
    console.log(`Seeded ${cats.length} categories.`);

    // Bulk upsert menu items. Use SKU as the natural key.
    const ops = items.map((it) => ({
      updateOne: {
        filter: it.sku ? { sku: it.sku } : { name: it.name, category: it.category },
        update: { $set: it },
        upsert: true,
      },
    }));
    const result = await MenuItem.bulkWrite(ops);
    console.log(
      `Menu upsert — inserted: ${result.upsertedCount || 0}, ` +
        `modified: ${result.modifiedCount || 0}, matched: ${result.matchedCount || 0}.`
    );
  }

  console.log('\nDone. Default logins:');
  seedUsers.forEach((u) => console.log(`  ${u.role}: ${u.email} / ${u.password}`));
  process.exit(0);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
