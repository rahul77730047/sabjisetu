async function testDerivedDashboard() {
  console.log('=== DERIVING DASHBOARD METRICS FROM DEPLOYED VERCEL API ===');
  const VERCEL_BASE = 'https://sabzisetu.vercel.app/api';

  const loginRes = await fetch(`${VERCEL_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: 'admin123' })
  });

  const loginData = await loginRes.json();
  const token = loginData.token;

  if (!token) return;

  const headers = { 'Authorization': `Bearer ${token}` };

  // Fetch summary, customers, sales, stock in parallel
  const [summaryRes, customersRes, salesRes, stockRes] = await Promise.all([
    fetch(`${VERCEL_BASE}/reports/summary`, { headers }),
    fetch(`${VERCEL_BASE}/customers`, { headers }),
    fetch(`${VERCEL_BASE}/sales`, { headers }),
    fetch(`${VERCEL_BASE}/stock`, { headers }),
  ]);

  const summary = await summaryRes.json();
  const customers = await customersRes.json();
  const sales = await salesRes.json();
  const stock = await stockRes.json();

  console.log('\n--- 1. DUE SUMMARY BREAKDOWN ---');
  const totalDue = Number(summary.total_due || 0);
  const overdueDue = customers.filter(c => c.status === 'Overdue').reduce((s, c) => s + Number(c.due || 0), 0);
  const todayDue = customers.filter(c => c.status === 'Due Today').reduce((s, c) => s + Number(c.due || 0), 0);
  const upcomingDue = customers.filter(c => (c.status === 'Upcoming' || (c.status !== 'Overdue' && c.status !== 'Due Today')) && Number(c.due || 0) > 0).reduce((s, c) => s + Number(c.due || 0), 0);

  console.log('Total Due:', totalDue);
  console.log('Overdue:', overdueDue);
  console.log('Due Today:', todayDue);
  console.log('Upcoming:', upcomingDue);
  console.log('Sum check (Overdue + Today + Upcoming):', overdueDue + todayDue + upcomingDue);

  console.log('\n--- 2. PAYMENT OVERVIEW ---');
  const collectedToday = Number(summary.collected_today || 0);
  const salesStillDue = Number(summary.sales_still_due ?? summary.total_due ?? 0);
  console.log('Collected Today:', collectedToday);
  console.log('Sales Still Due (Total Customer Due across all time):', salesStillDue);

  console.log('\n--- 3. TOP SELLING SABJI (TODAY) ---');
  const todayStr = new Date().toISOString().substring(0, 10);
  const todaySales = sales.filter(s => String(s.date).substring(0, 10) === todayStr);
  console.log("Today's Total Sales Count:", todaySales.length);

  const topMap = {};
  for (const s of todaySales) {
    const item = (s.item || '').trim();
    if (item) {
      topMap[item] = (topMap[item] || 0) + Number(s.qty || s.quantity_value || 0);
    }
  }

  let topItem = null;
  let topQty = 0;
  for (const [item, qty] of Object.entries(topMap)) {
    if (qty > topQty) {
      topItem = item;
      topQty = qty;
    }
  }

  console.log('Top Selling Item:', topItem || 'No sales recorded today.');
  console.log('Top Selling Qty:', topQty);

  console.log('\n--- 4. RECENT DUES (TOP 5) ---');
  const recentDues = customers.filter(c => Number(c.due || 0) > 0).sort((a, b) => Number(b.due || 0) - Number(a.due || 0)).slice(0, 5);
  console.log(JSON.stringify(recentDues, null, 2));

  console.log('\n--- 5. RECENT SALES (TOP 5) ---');
  const recentSales = sales.slice(0, 5);
  console.log(JSON.stringify(recentSales, null, 2));
}

testDerivedDashboard().catch(err => console.error('Error:', err));
