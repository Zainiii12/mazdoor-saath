// In-memory Firestore stand-in for the integration test suite.
//
// WHY: the suite normally runs against the Firestore emulator, but some
// sandboxes/CI environments block the emulator's gRPC (HTTP/2) transport.
// With FIRESTORE_FAKE=true, src/config/firebase.js exports this instead of
// the Admin SDK — no Java, no emulator, no credentials needed.
//
// SCOPE: implements exactly the Firestore surface the backend uses —
// collections, doc refs, where/orderBy/limit queries, write batches,
// transactions, serverTimestamp — with Firestore-like semantics for the
// filter operators and ordering the routes rely on (==, array-contains,
// in; orderBy on dates). It is a test double, not a Firestore emulator:
// it does not enforce composite indexes or security rules.
//
// TEST-ONLY. Never used in production.

const AUTO_ID_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

function autoId() {
  let s = '';
  for (let i = 0; i < 20; i++) {
    s += AUTO_ID_CHARS[Math.floor(Math.random() * AUTO_ID_CHARS.length)];
  }
  return s;
}

/** serverTimestamp() replacement: resolved to `new Date()` at write time. */
export function fakeServerTimestamp() {
  return { __fakeServerTimestamp: true };
}

function isTimestampMarker(v) {
  return (
    v !== null &&
    typeof v === 'object' &&
    !Array.isArray(v) &&
    v.__fakeServerTimestamp === true
  );
}

function resolveMarkersDeep(value) {
  if (isTimestampMarker(value)) return new Date();
  if (Array.isArray(value)) return value.map(resolveMarkersDeep);
  if (value !== null && typeof value === 'object' && value.constructor === Object) {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = resolveMarkersDeep(v);
    return out;
  }
  return value;
}

function clone(value) {
  return structuredClone(value);
}

function getPath(obj, path) {
  return String(path)
    .split('.')
    .reduce((o, k) => (o === null || o === undefined ? undefined : o[k]), obj);
}

function setPath(obj, path, value) {
  const parts = String(path).split('.');
  let o = obj;
  for (let i = 0; i < parts.length - 1; i++) {
    if (o[parts[i]] === null || typeof o[parts[i]] !== 'object') o[parts[i]] = {};
    o = o[parts[i]];
  }
  o[parts[parts.length - 1]] = value;
}

// Firestore ordering (simplified): null/undefined sort before everything
// in ascending order; otherwise numbers, Dates and strings compare naturally.
function compareValues(a, b) {
  const rank = (v) => (v === undefined || v === null ? 0 : 1);
  const ra = rank(a);
  const rb = rank(b);
  if (ra !== rb) return ra - rb;
  if (ra === 0) return 0;
  if (a instanceof Date && b instanceof Date) return a.getTime() - b.getTime();
  if (typeof a === 'number' && typeof b === 'number') return a - b;
  const sa = String(a);
  const sb = String(b);
  return sa < sb ? -1 : sa > sb ? 1 : 0;
}

function matchesFilter(docData, { field, op, value }) {
  const v = getPath(docData, field);
  switch (op) {
    case '==':
      if (value === null || value === undefined)
        return v === null || v === undefined;
      return compareValues(v, value) === 0;
    case 'array-contains':
      return Array.isArray(v) && v.some((x) => compareValues(x, value) === 0);
    case 'in':
      return Array.isArray(value) && value.some((x) => compareValues(v, x) === 0);
    case '>=':
      return compareValues(v, value) >= 0;
    case '<=':
      return compareValues(v, value) <= 0;
    case '>':
      return compareValues(v, value) > 0;
    case '<':
      return compareValues(v, value) < 0;
    default:
      throw new Error(`fake-firestore: unsupported where() operator "${op}"`);
  }
}

class FakeDocumentSnapshot {
  constructor(ref, data) {
    this._ref = ref;
    this._data = data === undefined ? undefined : clone(data);
  }
  get exists() {
    return this._data !== undefined;
  }
  get id() {
    return this._ref.id;
  }
  get ref() {
    return this._ref;
  }
  data() {
    return this._data === undefined ? undefined : clone(this._data);
  }
}

class FakeQuerySnapshot {
  constructor(docs) {
    this._docs = docs;
  }
  get docs() {
    return this._docs;
  }
  get empty() {
    return this._docs.length === 0;
  }
  get size() {
    return this._docs.length;
  }
  forEach(fn) {
    this._docs.forEach(fn);
  }
}

