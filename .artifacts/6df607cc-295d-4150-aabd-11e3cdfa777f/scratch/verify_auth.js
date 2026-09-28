async function testAuth() {
  const baseUrl = 'http://localhost:4000/api';
  console.log('--- TESTING AUTH API ---');

  try {
    // 1. Valid Login
    console.log('Testing valid login...');
    const loginRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'admin123' })
    });
    const loginData = await loginRes.json();
    if (loginRes.ok && loginData.token) {
      console.log('✅ Valid login success. Token received.');
      const token = loginData.token;

      // 2. Test Protected Route with Token
      console.log('Testing protected route with token...');
      const settingsRes = await fetch(`${baseUrl}/settings`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (settingsRes.ok) {
        console.log('✅ Protected route access success.');
      } else {
        console.error('❌ Protected route access failed:', settingsRes.status, await settingsRes.text());
      }

      // 3. Test Invalid Token
      console.log('Testing invalid token...');
      const invalidRes = await fetch(`${baseUrl}/settings`, {
        headers: { 'Authorization': `Bearer invalid_token` }
      });
      if (invalidRes.status === 400 || invalidRes.status === 401) {
        console.log('✅ Invalid token rejected correctly.');
      } else {
        console.error('❌ Invalid token was NOT rejected correctly:', invalidRes.status);
      }
    } else {
      console.error('❌ Valid login failed:', loginRes.status, loginData);
    }

    // 4. Invalid Login
    console.log('Testing invalid login...');
    const failRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'wrong_password' })
    });
    if (failRes.status === 401) {
      console.log('✅ Invalid login rejected correctly.');
    } else {
      console.error('❌ Invalid login was NOT rejected correctly:', failRes.status);
    }

  } catch (err) {
    console.error('❌ API test failed:', err.message);
  }
}

testAuth();
