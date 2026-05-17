/**
 * Importer for `backend/data/menu.xlsx`.
 *
 * The source sheet has a header row: Sr.No | Item Name | Category | Veg | SMALL | medium | (cheese-small) | (cheese-medium)
 * Pricing columns are sparse — some items have only SMALL, others have all four.
 * We expand each spreadsheet row into one MenuItem per priced variant, e.g.:
 *
 *   Margherita Pizza  S=150 M=250 cheeseS=200 cheeseM=300
 *     → "Margherita Pizza — Small", "… Medium", "… Small (Cheese)", "… Medium (Cheese)"
 *
 * If a row has only the SMALL column, we keep the bare item name (no size suffix).
 */

const path = require('path');
const fs = require('fs');
const XLSX = require('xlsx');

// Variant labels for the four pricing columns.
const VARIANTS = [
  { col: 4, label: 'Small', cheese: false },
  { col: 5, label: 'Medium', cheese: false },
  { col: 6, label: 'Small', cheese: true },
  { col: 7, label: 'Medium', cheese: true },
];

// Map messy spreadsheet category strings to clean canonical names.
const CATEGORY_NORMALIZERS = [
  [/^pizza( maina)?\s*$/i, 'Pizza'],
  [/^special pizza\s*$/i, 'Special Pizza'],
  [/^hot coffee\s*$/i, 'Hot Coffee'],
  [/^cold coffee\s*$/i, 'Cold Coffee'],
  [/^cold drink\s*$/i, 'Cold Drinks'],
  [/^milkshakes?\s*$/i, 'Milkshakes'],
  [/^mojito\s*$/i, 'Mojitos'],
  [/^chai\s*$/i, 'Chai'],
  [/^burger\s*$/i, 'Burgers'],
  [/^sandwich\s*$/i, 'Sandwiches'],
  [/^vada pav\s*$/i, 'Vada Pav'],
  [/^dabeli\s*$/i, 'Dabeli'],
  [/^french fries\s*$/i, 'French Fries'],
  [/^maggi\s*$/i, 'Maggi'],
  [/^pasta\s*$/i, 'Pasta'],
  [/^momos\s*$/i, 'Momos'],
  [/^paratha\s*$/i, 'Paratha'],
  [/^chat\s*$/i, 'Chaat'],
  [/^combos\s*$/i, 'Combos'],
  [/^quick bites\s*$/i, 'Quick Bites'],
  [/^special brownie\s*$/i, 'Brownies'],
  [/^tippy\s*$/i, 'Tippy'],
];

function normalizeCategory(raw) {
  const s = String(raw || '').trim();
  if (!s) return 'Uncategorized';
  for (const [pattern, name] of CATEGORY_NORMALIZERS) {
    if (pattern.test(s)) return name;
  }
  // Fallback: title-case
  return s.replace(/\s+/g, ' ').replace(/\w\S*/g, (t) =>
    t[0].toUpperCase() + t.slice(1).toLowerCase()
  );
}

function titleCase(s) {
  return String(s || '')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\w\S*/g, (t) => t[0].toUpperCase() + t.slice(1).toLowerCase());
}

function isPrice(v) {
  if (v === '' || v === '-' || v === null || v === undefined) return false;
  const n = Number(v);
  return Number.isFinite(n) && n > 0;
}

/**
 * Parse the workbook into a list of MenuItem-shaped records.
 */
function loadFromBuffer(buffer) {
  const wb = XLSX.read(buffer);
  const ws = wb.Sheets[wb.SheetNames[0]];
  const rows = XLSX.utils.sheet_to_json(ws, {
    header: 1,
    defval: '',
    blankrows: false,
  });

  const out = [];
  // Skip the first two rows (header + spacer if any).
  for (let i = 1; i < rows.length; i++) {
    const r = rows[i];
    const name = String(r[1] || '').trim();
    if (!name) continue;
    // Skip rows that are themselves headers ("Sr. No.", "Item Name", etc.)
    if (/^(sr\.?\s*no\.?|item\s*name)$/i.test(name)) continue;

    const category = normalizeCategory(r[2]);
    const isVeg = /veg/i.test(String(r[3] || '')) && !/non/i.test(String(r[3] || ''));
    const baseName = titleCase(name);

    // Which variants are priced?
    const priced = VARIANTS.filter((v) => isPrice(r[v.col]));
    if (priced.length === 0) continue;

    // Distinguish single-variant items (no suffix) from multi-variant items.
    const singleVariant = priced.length === 1;

    for (const v of priced) {
      const variantBits = [];
      if (!singleVariant) variantBits.push(v.label);
      if (v.cheese) variantBits.push('Cheese');
      const displayName = variantBits.length
        ? `${baseName} — ${variantBits.join(', ')}`
        : baseName;

      const tags = [isVeg ? 'veg' : 'non-veg'];
      if (v.cheese) tags.push('cheese');
      if (!singleVariant) tags.push(v.label.toLowerCase());

      out.push({
        name: displayName,
        category,
        price: Number(r[v.col]),
        sku: `${category.replace(/\s+/g, '').toUpperCase()}-${baseName
          .replace(/[^A-Za-z0-9]/g, '')
          .toUpperCase()}${v.cheese ? '-CHZ' : ''}${
          singleVariant ? '' : '-' + v.label[0]
        }`,
        description: '',
        tags,
        available: true,
        stock: null,
      });
    }
  }
  return out;
}

function loadFromFile(filePath) {
  const buf = fs.readFileSync(filePath);
  return loadFromBuffer(buf);
}

function defaultMenuPath() {
  return path.join(__dirname, '..', '..', 'data', 'menu.xlsx');
}

module.exports = {
  loadFromBuffer,
  loadFromFile,
  defaultMenuPath,
  normalizeCategory,
};
