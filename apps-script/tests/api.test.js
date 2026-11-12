const test = require('node:test');
const assert = require('node:assert/strict');
const { loadGas, plain } = require('./load');
const { MemoryStore, settingsFromDefaults, ctx } = require('./fakes');
const gas = loadGas();

const emailBooking = {
  id: 'b1', property: 'My Homestay', platform: 'Airbnb', platform_booking_id: 'HM1', guest_name: 'Rahul S', guests_count: 2,
  check_in: '2026-11-20', check_out: '2026-11-24', nights: 4, guest_total_paid: 18400, in_hand_amount: '', costs: 0,
  status: 'confirmed', source: 'email', edited_fields: '', email_message_id: 'm1', notes: '',
};
const op = (type, payload, id = 'op') => ({ op_id: id, type, payload });
const store0 = () => new MemoryStore(settingsFromDefaults(gas), [emailBooking]);

test('editing an emailed booking records edited_fields (not for in-hand/costs/notes)', () => {
  const s = store0();
  const [r] = gas.applyOps(s, [op('upsertBooking', { booking: { ...emailBooking, guest_total_paid: '17,900', in_hand_amount: 15000, costs: 800, notes: 'hi' } })], ctx());
  assert.equal(r.ok, true, r.error);
  assert.equal(s.bookings[0].guest_total_paid, 17900);
  assert.equal(s.bookings[0].in_hand_amount, 15000);
  assert.equal(s.bookings[0].edited_fields, 'guest_total_paid');
});

test('sending the same booking again changes nothing (idempotent)', () => {
  const s = store0();
  const [r] = gas.applyOps(s, [op('upsertBooking', { booking: emailBooking })], ctx());
  assert.equal(r.data.unchanged, true);
  assert.equal(s.bookings[0].edited_fields, '');
});

test('manual booking create, edit and delete', () => {
  const s = store0();
  const nb = { id: 'local-1', platform: 'Direct', guest_name: 'Anita', check_in: '2026-12-01', check_out: '2026-12-03', guest_total_paid: 6000, in_hand_amount: 6000 };
  let res = gas.applyOps(s, [op('upsertBooking', { booking: nb }, 'a'), op('upsertBooking', { booking: { ...nb, check_out: '2026-12-04' } }, 'b')], ctx());
  assert.ok(res.every((r) => r.ok), JSON.stringify(res));
  const m = s.bookings.find((b) => b.id === 'local-1');
  assert.equal(m.source, 'manual');
  assert.equal(m.nights, 3);
  assert.equal(m.edited_fields, '');
  res = gas.applyOps(s, [op('deleteBooking', { id: 'local-1' }), op('deleteBooking', { id: 'local-1' })], ctx());
  assert.ok(res.every((r) => r.ok));
  assert.equal(s.bookings.length, 1);
});

test('emailed bookings can be cancelled but not deleted', () => {
  const s = store0();
  const [del] = gas.applyOps(s, [op('deleteBooking', { id: 'b1' })], ctx());
  assert.equal(del.ok, false);
  assert.match(del.error, /cannot|not be deleted|but not deleted/);
  const [c] = gas.applyOps(s, [op('cancelBooking', { id: 'b1' })], ctx());
  assert.equal(c.ok, true);
  assert.equal(s.bookings[0].status, 'cancelled');
  assert.equal(s.bookings[0].edited_fields, 'status');
});

test('bad input is rejected per op, others still apply', () => {
  const s = store0();
  const res = gas.applyOps(s, [
    op('upsertBooking', { booking: { id: 'x', check_in: '2026-12-05', check_out: '2026-12-05' } }, '1'),
    op('upsertBooking', { booking: { id: 'y', platform: 'Hotels.com', check_in: '2026-12-01', check_out: '2026-12-02' } }, '2'),
    op('upsertBooking', { booking: { id: 'z', in_hand_amount: -5, check_in: '2026-12-01', check_out: '2026-12-02' } }, '3'),
    op('upsertBlock', { block: { id: 'k1', start_date: '2026-12-10', end_date: '2026-12-12', reason: 'maintenance' } }, '4'),
    op('nope', {}, '5'),
  ], ctx());
  assert.deepEqual(res.map((r) => r.ok), [false, false, false, true, false]);
  assert.equal(s.blocks.length, 1);
});

test('blocks: create, edit, delete, validation', () => {
  const s = store0();
  gas.applyOps(s, [op('upsertBlock', { block: { id: 'k1', property: 'My Homestay', start_date: '2026-12-10', end_date: '2026-12-12', reason: 'personal use' } })], ctx());
  gas.applyOps(s, [op('upsertBlock', { block: { id: 'k1', end_date: '2026-12-14' } })], ctx());
  assert.equal(s.blocks[0].end_date, '2026-12-14');
  assert.equal(s.blocks[0].reason, 'personal use');
  const [bad] = gas.applyOps(s, [op('upsertBlock', { block: { id: 'k2', start_date: '2026-12-10', end_date: '2026-12-09', reason: 'held' } })], ctx());
  assert.equal(bad.ok, false);
  gas.applyOps(s, [op('deleteBlock', { id: 'k1' })], ctx());
  assert.equal(s.blocks.length, 0);
});

test('creating a booking from an unparsed email resolves it', () => {
  const s = store0();
  s.appendLog({ email_message_id: 'mX', thread_id: 'tX', platform: 'Agoda', result: 'failed', subject: 'Booking 55', error: 'x', resolved: '' });
  let snap = gas.buildSnapshot(s, ctx());
  assert.equal(snap.unparsed.length, 1);
  assert.equal(snap.unparsed[0].gmail_url, 'https://mail.google.com/mail/u/0/#all/tX');
  gas.applyOps(s, [op('upsertBooking', { booking: { id: 'n1', platform: 'Agoda', platform_booking_id: '55', email_message_id: 'mX', check_in: '2026-12-01', check_out: '2026-12-02' } })], ctx());
  snap = gas.buildSnapshot(s, ctx());
  assert.equal(snap.unparsed.length, 0);
  assert.equal(s.logs[0].booking_id, 'n1');
});

test('snapshot shapes values for the app', () => {
  const s = new MemoryStore(settingsFromDefaults(gas, { properties: 'Hill View, Lake Room' }), [{ ...emailBooking, guest_total_paid: '18400', edited_fields: 'guest_name,status' }]);
  const snap = plain(gas.buildSnapshot(s, ctx()));
  assert.deepEqual(snap.settings.properties, ['Hill View', 'Lake Room']);
  assert.equal(snap.bookings[0].guest_total_paid, 18400);
  assert.equal(snap.bookings[0].in_hand_amount, null);
  assert.deepEqual(snap.bookings[0].edited_fields, ['guest_name', 'status']);
  assert.equal('_row' in snap.bookings[0], false);
});

test('setProperties', () => {
  const s = store0();
  gas.applyOps(s, [op('setProperties', { properties: ['A', ' B, C '] })], ctx());
  assert.equal(s.settings.properties, 'A, B  C');
});
