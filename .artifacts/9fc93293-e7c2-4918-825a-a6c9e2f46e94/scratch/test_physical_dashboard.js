async function testPhysicalDashboardRequest() {
  console.log('=== CAPTURING EXACT VERCEL PRODUCTION DASHBOARD SUMMARY RESPONSE ===');
  const VERCEL_BASE = 'https://sabzisetu.vercel.app/api';

  // 1. Login with admin/admin123 to get bearer token
  const loginRes = await fetch(`${VERCEL_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: 'admin123' })
  });

  const loginData = await loginRes.json();
  const token = loginData.token;
  console.log('Login Status:', loginRes.status, 'Token Available:', !!token);

  if (!token) return;

  // 2. Execute GET /reports/summary
  const summaryRes = await fetch(`${VERCEL_BASE}/reports/summary`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });

  console.log('\nHTTP METHOD: GET');
  console.log('REQUEST URL:', `${VERCEL_BASE}/reports/summary`);
  console.log('HTTP STATUS:', summaryRes.status);

  const rawBody = await summaryRes.text();
  console.log('\nRAW RESPONSE BODY:');
  console.log(rawBody);

  const parsed = JSON.parse(rawBody);
  console.log('\nDECODED JSON KEYS & TYPES:');
  Object.keys(parsed).forEach(k => {
    console.log(`  ${k}: ${typeof parsed[k]} = ${JSON.stringify(parsed[k])}`);
  });
}

testPhysicalDashboardRequest().catch(err => console.error('Error:', err));
