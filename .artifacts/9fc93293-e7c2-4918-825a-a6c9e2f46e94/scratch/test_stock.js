async function testStockCreate() {
  console.log('=== TESTING STOCK CREATE ON DEPLOYED VERCEL API ===');
  const VERCEL_BASE = 'https://sabzisetu.vercel.app/api';

  const loginRes = await fetch(`${VERCEL_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: 'admin123' })
  });

  const loginData = await loginRes.json();
  const token = loginData.token;

  if (!token) return;

  // Flutter Stock Add Form Payload:
  // When Flutter creates a stock item, what keys does it send?
  const testItemName = 'Test Mango ' + Date.now().toString().slice(-4);
  const flutterAddPayload = {
    item: testItemName,
    specification: 'Fresh',
    qty: 50,
    avg_cost: 30,
    avgCost: 30,
    selling_price: 45,
    sellingPrice: 45,
    quantity_unit: 'Kg',
    quantity_value: 50
  };

  console.log('Sending POST /stock payload:');
  console.log(JSON.stringify(flutterAddPayload, null, 2));

  const postRes = await fetch(`${VERCEL_BASE}/stock`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify(flutterAddPayload)
  });

  console.log('\nPOST /stock Status Code:', postRes.status);
  const postData = await postRes.json();
  console.log('POST /stock Response Body:', JSON.stringify(postData, null, 2));

  // Verify GET /stock
  const getRes = await fetch(`${VERCEL_BASE}/stock`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  const stockList = await getRes.json();
  const createdInList = stockList.find(s => s.item.toLowerCase() === testItemName.toLowerCase());
  console.log('\nGET /stock Found Created Item:', JSON.stringify(createdInList, null, 2));
}

testStockCreate().catch(err => console.error('Test error:', err));
