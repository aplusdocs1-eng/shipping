// Apply supabase/migration_partner_scoping.sql to the Supabase Postgres DB.
// Usage: node supabase/apply_migration.js [db_password]
const fs = require('fs');
const path = require('path');

const DB_PASS = process.argv[2] || 'Alphanso8989';
const sqlPath = path.join(__dirname, 'migration_partner_scoping.sql');
const sql = fs.readFileSync(sqlPath, 'utf8');

async function main() {
  let pg;
  try {
    pg = require('pg');
  } catch (e) {
    console.log('pg not installed, installing...');
    const { execSync } = require('child_process');
    execSync('npm install pg --no-save', { stdio: 'inherit', cwd: __dirname });
    pg = require('pg');
  }

  const client = new pg.Client({
    host: 'db.biuydcyyqeutfddxtruu.supabase.co',
    port: 5432,
    database: 'postgres',
    user: 'postgres',
    password: DB_PASS,
    ssl: { rejectUnauthorized: false },
  });

  try {
    console.log('Connecting to Supabase Postgres...');
    await client.connect();
    console.log('Connected. Applying migration_partner_scoping.sql...\n');
    await client.query(sql);
    console.log('✅ Migration applied.\n');

    const check = await client.query(`
      SELECT table_name, column_name
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND column_name = 'partner_id'
      ORDER BY table_name;
    `);
    console.log(`partner_id columns now present on ${check.rows.length} tables:`);
    check.rows.forEach(r => console.log(`  - ${r.table_name}.${r.column_name}`));
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exitCode = 1;
  } finally {
    await client.end();
  }
}

main();
