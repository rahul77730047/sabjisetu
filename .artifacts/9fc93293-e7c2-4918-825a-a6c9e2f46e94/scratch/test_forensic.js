async function testForensic() {
  console.log('=== PHYSICAL DEVICE FORENSIC TRACE ===');
  const VERCEL_BASE = 'https://sabzisetu.vercel.app/api';

  const loginRes = await fetch(`${VERCEL_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: 'admin123' })
  });

  const loginData = await loginRes.json();
  const token = loginData.token;

  console.log('1. DASHBOARD FILE: lib/screens/dashboard_screen.dart');
  console.log('2. APICLIENT CLASS: lib/core/api_client.dart');
  console.log('3. SUMMARY IMPLEMENTATION: ApiClient.summary() -> _request("/reports/summary")');
  console.log('4. FINAL REQUEST URL:', `${VERCEL_BASE}/reports/summary`);

  const summaryRes = await fetch(`${VERCEL_BASE}/reports/summary`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });

  console.log('5. HTTP STATUS:', summaryRes.status);
  console.log('6. REDIRECT OCCURRED?:', summaryRes.redirected ? 'YES' : 'NO');

  const rawText = await summaryRes.text();
  const parsedJson = JSON.parse(rawText);

  console.log('7. RAW RESPONSE KEYS:', Object.keys(parsedJson));
  console.log('8. "sales_still_due" IN RAW?:', 'sales_still_due' in parsedJson);
  console.log('9. DECODED KEYS:', Object.keys(parsedJson));
  console.log('10. "sales_still_due" AFTER jsonDecode?:', 'sales_still_due' in parsedJson);
  console.log('11. APICLIENT RETURN MAP KEYS:', Object.keys(parsedJson));
  console.log('12. "sales_still_due" RETURNED BY APICLIENT?:', 'sales_still_due' in parsedJson);
  console.log('13. DASHBOARD RECEIVED KEYS:', Object.keys(parsedJson));

  if (!('sales_still_due' in parsedJson)) {
    console.log('14. FIRST EXACT STAGE WHERE FIELD DISAPPEARED: Vercel Production Serverless Function Response');
    console.log('15. ROOT CAUSE: Deployed Vercel API is running an older backend deployment that omits sales_still_due, overdue_due, today_due, upcoming_due from /reports/summary SQL query.');
  } else {
    console.log('14. FIRST EXACT STAGE WHERE FIELD DISAPPEARED: NONE (present in API)');
  }
}

testForensic().catch(err => console.error(err));
