// Quick helper: insert a customer into Supabase via REST API.
// Usage: node supabase/add_customer.js
const https = require('https');

const SUPABASE_HOST = 'biuydcyyqeutfddxtruu.supabase.co';
const ANON_KEY = 'sb_publishable_vsEIUhzsOGFY6HYKGeDGMA_eZ_ffdp-';

const customer = {
  name: 'Sample Customer',
  email: 'sample.customer@howdidship.com',
  phone: '+1 876 555 0100',
  address: '1 Howdidship Way, Kingston, Jamaica',
  mailbox_number: 'HDS-' + Date.now(),
  status: 'active',
};

function req(method, path, body) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const opts = {
      hostname: SUPABASE_HOST,
      port: 443,
      path,
      method,
      headers: {
        'Content-Type': 'application/json',
        apikey: ANON_KEY,
        Authorization: `Bearer ${ANON_KEY}`,
        Prefer: 'return=representation',
      },
    };
    const r = https.request(opts, (res) => {
      let b = '';
      res.on('data', (c) => (b += c));
      res.on('end', () => resolve({ status: res.statusCode, body: b }));
    });
    r.on('error', reject);
    if (data) r.write(data);
    r.end();
  });
}

(async () => {
  console.log('Inserting customer:', customer.name);
  const res = await req('POST', '/rest/v1/customers', customer);
  console.log('Status:', res.status);
  console.log('Response:', res.body);
  if (res.status >= 200 && res.status < 300) {
    console.log('\n✅ Customer inserted.');
  } else {
    console.log('\n❌ Insert failed.');
    process.exitCode = 1;
  }
})();
