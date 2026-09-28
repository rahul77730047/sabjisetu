async function testUnitsPayload() {
  console.log('=== TESTING MANDI PURCHASE WITH NON-KG UNITS (Carat, Quintal, Bag) ===');
  const VERCEL_BASE = 'https://sabzisetu.vercel.app/api';

  const loginRes = await fetch(`${VERCEL_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: 'admin123' })
  });

  const loginData = await loginRes.json();
  const token = loginData.token;

  // Test 1: Carat (Multiplier = 25)
  const caratPayload = {
    date: '2026-09-26',
    vendor: 'Azadpur Mandi',
    item: 'Capsicum',
    specification: 'Grade A',
    qty: 250, // 10 Carat * 25 Kg = 250 Kg
    quantity_value: 10,
    quantityValue: 10,
    quantity_unit: 'Carat',
    quantityUnit: 'Carat',
    rate: 30
  };

  console.log('Sending Carat Payload to Vercel API:');
  console.log(JSON.stringify(caratPayload, null, 2));

  const postRes1 = await fetch(`${VERCEL_BASE}/mandi-purchases`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify(caratPayload)
  });

  console.log('\nCarat Purchase Status Code:', postRes1.status);
  const data1 = await postRes1.json();
  console.log('Carat Purchase Response:', JSON.stringify(data1, null, 2));

  // Test 2: Quintal (Multiplier = 100)
  const quintalPayload = {
    date: '2026-09-26',
    vendor: 'Azadpur Mandi',
    item: 'Capsicum',
    specification: 'Grade A',
    qty: 200, // 2 Quintal * 100 Kg = 200 Kg
    quantity_value: 2,
    quantityValue: 2,
    quantity_unit: 'Quintal',
    quantityUnit: 'Quintal',
    rate: 25
  };

  const postRes2 = await fetch(`${VERCEL_BASE}/mandi-purchases`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify(quintalPayload)
  });

  console.log('\nQuintal Purchase Status Code:', postRes2.status);
  const data2 = await postRes2.json();
  console.log('Quintal Purchase Response:', JSON.stringify(data2, null, 2));
}

testUnitsPayload().catch(err => console.error('Test error:', err));
