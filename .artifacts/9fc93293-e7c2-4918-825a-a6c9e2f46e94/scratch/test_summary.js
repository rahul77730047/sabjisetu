async function testSummaryApi() {
  console.log('=== TESTING DEPLOYED VERCEL API SUMMARY REPORT ===');
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

  // GET /reports/summary
  const summaryRes = await fetch(`${VERCEL_BASE}/reports/summary`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });

  const summary = await summaryRes.json();
  console.log('GET /reports/summary Status Code:', summaryRes.status);
  console.log('Summary Data:', JSON.stringify(summary, null, 2));
}

testSummaryApi().catch(err => console.error('Test error:', err));
