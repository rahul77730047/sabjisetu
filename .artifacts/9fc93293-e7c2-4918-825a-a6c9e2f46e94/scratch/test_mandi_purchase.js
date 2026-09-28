async function testMandiPurchase() {
  console.log('=== TESTING MANDI PURCHASE WITH BACKWARD-COMPATIBLE PAYLOAD ===');
  const VERCEL_BASE = 'https://sabzisetu.vercel.app/api';

  const loginRes = await fetch(`${VERCEL_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: 'admin123' })
  });

  const loginData = await loginRes.json();
  const token = loginData.token;

  // Backward compatible payload including both 'qty' and 'quantity_value'
  const purchasePayload = {
    date: '2026-09-25',
    vendor: 'Azadpur Mandi',
    item: 'Capsicum',
    specification: 'Grade A',
    qty: 100,
    quantity_value: 100,
    quantityValue: 100,
    quantity_unit: 'Kg',
    quantityUnit: 'Kg',
    rate: 20
  };

  console.log('\nSending Backward-Compatible Payload to Vercel API:');
  console.log(JSON.stringify(purchasePayload, null, 2));

  const postRes = await fetch(`${VERCEL_BASE}/mandi-purchases`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify(purchasePayload)
  });

  console.log('\nPOST /mandi-purchases Status Code:', postRes.status);
  const postData = await postRes.json();
  console.log('POST /mandi-purchases Response:', JSON.stringify(postData, null, 2));
}

testMandiPurchase().catch(err => console.error('Test error:', err));
