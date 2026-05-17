const MenuItem = require('../models/MenuItem');
const Category = require('../models/Category');
const { parseMenuExcel } = require('../utils/excelParser');

exports.listItems = async (req, res, next) => {
  try {
    const { category, q, available } = req.query;
    const filter = {};
    if (category) filter.category = category;
    if (available !== undefined) filter.available = available === 'true';
    if (q) filter.$text = { $search: q };
    const items = await MenuItem.find(filter).sort({ category: 1, name: 1 });
    res.json({ items });
  } catch (err) {
    next(err);
  }
};

exports.getItem = async (req, res, next) => {
  try {
    const item = await MenuItem.findById(req.params.id);
    if (!item) return res.status(404).json({ error: 'Item not found' });
    res.json({ item });
  } catch (err) {
    next(err);
  }
};

exports.createItem = async (req, res, next) => {
  try {
    const item = await MenuItem.create(req.body);
    res.status(201).json({ item });
  } catch (err) {
    next(err);
  }
};

exports.updateItem = async (req, res, next) => {
  try {
    const item = await MenuItem.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true,
    });
    if (!item) return res.status(404).json({ error: 'Item not found' });
    res.json({ item });
  } catch (err) {
    next(err);
  }
};

exports.deleteItem = async (req, res, next) => {
  try {
    const item = await MenuItem.findByIdAndDelete(req.params.id);
    if (!item) return res.status(404).json({ error: 'Item not found' });
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
};

exports.listCategories = async (_req, res, next) => {
  try {
    const cats = await Category.find().sort({ sortOrder: 1, name: 1 });
    res.json({ categories: cats });
  } catch (err) {
    next(err);
  }
};

exports.createCategory = async (req, res, next) => {
  try {
    const cat = await Category.create(req.body);
    res.status(201).json({ category: cat });
  } catch (err) {
    next(err);
  }
};

exports.bulkUpload = async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'Excel file required (field: file)' });
    const rows = parseMenuExcel(req.file.buffer);
    if (!rows.length) return res.status(400).json({ error: 'No rows parsed' });

    // Upsert by SKU when present, else by (name, category).
    const ops = rows.map((r) => {
      const filter = r.sku
        ? { sku: r.sku }
        : { name: r.name, category: r.category };
      return {
        updateOne: {
          filter,
          update: { $set: r },
          upsert: true,
        },
      };
    });
    const result = await MenuItem.bulkWrite(ops);
    res.json({
      inserted: result.upsertedCount || 0,
      modified: result.modifiedCount || 0,
      matched: result.matchedCount || 0,
      total: rows.length,
    });
  } catch (err) {
    next(err);
  }
};
