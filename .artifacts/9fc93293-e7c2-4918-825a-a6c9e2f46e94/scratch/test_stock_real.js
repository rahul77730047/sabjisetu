async function testStockUpdateFlow() {
  console.log('=== TESTING STOCK UPDATE FLOW AGAINST DEPLOYED VERCEL API ===');
  const VERCEL_BASE = 'https://sabzisetu.vercel.app/api';

  const loginRes = await fetch(`${VERCEL_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: 'admin123' })
  });

  const loginData = await loginRes.json();
  const token = loginData.token;

  if (!token) return;

  const appleId = '515ac2f0-6d11-4433-90f1-abdc538f8291';

  // 1. Send PATCH update
  console.log('\n1. Sending PATCH /stock/' + appleId + ' with sellingPrice = 60');
  const patchRes = await fetch(`${VERCEL_BASE}/stock/${appleId}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify({ selling_price: 60, sellingPrice: 60 })
  });

  console.log('PATCH Status Code:', patchRes.status);
  const patchBody = await patchRes.json();
  console.log('PATCH Returned Object:', JSON.stringify(patchBody, null, 2));

  // 2. Re-fetch GET /stock
  console.log('\n2. Re-fetching GET /stock to verify persistent update');
  const getRes = await fetch(`${VERCEL_BASE}/stock`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });

  const stockList = await getRes.json();
  const appleUpdated = stockList.find(s => s.id === appleId);
  console.log('GET /stock Returned Apple Object:');
  console.log(JSON.stringify(appleUpdated, null, 2));

  // 3. Simulate Flutter rendering
  const rawSellingPrice = appleUpdated.selling_price ?? appleUpdated.sellingPrice;
  const rawAvgCost = appleUpdated.avg_cost ?? appleUpdated.avgCost;

  console.log('\n3. Simulated Flutter Render Values:');
  console.log('  Item:', appleUpdated.item);
  console.log('  Qty:', appleUpdated.qty, 'Kg');
  console.log('  Avg Cost:', rawAvgCost !== null ? `₹${rawAvgCost}` : '—');
  console.log('  Selling Price:', rawSellingPrice !== null ? `₹${rawSellingPrice}` : '—');
}

testStockUpdateFlow().catch(err => console.error(err));
