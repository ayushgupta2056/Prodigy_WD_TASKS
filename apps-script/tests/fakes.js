// In-memory stand-ins for the Sheet and Gmail, matching the interfaces in
// src/40_Processor.gs.

function settingsFromDefaults(gas, overrides = {}) {
  const s = {};
  gas.DEFAULT_SETTINGS.forEach((r) => { s[r[0]] = r[1]; });
  return Object.assign(s, overrides);
}

class MemoryStore {
  constructor(settings, bookings = []) {
    this.settings = settings;
    this.bookings = bookings.map((b, i) => ({ ...b, _row: i + 2 }));
    this.logs = [];
  }
  getSettings() { return { ...this.settings }; }
  listBookings() { return this.bookings.map((b) => ({ ...b })); }
  insertBooking(b) { b._row = this.bookings.length + 2; this.bookings.push({ ...b }); return b; }
  updateBooking(b) {
    const i = this.bookings.findIndex((x) => x._row === b._row);
    if (i < 0) throw new Error('no row ' + b._row);
    this.bookings[i] = { ...this.bookings[i], ...b };
    return b;
  }
  processedMessageIds() { const s = {}; this.logs.forEach((l) => { s[l.email_message_id] = true; }); return s; }
  appendLog(e) { this.logs.push({ ...e }); }
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
