async function testVercelSummary() {
  console.log('=== CHECKING DEPLOYED VERCEL API RAW SUMMARY KEYS ===');
  const VERCEL_BASE = 'https://sabzisetu.vercel.app/api';

  const loginRes = await fetch(`${VERCEL_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: 'admin123' })
  });

  const loginData = await loginRes.json();
  const token = loginData.token;

  if (!token) {
    console.error('Login failed');
    return;
  }

  const summaryRes = await fetch(`${VERCEL_BASE}/reports/summary`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });

  const rawText = await summaryRes.text();
  console.log('HTTP STATUS:', summaryRes.status);
  console.log('RAW RESPONSE TEXT:');
  console.log(rawText);

  try {
    const json = JSON.parse(rawText);
    console.log('\nPARSED KEYS LIST:');
    console.log(Object.keys(json));
    console.log('\nDoes "sales_still_due" exist?', 'sales_still_due' in json);
    console.log('sales_still_due value:', json.sales_still_due);
  } catch (e) {
    console.error('JSON parse error:', e.message);
  }
}

testVercelSummary().catch(err => console.error(err));
