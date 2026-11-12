// In-memory stand-ins for the Sheet and Gmail, matching the interfaces in
// src/40_Processor.gs.

function settingsFromDefaults(gas, overrides = {}) {
  const s = {};
  gas.DEFAULT_SETTINGS.forEach((r) => { s[r[0]] = r[1]; });
  return Object.assign(s, overrides);
}

class MemoryStore {
  constructor(settings, bookings = [], blocks = []) {
    this.settings = settings;
    this.bookings = bookings.map((b, i) => ({ ...b, _row: i + 2 }));
    this.blocks = blocks.map((b, i) => ({ ...b, _row: i + 2 }));
    this.logs = [];
  }
  static renumber(list) { list.forEach((x, i) => { x._row = i + 2; }); }
  getSettings() { return { ...this.settings }; }
  listBookings() { return this.bookings.map((b) => ({ ...b })); }
  insertBooking(b) { b._row = this.bookings.length + 2; this.bookings.push({ ...b }); return b; }
  updateBooking(b) {
    const i = this.bookings.findIndex((x) => x._row === b._row);
    if (i < 0) throw new Error('no row ' + b._row);
    this.bookings[i] = { ...this.bookings[i], ...b };
    return b;
  }
  listLogs() { return this.logs.map((l) => ({ ...l })); }
  appendLog(e) { e._row = this.logs.length + 2; this.logs.push({ ...e }); }
  updateLog(e) { const i = this.logs.findIndex((x) => x._row === e._row); this.logs[i] = { ...this.logs[i], ...e }; }
  listBlocks() { return this.blocks.map((b) => ({ ...b })); }
  insertBlock(b) { b._row = this.blocks.length + 2; this.blocks.push({ ...b }); }
  updateBlock(b) { const i = this.blocks.findIndex((x) => x._row === b._row); this.blocks[i] = { ...this.blocks[i], ...b }; }
  deleteBookingRow(row) { this.bookings = this.bookings.filter((b) => b._row !== row); MemoryStore.renumber(this.bookings); }
  deleteBlockRow(row) { this.blocks = this.blocks.filter((b) => b._row !== row); MemoryStore.renumber(this.blocks); }
  setSetting(k, v) { this.settings[k] = v; }
}

class FakeSource {
  constructor(emails) {
    this.emails = emails.map((e) => ({
      threadId: 't-' + e.id, plainText: '', htmlText: '', ...e,
      plain() { return this.plainText; }, html() { return this.htmlText; },
    }));
    this.labels = [];
    this.queries = [];
  }
  search(q) { this.queries.push(q); return this.emails.slice(); }
  label(email, name) { this.labels.push([email.id, name]); }
}

function ctx(extra = {}) {
  let n = 0;
  return {
    nowIso: '2026-11-12T10:00:00+05:30',
    todayIso: '2026-11-12',
    newId: () => 'id-' + (++n),
    ...extra,
  };
}

module.exports = { MemoryStore, FakeSource, settingsFromDefaults, ctx };
