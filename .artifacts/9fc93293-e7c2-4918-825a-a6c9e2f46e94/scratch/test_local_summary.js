async function testLocalSummary() {
  console.log('=== TESTING LOCAL EXPRESS API SUMMARY ===');
  const LOCAL_BASE = 'http://localhost:4000/api';

  try {
    const loginRes = await fetch(`${LOCAL_BASE}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'admin123' })
    });

    const loginData = await loginRes.json();
    const token = loginData.token;

    const summaryRes = await fetch(`${LOCAL_BASE}/reports/summary`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });

    const summary = await summaryRes.json();
    console.log('Local GET /reports/summary Status Code:', summaryRes.status);
    console.log('Local Summary Data:', JSON.stringify(summary, null, 2));
  } catch (err) {
    console.log('Local server error (ensure local server is running):', err.message);
  }
}

testLocalSummary().catch(err => console.error('Test error:', err));
