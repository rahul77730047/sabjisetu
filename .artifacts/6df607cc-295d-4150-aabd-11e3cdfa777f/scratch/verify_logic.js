import { pool } from '../../../server/db.js';

async function testLogic() {
  const baseUrl = 'http://localhost:4000/api';
  console.log('--- TESTING BUSINESS LOGIC API ---');

  try {
    const loginRes = await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'admin123' })
    });
    const { token } = await loginRes.json();
    const headers = { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` };

    // 1. Test Low Stock Threshold
    console.log('\n--- Testing Low Stock Threshold ---');
    const settingsGet = await fetch(`${baseUrl}/settings`, { headers });
    const originalSettings = await settingsGet.json();
    console.log('Current threshold:', originalSettings.low_stock_threshold_kg);

    const newThreshold = 123.45;
    console.log(`Updating threshold to ${newThreshold}...`);
    const settingsPut = await fetch(`${baseUrl}/settings`, {
      method: 'PUT',
      headers,
      body: JSON.stringify({ ...originalSettings, low_stock_threshold_kg: newThreshold })
    });
    const updatedSettings = await settingsPut.json();
    console.log('Update response:', updatedSettings);
    if (Number(updatedSettings.low_stock_threshold_kg) === newThreshold) {
      console.log('✅ Threshold update success.');
    } else {
      console.error('❌ Threshold update failed:', updatedSettings.low_stock_threshold_kg);
    }

    // Restore threshold
    await fetch(`${baseUrl}/settings`, {
      method: 'PUT',
      headers,
      body: JSON.stringify(originalSettings)
    });

    // 2. Test Stock Movement recording via Purchase
    console.log('\n--- Testing Stock Movement via Mandi Purchase ---');
    const moveCountBeforeRes = await fetch(`${baseUrl}/stock/movements`, { headers });
    const moveCountBefore = (await moveCountBeforeRes.json()).length;

    const purchaseBody = {
      date: new Date().toISOString().split('T')[0],
      vendor: 'Test Vendor',
      item: 'Test Item ' + Date.now(),
      quantity_value: 10,
      quantity_unit: 'Kg',
      rate: 5
    };

    const purchaseRes = await fetch(`${baseUrl}/mandi-purchases`, {
      method: 'POST',
      headers,
      body: JSON.stringify(purchaseBody)
    });
    const purchaseData = await purchaseRes.json();
    if (!purchaseRes.ok) throw new Error('Purchase failed: ' + JSON.stringify(purchaseData));

    const moveCountAfterRes = await fetch(`${baseUrl}/stock/movements`, { headers });
    const movements = await moveCountAfterRes.json();
    const moveCountAfter = movements.length;

    if (moveCountAfter === moveCountBefore + 1) {
      console.log('✅ Stock movement recorded correctly.');
      const lastMove = movements[0];
      if (lastMove.source_type === 'purchase' && Number(lastMove.qty_change) === 10) {
          console.log('✅ Movement details correct.');
      } else {
          console.error('❌ Movement details incorrect:', lastMove);
      }
    } else {
      console.error(`❌ Movement count mismatch. Before: ${moveCountBefore}, After: ${moveCountAfter}`);
    }

    // 3. Test Sale Movement (Negative)
    console.log('\n--- Testing Stock Movement via Sale ---');
    // Ensure item has stock (the one created above should have 10kg)
    const saleBody = {
        date: purchaseBody.date,
        customer: 'Test Customer',
        item: purchaseBody.item,
        quantity_value: 4,
        quantity_unit: 'Kg',
        rate: 8,
        status: 'Due',
        payment_method: 'Cash',
        transaction_id: ''
    };
    const saleRes = await fetch(`${baseUrl}/sales`, {
        method: 'POST',
        headers,
        body: JSON.stringify(saleBody)
    });
    if (!saleRes.ok) console.error('❌ Sale failed:', await saleRes.text());

    const moveCountAfterSaleRes = await fetch(`${baseUrl}/stock/movements`, { headers });
    const movementsAfterSale = await moveCountAfterSaleRes.json();
    const lastMoveSale = movementsAfterSale[0];
    if (lastMoveSale.source_type === 'sale' && Number(lastMoveSale.qty_change) === -4) {
        console.log('✅ Sale movement recorded correctly (negative).');
    } else {
        console.error('❌ Sale movement details incorrect:', lastMoveSale);
    }

    // 4. Test Customer Payment
    console.log('\n--- Testing Customer Payment ---');
    const custRes = await fetch(`${baseUrl}/customers`, { headers });
    const customers = await custRes.json();
    const testCust = customers.find(c => c.name === 'Test Customer');

    if (testCust) {
        const paymentBody = {
            customer_id: testCust.id,
            date: purchaseBody.date,
            amount: 10,
            payment_method: 'Bank',
            transaction_id: 'BANK789',
            note: 'Test payment'
        };
        const payRes = await fetch(`${baseUrl}/payments`, {
            method: 'POST',
            headers,
            body: JSON.stringify(paymentBody)
        });
        if (payRes.ok) {
            console.log('✅ Customer payment recorded with method and txn id.');
        } else {
            console.error('❌ Customer payment failed:', await payRes.text());
        }
    }

    // 5. Check Notifications (Low Stock)
    console.log('\n--- Testing Low Stock Notification ---');
    // Set threshold high to trigger for our item with 6kg left
    await fetch(`${baseUrl}/settings`, {
        method: 'PUT',
        headers,
        body: JSON.stringify({ ...originalSettings, low_stock_threshold_kg: 100 })
    });

    const notifyRes = await fetch(`${baseUrl}/notifications`, { headers });
    const notifications = await notifyRes.json();
    const lowStockAlert = notifications.find(n => n.text.includes(purchaseBody.item) && n.notification_key === 'LOW_STOCK');
    if (lowStockAlert) {
        console.log('✅ Low stock notification triggered correctly.');
        if (lowStockAlert.action_message === 'Restock soon') {
            console.log('✅ Notification action message correct.');
        }
    } else {
        console.error('❌ Low stock notification NOT found.');
    }

    // 6. Cleanup
    console.log('\n--- Cleaning Up ---');
    await pool.query('DELETE FROM stock_movements WHERE item LIKE \'Test Item%\'');
    await pool.query('DELETE FROM mandi_purchases WHERE vendor = \'Test Vendor\'');
    await pool.query('DELETE FROM sales WHERE customer = \'Test Customer\'');
    await pool.query('DELETE FROM customer_payments WHERE note = \'Test payment\'');
    await pool.query('DELETE FROM customers WHERE name = \'Test Customer\'');
    await pool.query('DELETE FROM stock WHERE item LIKE \'Test Item%\'');
    console.log('✅ Cleanup finished.');

  } catch (err) {
    console.error('❌ API logic test failed:', err.message);
  }
}

testLogic();
