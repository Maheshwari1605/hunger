const jwt = require('jsonwebtoken');
const User = require('../models/User');

function signToken(user) {
  return jwt.sign(
    { sub: user._id.toString(), role: user.role, outletId: user.outletId },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '8h' }
  );
}

exports.register = async (req, res, next) => {
  try {
    const { name, email, password, role, outletId } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ error: 'name, email, password required' });
    }
    const existing = await User.findOne({ email: email.toLowerCase() });
    if (existing) return res.status(409).json({ error: 'Email already in use' });

    const passwordHash = await User.hashPassword(password);
    const user = await User.create({
      name,
      email,
      passwordHash,
      role: role || 'cashier',
      outletId: outletId || 'default',
    });
    const token = signToken(user);
    res.status(201).json({ token, user: user.toSafeJSON() });
  } catch (err) {
    next(err);
  }
};

exports.login = async (req, res, next) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'email and password required' });
    }
    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user || !user.active) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    const ok = await user.verifyPassword(password);
    if (!ok) return res.status(401).json({ error: 'Invalid credentials' });

    const token = signToken(user);
    res.json({ token, user: user.toSafeJSON() });
  } catch (err) {
    next(err);
  }
};

exports.me = async (req, res) => {
  res.json({ user: req.user.toSafeJSON() });
};

exports.listUsers = async (req, res, next) => {
  try {
    // Scope to the caller's outlet so admins of one cafe never see another's staff.
    const users = await User.find({ outletId: req.user.outletId }).sort({
      createdAt: -1,
    });
    res.json({ users: users.map((u) => u.toSafeJSON()) });
  } catch (err) {
    next(err);
  }
};

/**
 * Authenticated user changes their own password.
 * Body: { currentPassword, newPassword }
 */
exports.changePassword = async (req, res, next) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword) {
      return res
        .status(400)
        .json({ error: 'currentPassword and newPassword required' });
    }
    if (String(newPassword).length < 6) {
      return res
        .status(400)
        .json({ error: 'New password must be at least 6 characters' });
    }
    const user = await User.findById(req.user._id);
    if (!user) return res.status(404).json({ error: 'User not found' });

    const ok = await user.verifyPassword(currentPassword);
    if (!ok) {
      return res.status(401).json({ error: 'Current password is incorrect' });
    }

    user.passwordHash = await User.hashPassword(newPassword);
    await user.save();
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
};

/**
 * Admin creates a new staff user under the same outlet.
 * Body: { name, email, password, role }
 */
exports.createUser = async (req, res, next) => {
  try {
    const { name, email, password, role } = req.body;
    if (!name || !email || !password) {
      return res
        .status(400)
        .json({ error: 'name, email and password are required' });
    }
    if (!User.ROLES.includes(role)) {
      return res
        .status(400)
        .json({ error: `role must be one of ${User.ROLES.join(', ')}` });
    }
    if (String(password).length < 6) {
      return res
        .status(400)
        .json({ error: 'Password must be at least 6 characters' });
    }
    const lower = String(email).toLowerCase().trim();
    const existing = await User.findOne({ email: lower });
    if (existing) return res.status(409).json({ error: 'Email already in use' });

    const passwordHash = await User.hashPassword(password);
    const user = await User.create({
      name: String(name).trim(),
      email: lower,
      passwordHash,
      role,
      outletId: req.user.outletId,
    });
    res.status(201).json({ user: user.toSafeJSON() });
  } catch (err) {
    next(err);
  }
};

/**
 * Admin updates an existing user under the same outlet.
 * Body: { name?, role?, active?, newPassword? }
 * Admins can't demote themselves or deactivate their own account here.
 */
exports.updateUser = async (req, res, next) => {
  try {
    const { id } = req.params;
    const user = await User.findOne({ _id: id, outletId: req.user.outletId });
    if (!user) return res.status(404).json({ error: 'User not found' });

    const { name, role, active, newPassword } = req.body;
    const isSelf = String(user._id) === String(req.user._id);

    if (name !== undefined) user.name = String(name).trim();

    if (role !== undefined) {
      if (!User.ROLES.includes(role)) {
        return res
          .status(400)
          .json({ error: `role must be one of ${User.ROLES.join(', ')}` });
      }
      if (isSelf && role !== 'admin') {
        return res
          .status(400)
          .json({ error: "You can't demote your own admin account here." });
      }
      user.role = role;
    }

    if (active !== undefined) {
      if (isSelf && active === false) {
        return res
          .status(400)
          .json({ error: "You can't deactivate your own account." });
      }
      user.active = !!active;
    }

    if (newPassword !== undefined && newPassword !== '') {
      if (String(newPassword).length < 6) {
        return res
          .status(400)
          .json({ error: 'New password must be at least 6 characters' });
      }
      user.passwordHash = await User.hashPassword(newPassword);
    }

    await user.save();
    res.json({ user: user.toSafeJSON() });
  } catch (err) {
    next(err);
  }
};
