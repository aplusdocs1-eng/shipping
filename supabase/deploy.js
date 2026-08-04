const fs = require('fs');
const https = require('https');

const SUPABASE_URL = 'biuydcyyqeutfddxtruu.supabase.co';
const DB_PASS = process.argv[2] || 'Alphanso8989';

// Read SQL file
const sql = fs.readFileSync('./supabase/schema.sql', 'utf8');

// Split into individual statements (skip empty ones)
const statements = sql
  .split(/;\s*\n/)
  .map(s => s.trim())
  .filter(s => s.length > 0 && !s.startsWith('--'));

console.log(`Found ${statements.length} SQL statements to execute.\n`);

// Use Supabase's PostgREST won't work for DDL, so let's use
// the pg REST SQL endpoint with service role or try management API.
// Actually, let's use the Supabase pg-meta query endpoint.

// Try executing via the REST SQL API
async function executeSQL(sqlText) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({ query: sqlText });
    
    const options = {
      hostname: SUPABASE_URL,
      port: 443,
      path: '/rest/v1/rpc/',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': 'sb_publishable_vsEIUhzsOGFY6HYKGeDGMA_eZ_ffdp-',
        'Authorization': 'Bearer sb_publishable_vsEIUhzsOGFY6HYKGeDGMA_eZ_ffdp-',
      }
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => resolve({ status: res.statusCode, body }));
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

// Use the pg module via npx or direct postgres connection
// Since we can't use PostgREST for DDL, let's just use fetch to supabase management
// Actually, let's use the simpler approach: use the supabase-js createClient + sql template

// Use pg module for direct postgres connection

async function main() {
  let pg;
  try {
    pg = require('pg');
  } catch(e) {
    console.log('pg not installed, installing...');
    const { execSync } = require('child_process');
    execSync('npm install pg --no-save', { stdio: 'inherit', cwd: __dirname });
    pg = require('pg');
  }

  const client = new pg.Client({
    host: `db.biuydcyyqeutfddxtruu.supabase.co`,
    port: 5432,
    database: 'postgres',
    user: 'postgres',
    password: DB_PASS,
    ssl: { rejectUnauthorized: false }
  });

  try {
    console.log('Connecting to Supabase Postgres...');
    await client.connect();
    console.log('Connected!\n');

    console.log('Executing schema migration...');
    await client.query(sql);
    console.log('\n✅ All tables created successfully!');

    // Verify tables
    const res = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      AND table_type = 'BASE TABLE'
      ORDER BY table_name;
    `);
    console.log(`\nTables in database (${res.rows.length}):`);
    res.rows.forEach(r => console.log(`  - ${r.table_name}`));

  } catch(err) {
    console.error('Error:', err.message);
  } finally {
    await client.end();
  }
}

main();
