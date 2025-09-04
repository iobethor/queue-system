import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

export async function initDb() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS departments (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        slug VARCHAR(255) UNIQUE NOT NULL
      );
    `);
    await client.query(`
      CREATE TABLE IF NOT EXISTS services (
        id SERIAL PRIMARY KEY,
        department_id INTEGER REFERENCES departments(id) ON DELETE CASCADE,
        name VARCHAR(255) NOT NULL,
        code VARCHAR(10) NOT NULL
      );
    `);
    // insert default if none exist
    const { rows: deptRows } = await client.query(`SELECT id FROM departments LIMIT 1`);
    let deptId;
    if (deptRows.length === 0) {
      const res = await client.query(`INSERT INTO departments (name, slug) VALUES ($1, $2) RETURNING id`, ['Default Department', 'default']);
      deptId = res.rows[0].id;
    } else {
      deptId = deptRows[0].id;
    }
    const { rows: serviceRows } = await client.query(`SELECT id FROM services LIMIT 1`);
    if (serviceRows.length === 0) {
      await client.query(`INSERT INTO services (department_id, name, code) VALUES ($1, $2, $3)`, [deptId, 'Default Service', 'DEF']);
    }
  } finally {
    client.release();
  }
}
