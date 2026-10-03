// Shared HTTP helpers: one JSON envelope and one async-error wrapper
// so every route behaves the same way.
//
// Success:  { ok: true,  data: <payload>, error: null }
// Failure:  { ok: false, data: null,     error: { message, details } }

/** Send a success response. */
export function ok(res, data = null, status = 200) {
  return res.status(status).json({ ok: true, data, error: null });
}

/** Send an error response. */
export function fail(res, status, message, details = null) {
  return res
    .status(status)
    .json({ ok: false, data: null, error: { message, details } });
}

/**
 * Wrap an async route handler so rejected promises are forwarded
 * to the central error middleware instead of hanging the request.
 *
 * Usage: router.get('/', ah(async (req, res) => { ... }));
 */
export function ah(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

/** True for finite numbers (accepts numeric strings too, rejects NaN/Infinity). */
export function toNumber(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

/** True when `value` is a YYYY-MM-DD calendar date. */
export function isDateString(value) {
  return (
    typeof value === 'string' &&
    /^\d{4}-\d{2}-\d{2}$/.test(value) &&
    !Number.isNaN(Date.parse(value))
  );
}
