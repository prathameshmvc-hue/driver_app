// Reads trips from Google Sheet (service account, read-only), caches, serves to app.
// Env: SHEET_ID, TAB_NAME, GOOGLE_APPLICATION_CREDENTIALS, APP_API_KEY, PORT, REFRESH_MIN
const express = require('express');
const fs = require('fs');
const crypto = require('crypto');

const { SHEET_ID, TAB_NAME = 'Sheet1', APP_API_KEY, PORT = 3000 } = process.env;
const REFRESH_MS = Number(process.env.REFRESH_MIN || 10) * 60 * 1000;
if (!SHEET_ID || !APP_API_KEY) throw new Error('SHEET_ID and APP_API_KEY are required');

let cache = { trips: new Map(), updatedAt: null };

// --- Google auth with built-in fetch (no googleapis library) ---
let tok = { value: null, exp: 0 };
const b64u = (x) => Buffer.from(x).toString('base64url');

async function getToken() {
  if (tok.value && Date.now() < tok.exp - 60000) return tok.value;
  const key = JSON.parse(fs.readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS, 'utf8'));
  const now = Math.floor(Date.now() / 1000);
  const unsigned = b64u(JSON.stringify({ alg: 'RS256', typ: 'JWT' })) + '.' + b64u(JSON.stringify({
    iss: key.client_email,
    scope: 'https://www.googleapis.com/auth/spreadsheets.readonly',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now, exp: now + 3600,
  }));
  const sig = crypto.createSign('RSA-SHA256').update(unsigned).sign(key.private_key, 'base64url');
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: unsigned + '.' + sig,
    }),
  });
  const j = await r.json();
  if (!r.ok) throw new Error('token ' + r.status + ' ' + (j.error_description || j.error));
  tok = { value: j.access_token, exp: Date.now() + j.expires_in * 1000 };
  return tok.value;
}

async function fetchRows() {
  const t = await getToken();
  const range = encodeURIComponent(`${TAB_NAME}!A:Z`);
  const r = await fetch(`https://sheets.googleapis.com/v4/spreadsheets/${SHEET_ID}/values/${range}`, {
    headers: { Authorization: 'Bearer ' + t },
  });
  const j = await r.json();
  if (!r.ok) throw new Error('sheets ' + r.status + ' ' + (j.error && j.error.message));
  return j.values || [];
}

async function loadSheet() {
  const [head = [], ...rows] = await fetchRows();
  const h = head.map((x) => String(x).trim());
  const trips = new Map();
  for (const row of rows) {
    const o = {};
    h.forEach((k, i) => (o[k] = (row[i] ?? '').toString().trim()));
    const id = o['Ref ID'];
    if (!id) continue;
    if (!trips.has(id)) trips.set(id, { rows: [] });
    trips.get(id).rows.push(o);
  }
  const out = new Map();
  for (const [id, { rows }] of trips) {
    // 'Timestamp' is 'YYYY-MM-DD HH:mm:ss', so string sort = time sort
    rows.sort((a, b) => (a.Timestamp || '').localeCompare(b.Timestamp || ''));
    const last = rows[rows.length - 1];
    const f = rows[0];
    const withLoc = rows.find((x) => x.Lat && x.Long) || {};
    out.set(id, {
      refId: id,
      warehouse: f['Warehouse Name'],
      facilityId: f['Facility ID'],
      date: f['Search Date'],
      route: f['Route'],
      status: last['Trip Status'],            // source of truth: Trip Status column
      vendor: f['Vendor Name'],
      vehicleNumber: f['Vehicle Number'],
      vehicleType: f['Vehicle Type'],
      tripType: f['Trip_Type'],
      lastEvent: last['Event Name'],
      lastEventTime: last['Timestamp'],
      ds: { lat: parseFloat(withLoc.Lat) || null, lng: parseFloat(withLoc.Long) || null },
      // User and Remarks columns are intentionally never exposed (PII)
      events: rows.map((x) => ({ event: x['Event Name'], time: x['Timestamp'] })),
    });
  }
  cache = { trips: out, updatedAt: new Date().toISOString() };
  console.log(`sheet loaded: ${out.size} trips`);
}

async function refresh() {
  try { await loadSheet(); } catch (e) { console.error('refresh failed:', e.message); }
}