class FakeDocumentReference {
  constructor(firestore, collectionName, id) {
    this._firestore = firestore;
    this._collectionName = collectionName;
    this._id = id;
  }
  get id() {
    return this._id;
  }
  get path() {
    return `${this._collectionName}/${this._id}`;
  }
  async get() {
    return new FakeDocumentSnapshot(this, this._firestore._read(this._collectionName, this._id));
  }
  async set(data, options = {}) {
    const resolved = resolveMarkersDeep(clone(data));
    if (options.merge) {
      const existing = this._firestore._read(this._collectionName, this._id) || {};
      this._firestore._write(this._collectionName, this._id, { ...clone(existing), ...resolved });
    } else {
      this._firestore._write(this._collectionName, this._id, resolved);
    }
  }
  async update(data) {
    const existing = this._firestore._read(this._collectionName, this._id);
    if (existing === undefined) {
      const err = new Error(`fake-firestore: document ${this.path} does not exist`);
      err.code = 5; // NOT_FOUND, like Firestore
      throw err;
    }
    const resolved = resolveMarkersDeep(clone(data));
    const merged = clone(existing);
    for (const [k, v] of Object.entries(resolved)) setPath(merged, k, v);
    this._firestore._write(this._collectionName, this._id, merged);
  }
  async delete() {
    this._firestore._delete(this._collectionName, this._id);
  }
}

class FakeQuery {
  constructor(firestore, collectionName, filters = [], orders = [], limitN = null) {
    this._firestore = firestore;
    this._collectionName = collectionName;
    this._filters = filters;
    this._orders = orders;
    this._limitN = limitN;
  }
  where(field, op, value) {
    return new FakeQuery(
      this._firestore,
      this._collectionName,
      [...this._filters, { field, op, value: clone(value) }],
      this._orders,
      this._limitN
    );
  }
  orderBy(field, direction = 'asc') {
    return new FakeQuery(
      this._firestore,
      this._collectionName,
      this._filters,
      [...this._orders, { field, direction }],
      this._limitN
    );
  }
  limit(n) {
    return new FakeQuery(this._firestore, this._collectionName, this._filters, this._orders, n);
  }
  async get() {
    const entries = this._firestore._allIn(this._collectionName);
    let docs = entries
      .filter(([, data]) => this._filters.every((f) => matchesFilter(data, f)))
      .map(([id, data]) => new FakeDocumentSnapshot(
        new FakeDocumentReference(this._firestore, this._collectionName, id),
        data
      ));
    if (this._orders.length > 0) {
      docs = docs
        .map((d, i) => [d, i])
        .sort(([da, ia], [db, ib]) => {
          for (const { field, direction } of this._orders) {
            const c = compareValues(getPath(da.data(), field), getPath(db.data(), field));
            if (c !== 0) return direction === 'desc' ? -c : c;
          }
          return ia - ib; // stable
        })
        .map(([d]) => d);
    }
    if (this._limitN !== null) docs = docs.slice(0, this._limitN);
    return new FakeQuerySnapshot(docs);
  }
}

class FakeCollectionReference extends FakeQuery {
  doc(id) {
    return new FakeDocumentReference(this._firestore, this._collectionName, id || autoId());
  }
  async add(data) {
    const ref = this.doc();
    await ref.set(data);
    return ref;
  }
}

class FakeWriteBatch {
  constructor(firestore) {
    this._firestore = firestore;
    this._ops = [];
  }
  set(ref, data, options) {
    this._ops.push(() => ref.set(data, options));
    return this;
  }
  update(ref, data) {
    this._ops.push(() => ref.update(data));
    return this;
  }
  delete(ref) {
    this._ops.push(() => ref.delete());
    return this;
  }
  async commit() {
    for (const op of this._ops) await op();
  }
}

class FakeTransaction {
  constructor(firestore) {
    this._firestore = firestore;
  }
  async get(refOrQuery) {
    return refOrQuery.get();
  }
  set(ref, data, options) {
    return ref.set(data, options);
  }
  update(ref, data) {
    return ref.update(data);
  }
  delete(ref) {
    return ref.delete();
  }
}

/** Minimal Timestamp stand-in (routes don't use it, but firebase.js exports it). */
export class FakeTimestamp {
  constructor(seconds, nanoseconds) {
    this.seconds = seconds;
    this.nanoseconds = nanoseconds;
  }
  toDate() {
    return new Date(this.seconds * 1000 + Math.floor(this.nanoseconds / 1e6));
  }
  static now() {
    return FakeTimestamp.fromDate(new Date());
  }
  static fromDate(date) {
    const ms = date.getTime();
    return new FakeTimestamp(Math.floor(ms / 1000), (ms % 1000) * 1e6);
  }
}

export class FakeFirestore {
  constructor() {
    this._docs = new Map(); // "collection/id" -> stored object
  }
  _read(collectionName, id) {
    const v = this._docs.get(`${collectionName}/${id}`);
    return v === undefined ? undefined : clone(v);
  }
  _write(collectionName, id, data) {
    this._docs.set(`${collectionName}/${id}`, clone(data));
  }
  _delete(collectionName, id) {
    this._docs.delete(`${collectionName}/${id}`);
  }
  _allIn(collectionName) {
    const out = [];
    const prefix = `${collectionName}/`;
    for (const [key, data] of this._docs) {
      if (key.startsWith(prefix)) out.push([key.slice(prefix.length), clone(data)]);
    }
    return out;
  }
  collection(name) {
    return new FakeCollectionReference(this, name);
  }
  batch() {
    return new FakeWriteBatch(this);
  }
  async runTransaction(updateFn) {
    return updateFn(new FakeTransaction(this));
  }
}

export function createFakeFirestore() {
  return new FakeFirestore();
}
