const express = require("express");
const { Pool } = require("pg");
const crypto = require("crypto");

const app = express();
app.use(express.json({ limit: "10kb" }));

const pool = new Pool({
  host: process.env.DB_HOST || "localhost",
  port: +(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || "minipoll",
  password: process.env.DB_PASSWORD || "minipoll",
  database: process.env.DB_NAME || "minipoll",
  ssl: process.env.DB_SSL === "true" ? { rejectUnauthorized: false } : false,
});

async function initDb(retries = 20) {
  for (let i = 0; i < retries; i++) {
    try {
      await pool.query(`
        CREATE TABLE IF NOT EXISTS polls (
          id TEXT PRIMARY KEY, question TEXT NOT NULL,
          created_at TIMESTAMPTZ DEFAULT now());
        CREATE TABLE IF NOT EXISTS options (
          id SERIAL PRIMARY KEY, poll_id TEXT REFERENCES polls(id) ON DELETE CASCADE,
          label TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS votes (
          id SERIAL PRIMARY KEY, option_id INT REFERENCES options(id) ON DELETE CASCADE,
          poll_id TEXT NOT NULL, created_at TIMESTAMPTZ DEFAULT now());
        CREATE INDEX IF NOT EXISTS votes_poll_idx ON votes(poll_id);`);
      console.log("database ready");
      return;
    } catch (e) {
      console.log(`waiting for database (${e.message})`);
      await new Promise((r) => setTimeout(r, 3000));
    }
  }
  process.exit(1);
}

// Liveness: process is up. Readiness: database reachable.
app.get("/api/healthz", (_req, res) => res.json({ ok: true }));
app.get("/api/readyz", async (_req, res) => {
  try { await pool.query("SELECT 1"); res.json({ ready: true }); }
  catch { res.status(503).json({ ready: false }); }
});

app.post("/api/polls", async (req, res) => {
  const question = String(req.body.question || "").trim().slice(0, 200);
  const options = (req.body.options || []).map((o) => String(o).trim().slice(0, 100)).filter(Boolean);
  if (!question || options.length < 2 || options.length > 8)
    return res.status(400).json({ error: "Add a question and 2 to 8 options." });
  const id = crypto.randomBytes(4).toString("hex");
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("INSERT INTO polls(id, question) VALUES($1,$2)", [id, question]);
    for (const label of options)
      await client.query("INSERT INTO options(poll_id,label) VALUES($1,$2)", [id, label]);
    await client.query("COMMIT");
    res.status(201).json({ id });
  } catch (e) {
    await client.query("ROLLBACK"); res.status(500).json({ error: "Could not create poll." });
  } finally { client.release(); }
});

async function getResults(id) {
  const p = await pool.query("SELECT id, question FROM polls WHERE id=$1", [id]);
  if (!p.rows.length) return null;
  const o = await pool.query(
    `SELECT o.id, o.label, COUNT(v.id)::int AS votes FROM options o
     LEFT JOIN votes v ON v.option_id=o.id WHERE o.poll_id=$1
     GROUP BY o.id ORDER BY o.id`, [id]);
  const total = o.rows.reduce((s, r) => s + r.votes, 0);
  return { ...p.rows[0], total, options: o.rows };
}

app.get("/api/polls/:id", async (req, res) => {
  const r = await getResults(req.params.id);
  r ? res.json(r) : res.status(404).json({ error: "Poll not found." });
});
app.get("/api/polls/:id/results", async (req, res) => {
  const r = await getResults(req.params.id);
  r ? res.json(r) : res.status(404).json({ error: "Poll not found." });
});

app.post("/api/polls/:id/vote", async (req, res) => {
  const optionId = parseInt(req.body.optionId, 10);
  const r = await pool.query(
    "INSERT INTO votes(option_id, poll_id) SELECT id, poll_id FROM options WHERE id=$1 AND poll_id=$2 RETURNING id",
    [optionId, req.params.id]);
  if (!r.rows.length) return res.status(400).json({ error: "Pick a valid option." });
  res.status(201).json({ ok: true });
});

// Optional demo endpoints for load tests and alerts. Off unless ENABLE_DEBUG=true.
if (process.env.ENABLE_DEBUG === "true") {
  app.get("/api/debug/burn", (_req, res) => {
    const end = Date.now() + 300; while (Date.now() < end) Math.sqrt(Math.random());
    res.json({ burned: true });
  });
  app.get("/api/debug/crash", () => setTimeout(() => process.exit(1), 50));
}

initDb().then(() => app.listen(3000, () => console.log("minipoll api on :3000")));
