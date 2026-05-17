const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const ROLES = ['admin', 'cashier', 'kitchen'];

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    passwordHash: { type: String, required: true },
    role: { type: String, enum: ROLES, default: 'cashier' },
    outletId: { type: String, default: 'default' }, // multi-outlet ready
    active: { type: Boolean, default: true },
  },
  { timestamps: true }
);

userSchema.methods.verifyPassword = function (plain) {
  return bcrypt.compare(plain, this.passwordHash);
};

userSchema.statics.hashPassword = function (plain) {
  return bcrypt.hash(plain, 12);
};

userSchema.methods.toSafeJSON = function () {
  const { _id, name, email, role, outletId, active, createdAt } = this;
  return { id: _id, name, email, role, outletId, active, createdAt };
};

module.exports = mongoose.model('User', userSchema);
module.exports.ROLES = ROLES;
