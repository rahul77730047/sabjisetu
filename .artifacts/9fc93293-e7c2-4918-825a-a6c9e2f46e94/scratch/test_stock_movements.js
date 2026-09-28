async function testMovements() {
  console.log('=== TESTING STOCK MOVEMENTS ENDPOINT ===');
  const VERCEL_BASE = 'https://sabzisetu.vercel.app/api';

  const loginRes = await fetch(`${VERCEL_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: 'admin123' })
  });

  const loginData = await loginRes.json();
  const token = loginData.token;

  console.log('\n--- Vercel API: GET /stock/movements ---');
  const vercelRes = await fetch(`${VERCEL_BASE}/stock/movements`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  console.log('Vercel Status:', vercelRes.status);
  console.log('Vercel Content-Type:', vercelRes.headers.get('content-type'));
  const vercelText = await vercelRes.text();
  console.log('Vercel Response (first 200 chars):', vercelText.slice(0, 200));

  console.log('\n--- Vercel API: GET /stock/history or alternate ---');
  const altRes = await fetch(`${VERCEL_BASE}/stock/history`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  console.log('Alt Status:', altRes.status);
}

testMovements().catch(err => console.error('Test error:', err));
