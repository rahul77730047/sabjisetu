async function testDiagnostics() {
  console.log('=== REAL PRODUCTION API DIAGNOSTIC CHECKS ===');
  const VERCEL_BASE = 'https://sabzisetu.vercel.app/api';

  const loginRes = await fetch(`${VERCEL_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: 'admin123' })
  });

  const loginData = await loginRes.json();
  const token = loginData.token;

  if (!token) return;

  const headers = { 'Authorization': `Bearer ${token}` };

  // 1. GET /stock
  const stockRes = await fetch(`${VERCEL_BASE}/stock`, { headers });
  const stockJson = await stockRes.json();
  console.log('\nGET /api/stock:');
  console.log('  Final URL:', stockRes.url);
  console.log('  HTTP Status:', stockRes.status);
  console.log('  Top-Level Response Type:', Array.isArray(stockJson) ? 'Array (List)' : typeof stockJson);
  console.log('  Parsed Count:', Array.isArray(stockJson) ? stockJson.length : 0);

  // 2. GET /customers
  const customersRes = await fetch(`${VERCEL_BASE}/customers`, { headers });
  const customersJson = await customersRes.json();
  console.log('\nGET /api/customers:');
  console.log('  Final URL:', customersRes.url);
  console.log('  HTTP Status:', customersRes.status);
  console.log('  Top-Level Response Type:', Array.isArray(customersJson) ? 'Array (List)' : typeof customersJson);
  console.log('  Parsed Count:', Array.isArray(customersJson) ? customersJson.length : 0);
  if (Array.isArray(customersJson)) {
    const dueCusts = customersJson.filter(c => Number(c.due || 0) > 0);
    console.log('  Customers with due > 0 Count:', dueCusts.length);
  }

  // 3. GET /sales
  const salesRes = await fetch(`${VERCEL_BASE}/sales`, { headers });
  const salesJson = await salesRes.json();
  console.log('\nGET /api/sales:');
  console.log('  Final URL:', salesRes.url);
  console.log('  HTTP Status:', salesRes.status);
  console.log('  Top-Level Response Type:', Array.isArray(salesJson) ? 'Array (List)' : typeof salesJson);
  console.log('  Parsed Count:', Array.isArray(salesJson) ? salesJson.length : 0);
}

testDiagnostics().catch(err => console.error(err));
