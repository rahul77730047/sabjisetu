async function testNotifications() {
  console.log('=== TESTING DEPLOYED VERCEL API NOTIFICATIONS ===');
  const VERCEL_BASE = 'https://sabzisetu.vercel.app/api';

  // 1. Login
  const loginRes = await fetch(`${VERCEL_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: 'admin123' })
  });

  const loginData = await loginRes.json();
  const token = loginData.token;
  console.log('Login Status:', loginRes.status, 'Token:', token ? 'YES' : 'NO');

  if (!token) return;

  // 2. GET /notifications BEFORE
  const getRes1 = await fetch(`${VERCEL_BASE}/notifications`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  const notifs1 = await getRes1.json();
  console.log('\nGET /notifications Total Count:', notifs1.length);
  const unread1 = notifs1.filter(n => n.read === false);
  console.log('Unread Count BEFORE Mark All Read:', unread1.length);
  console.log('Sample Unread Notif:', JSON.stringify(unread1[0], null, 2));

  // 3. PATCH /notifications/mark-all-read
  console.log('\nSending PATCH /notifications/mark-all-read...');
  const markRes = await fetch(`${VERCEL_BASE}/notifications/mark-all-read`, {
    method: 'PATCH',
    headers: { 'Authorization': `Bearer ${token}` }
  });
  console.log('PATCH Status:', markRes.status);
  console.log('PATCH Body:', await markRes.json());

  // 4. GET /notifications AFTER
  const getRes2 = await fetch(`${VERCEL_BASE}/notifications`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  const notifs2 = await getRes2.json();
  const unread2 = notifs2.filter(n => n.read === false);
  console.log('\nGET /notifications Unread Count AFTER Mark All Read:', unread2.length);
  console.log('Sample Notif AFTER:', JSON.stringify(notifs2[0], null, 2));
}

testNotifications().catch(err => console.error('Test error:', err));
