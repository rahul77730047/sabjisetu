import { Router } from "express";
import bcrypt from "bcryptjs";
import crypto from "node:crypto";
import jwt from "jsonwebtoken";
import { pool } from "../db.js";

export const authRouter = Router();

const JWT_SECRET = process.env.JWT_SECRET || "sabzisetu_secret_key_123";

export async function verifyPassword(password, storedHash) {
  if (!storedHash || typeof storedHash !== "string") return false;

  if (storedHash.startsWith("scrypt$")) {
    const parts = storedHash.split("$");
    if (parts.length !== 3) return false;
    const [, saltStr, targetHash] = parts;
    try {
      const computedKey = crypto.scryptSync(password, saltStr, 64).toString("hex");
      if (computedKey.length !== targetHash.length) return false;
      return crypto.timingSafeEqual(Buffer.from(computedKey, "hex"), Buffer.from(targetHash, "hex"));
    } catch {
      return false;
    }
  }

  if (storedHash.startsWith("$2a$") || storedHash.startsWith("$2b$") || storedHash.startsWith("$2y$")) {
    try {
      return await bcrypt.compare(password, storedHash);
    } catch {
      return false;
    }
  }

  return false;
}

export function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString("hex");
  const derivedKey = crypto.scryptSync(password, salt, 64).toString("hex");
  return `scrypt$${salt}$${derivedKey}`;
}

// Middleware to verify token
export const verifyToken = (req, res, next) => {
  const token = req.headers["authorization"]?.split(" ")[1];
  if (!token) return res.status(401).json({ error: "Access denied. No token provided." });

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (ex) {
    res.status(400).json({ error: "Invalid token." });
  }
};

authRouter.post("/login", async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) return res.status(400).json({ error: "Username and password required" });

  try {
    const { rows } = await pool.query("SELECT * FROM admin_users WHERE username = $1 AND active = true", [username]);
    if (rows.length === 0) return res.status(401).json({ error: "Invalid username or password" });

    const user = rows[0];
    const validPassword = await verifyPassword(password, user.password_hash);
    if (!validPassword) return res.status(401).json({ error: "Invalid username or password" });

    const token = jwt.sign({ id: user.id, username: user.username, role: user.role, displayName: user.display_name }, JWT_SECRET, { expiresIn: "30d" });

    // Record session in admin_sessions
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);
    await pool.query("INSERT INTO admin_sessions (admin_user_id, token_hash, expires_at) VALUES ($1, $2, $3)", [user.id, token.substring(token.length - 20), expiresAt]);

    res.json({ token, username: user.username, displayName: user.display_name, role: user.role });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Internal server error" });
  }
});

authRouter.post("/change-password", verifyToken, async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  if (!currentPassword || !newPassword) return res.status(400).json({ error: "All fields required" });

  try {
    const { rows } = await pool.query("SELECT * FROM admin_users WHERE id = $1", [req.user.id]);
    const user = rows[0];

    const validPassword = await verifyPassword(currentPassword, user.password_hash);
    if (!validPassword) return res.status(400).json({ error: "Incorrect current password" });

    const hashedPassword = hashPassword(newPassword);

    await pool.query("UPDATE admin_users SET password_hash = $1, updated_at = now() WHERE id = $2", [hashedPassword, user.id]);
    res.json({ success: true, message: "Password updated successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Internal server error" });
  }
});
