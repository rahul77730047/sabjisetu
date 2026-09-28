async function testSaleCreate() {
  console.log('=== TESTING SALE CREATE ON DEPLOYED VERCEL API ===');
  const VERCEL_BASE = 'https://sabzisetu.vercel.app/api';

  const loginRes = await fetch(`${VERCEL_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: 'admin123' })
  });

  const loginData = await loginRes.json();
  const token = loginData.token;
  console.log('Login Status:', loginRes.status, 'Token:', token ? 'YES' : 'NO');

  if (!token) return;

  // Flutter Sale Add Form Payload
  const salePayload = {
    date: '2026-09-26',
    customer: 'Mahesh Ji',
    phone: '9999999999',
    item: 'Capsicum',
    specification: 'Grade A',
    qty: 10,
    quantity_value: 10,
    quantityValue: 10,
    quantity_unit: 'Kg',
    quantityUnit: 'Kg',
    rate: 40,
    payment_method: 'Cash',
    status: 'Due'
  };

  console.log('\nSending POST /sales payload:');
  console.log(JSON.stringify(salePayload, null, 2));

  const postRes = await fetch(`${VERCEL_BASE}/sales`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify(salePayload)
  });

  console.log('\nPOST /sales Status Code:', postRes.status);
  const postData = await postRes.json();
  console.log('POST /sales Response Body:', JSON.stringify(postData, null, 2));

  // Verify GET /sales
  const getRes = await fetch(`${VERCEL_BASE}/sales`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  const salesList = await getRes.json();
  const createdSale = salesList.find(s => s.id === postData.id);
  console.log('\nGET /sales Found Created Sale:', JSON.stringify(createdSale, null, 2));

  // Verify Stock deduct effect
  const stockRes = await fetch(`${VERCEL_BASE}/stock`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  const stockList = await stockRes.json();
  const capsicumStock = stockList.find(s => s.item.toLowerCase() === 'capsicum');
  console.log('\nGET /stock After Sale for Capsicum:', JSON.stringify(capsicumStock, null, 2));
}

testSaleCreate().catch(err => console.error('Test error:', err));