const app = express();
app.use((req, res, next) => {
  if (req.path === '/health') return next();
  if (req.get('x-api-key') !== APP_API_KEY) return res.status(401).json({ error: 'unauthorized' });
  next();
});

app.use(express.json({ limit: '10kb' }));

// ---- Live driver location + 100 m geofence (in memory only, no persistence) ----
const ARRIVE_M = Number(process.env.ARRIVE_M || 100);   // enter radius
const LEAVE_M = Number(process.env.LEAVE_M || 150);     // reset radius (hysteresis)
const MAX_ACC_M = Number(process.env.MAX_ACC_M || 50);  // ignore poor GPS fixes
const locations = new Map(); // refId -> { distanceM, arrived, arrivedAt, ts }

function haversineM(lat1, lon1, lat2, lon2) {
  const R = 6371000, r = (d) => (d * Math.PI) / 180;
  const a = Math.sin(r(lat2 - lat1) / 2) ** 2 +
    Math.cos(r(lat1)) * Math.cos(r(lat2)) * Math.sin(r(lon2 - lon1) / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

// Only distance and arrival state are exposed, never raw driver coordinates.
function withLive(t) {
  const { events, ...rest } = t;
  const l = locations.get(t.refId);
  if (!l) return rest;
  return { ...rest, live: {
    distanceM: Math.round(l.distanceM),
    arrived: l.arrived,
    arrivedAt: l.arrivedAt,
    ageSec: Math.round((Date.now() - l.ts) / 1000),
  } };
}

setInterval(() => {
  const cutoff = Date.now() - 12 * 3600 * 1000;
  for (const [k, v] of locations) if (v.ts < cutoff) locations.delete(k);
}, 3600 * 1000);

// POST /location  { refId, lat, lng, accuracy }   (driver app, every ~5 s)
app.post('/location', (req, res) => {
  const { refId, lat, lng, accuracy } = req.body || {};
  const trip = cache.trips.get(String(refId || ''));
  if (!trip) return res.status(404).json({ error: 'trip not found' });
  if (typeof lat !== 'number' || typeof lng !== 'number' ||
      lat < -90 || lat > 90 || lng < -180 || lng > 180)
    return res.status(400).json({ error: 'bad coordinates' });
  if (trip.ds.lat == null || trip.ds.lng == null)
    return res.status(409).json({ error: 'trip has no darkstore coordinates' });
  if (typeof accuracy === 'number' && accuracy > MAX_ACC_M)
    return res.json({ ok: true, ignored: 'low accuracy' });

  const d = haversineM(lat, lng, trip.ds.lat, trip.ds.lng);
  const prev = locations.get(refId) || { arrived: false, arrivedAt: null };
  let { arrived, arrivedAt } = prev;
  if (!arrived && d <= ARRIVE_M) { arrived = true; arrivedAt = new Date().toISOString(); }
  else if (arrived && d > LEAVE_M) { arrived = false; }
  locations.set(refId, { distanceM: d, arrived, arrivedAt, ts: Date.now() });
  res.json({ ok: true, distanceM: Math.round(d), arrived });
});

app.get('/health', (_q, res) => res.json({ ok: true, updatedAt: cache.updatedAt, trips: cache.trips.size }));

// GET /trips?date=2026-10-26&warehouse=ahm_112_wh_hl_01&status=COMPLETED
app.get('/trips', (req, res) => {
  const { date, facilityId, warehouse, status } = req.query;
  const list = [...cache.trips.values()].filter((t) =>
    (!date || t.date === date) &&
    (!facilityId || t.facilityId === facilityId) &&
    (!warehouse || t.warehouse.toLowerCase() === String(warehouse).trim().toLowerCase()) &&
    (!status || t.status.toLowerCase() === String(status).toLowerCase())).map(withLive);
  res.json({ updatedAt: cache.updatedAt, count: list.length, trips: list });
});

// GET /trips/:refId  (also used to validate a driver's Trip ID at login)
app.get('/trips/:refId', (req, res) => {
  const t = cache.trips.get(req.params.refId);
  if (!t) return res.status(404).json({ error: 'trip not found' });
  res.json({ ...withLive(t), events: t.events });
});

app.listen(PORT, async () => {
  console.log(`listening on ${PORT}`);
  await refresh();
  setInterval(refresh, REFRESH_MS);
});
