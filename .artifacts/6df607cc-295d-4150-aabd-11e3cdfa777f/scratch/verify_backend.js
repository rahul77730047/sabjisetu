import { pool } from '../../../server/db.js';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

async function runTests() {
  console.log('--- STARTING BACKEND VERIFICATION ---');

  try {
    // 1. Check Tables and Columns
    const tables = ['admin_users', 'admin_sessions', 'stock_movements', 'sales', 'customer_payments', 'business_settings', 'whatsapp_bills', 'notifications'];
    for (const table of tables) {
      const res = await pool.query('SELECT column_name FROM information_schema.columns WHERE table_name = $1', [table]);
      console.log(`Table ${table} columns:`, res.rows.map(c => c.column_name).join(', '));
      if (res.rows.length === 0) console.error(`❌ Table ${table} not found or has no columns!`);
    }

    // 2. Auth Test
    console.log('\n--- Testing Auth ---');
    const userRes = await pool.query("SELECT * FROM admin_users WHERE username = 'admin'");
    if (userRes.rows.length === 0) {
        console.error('❌ Admin user not found');
    } else {
        const user = userRes.rows[0];
        const valid = await bcrypt.compare('admin123', user.password_hash);
        console.log('Admin password valid:', valid);
    }

    // 3. Business Settings Test
    console.log('\n--- Testing Settings ---');
    const settingsRes = await pool.query('SELECT low_stock_threshold_kg FROM business_settings WHERE id = 1');
    console.log('Low stock threshold:', settingsRes.rows[0]?.low_stock_threshold_kg);

    // 4. Stock Movement Test
    console.log('\n--- Testing Stock Movements ---');
    const moveRes = await pool.query('SELECT COUNT(*) FROM stock_movements');
    console.log('Total stock movements:', moveRes.rows[0].count);

    console.log('\n--- VERIFICATION FINISHED ---');
  } catch (err) {
    console.error('❌ Test failed:', err);
  } finally {
    await pool.end();
  }
}

runTests();
