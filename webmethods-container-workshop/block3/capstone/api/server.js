// Capstone 3 - a tiny API that records every request in PostgreSQL.
// The visit counter lets you SEE whether the database volume survived.
const http = require('http');
const os = require('os');
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST || 'db',
  port: Number(process.env.DB_PORT || 5432),
  database: process.env.DB_NAME || 'shop',
  user: process.env.DB_USER || 'shop',
  password: process.env.DB_PASS,
});

const ready = pool.query(
  'CREATE TABLE IF NOT EXISTS visits (id serial PRIMARY KEY, at timestamptz DEFAULT now(), served_by text)'
);

http.createServer(async (req, res) => {
  try {
    await ready;
    await pool.query('INSERT INTO visits (served_by) VALUES ($1)', [os.hostname()]);
    const { rows } = await pool.query('SELECT count(*)::int AS visits, now() AS time FROM visits');
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', visits: rows[0].visits, time: rows[0].time, hostname: os.hostname() }) + '\n');
  } catch (e) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'error', error: e.message }) + '\n');
  }
}).listen(3000, () => console.log('API listening on :3000'));
