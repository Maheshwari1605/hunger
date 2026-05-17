const XLSX = require('xlsx');

/**
 * Parse a menu Excel file (.xlsx/.xls/.csv).
 * Expected columns (case-insensitive, flexible):
 *   name, category, price, sku, description, tags, available, stock
 */
function parseMenuExcel(buffer) {
  const wb = XLSX.read(buffer, { type: 'buffer' });
  const sheet = wb.Sheets[wb.SheetNames[0]];
  const rows = XLSX.utils.sheet_to_json(sheet, { defval: '' });

  return rows
    .map((raw) => {
      const r = {};
      for (const k of Object.keys(raw)) r[k.trim().toLowerCase()] = raw[k];

      if (!r.name || r.price === '' || r.price === undefined) return null;

      const tags =
        typeof r.tags === 'string'
          ? r.tags
              .split(/[,;|]/)
              .map((t) => t.trim())
              .filter(Boolean)
          : Array.isArray(r.tags)
          ? r.tags
          : [];

      const available =
        r.available === '' || r.available === undefined
          ? true
          : ['true', 'yes', '1', 1, true].includes(
              typeof r.available === 'string'
                ? r.available.toLowerCase()
                : r.available
            );

      return {
        name: String(r.name).trim(),
        category: String(r.category || 'Uncategorized').trim(),
        price: Number(r.price),
        sku: r.sku ? String(r.sku).trim() : '',
        description: r.description ? String(r.description) : '',
        tags,
        available,
        stock:
          r.stock === '' || r.stock === undefined ? null : Number(r.stock),
      };
    })
    .filter(Boolean);
}

module.exports = { parseMenuExcel };
