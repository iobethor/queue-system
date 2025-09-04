/**
 * Script to initialize the queue-system database.
 *
 * Reads SQL from the create_database.sql file and optional database-init.sql
 * to create tables and seed data. It uses the DATABASE_URL environment
 * variable to connect to an existing Postgres database.
 */

const { Pool } = require('pg');
const fs = require('fs').promises;
const path = require('path');

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) {
  console.error('DATABASE_URL environment variable is not defined');
  process.exit(1);
}

// Read SQL files relative to the project root. If a file is missing, it will be skipped.
async function readSql() {
  const files = ['create_database.sql', 'deployment/database-init.sql'];
  let sqlText = '';
  for (const file of files) {
    try {
      const filePath = path.join(process.cwd(), file);
      const buffer = await fs.readFile(filePath);
      sqlText += buffer.toString() + '\n';
    } catch (err) {
      console.warn(`Warning: failed to read ${file}: ${err.message}`);
    }
  }
  return sqlText;
}

// Remove CREATE DATABASE and \c commands since we are connecting to an existing database.
function sanitize(sql) {
  return sql
    .replace(/CREATE\s+DATABASE[^;]+;/gi, '')
    .replace(/\\c\s+\w+;?/gi, '');
}

async function run() {
  const sql = await readSql();
  const sanitized = sanitize(sql);
  const statements = sanitized
    .split(';')
    .map(s => s.trim())
    .filter(s => s.length > 0);

  const pool = new Pool({ connectionString: databaseUrl });
  const client = await pool.connect();
  try {
    for (const statement of statements) {
      try {
        await client.query(statement);
        console.log('Executed statement:', statement.substring(0, 80));
      } catch (err) {
        console.error('Error executing statement:', statement.substring(0, 80), err);
      }
    }
    console.log('Database initialization complete');
  } finally {
    client.release();
    await pool.end();
  }
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
