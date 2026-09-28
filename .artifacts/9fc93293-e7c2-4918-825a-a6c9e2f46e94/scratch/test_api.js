async function testVercelApi() {
  console.log('=== TESTING DEPLOYED VERCEL API WITH COMPLETE PAYLOAD ===');
  const VERCEL_BASE = 'https://sabzisetu.vercel.app/api';

  const loginRes = await fetch(`${VERCEL_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: 'admin123' })
  });

  const loginData = await loginRes.json();
  const token = loginData.token;

  const getRes = await fetch(`${VERCEL_BASE}/settings`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  const getData = await getRes.json();
  console.log('GET /settings Data from Vercel before save:', JSON.stringify(getData, null, 2));

  // Complete payload including low_stock_threshold_kg so OLD Vercel deployments do NOT fail!
  const completePayload = {
    name: getData.name || 'SabziSetu',
    owner: getData.owner || 'Owner',
    tagline: getData.tagline || '',
    currency: getData.currency || '₹',
    theme_color: '#D9AE12',
    themeColor: '#D9AE12',
    low_stock_threshold_kg: 50,
    lowStockThresholdKg: 50,
    whatsapp_send_all_enabled: true,
    whatsappSendAllEnabled: true,
  };

  console.log('\nSending Complete Payload to DEPLOYED Vercel API:');
  console.log(JSON.stringify(completePayload, null, 2));

  const putRes = await fetch(`${VERCEL_BASE}/settings`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify(completePayload)
  });

  console.log('\nVERCEL PUT /settings Status Code:', putRes.status);
  const putData = await putRes.json();
  console.log('VERCEL PUT /settings Response Body:', JSON.stringify(putData, null, 2));

  // Fetch /settings again to verify persistence on Vercel
  const getRes2 = await fetch(`${VERCEL_BASE}/settings`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  const getData2 = await getRes2.json();
  console.log('\nGET /settings Data from Vercel AFTER save:', JSON.stringify(getData2, null, 2));
}

testVercelApi().catch(err => console.error('Test error:', err));
