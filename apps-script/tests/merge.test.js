const test = require('node:test');
const assert = require('node:assert/strict');
const { loadGas, plain } = require('./load');
const gas = loadGas();
const ctx = { nowIso: '2026-11-12T10:00:00+05:30' };

const base = {
  id: 'b1', platform: 'Airbnb', platform_booking_id: 'HM123', guest_name: 'Rahul S', guests_count: 2,
  check_in: '2026-11-12', check_out: '2026-11-16', nights: 4, guest_total_paid: 18400,
  in_hand_amount: 15640, costs: 500, status: 'confirmed', source: 'email', edited_fields: '', notes: 'late arrival',
};

test('modification updates dates, amount and nights', () => {
  const r = gas.mergeParsedIntoBooking(base, { type: 'modification', platform_booking_id: 'HM123', check_out: '2026-11-17', guest_total_paid: 22000 }, ctx);
  assert.deepEqual(plain(r.changed), ['check_out', 'guest_total_paid']);
  assert.equal(r.booking.nights, 5);
  assert.equal(r.booking.guest_total_paid, 22000);
  assert.equal(r.booking.updated_at, ctx.nowIso);
  assert.equal(base.check_out, '2026-11-16', 'input not mutated');
});

test('edited fields are never overwritten', () => {
  const edited = { ...base, edited_fields: 'guest_total_paid,guest_name' };
  const r = gas.mergeParsedIntoBooking(edited, { type: 'modification', platform_booking_id: 'HM123', guest_name: 'R Sharma', guest_total_paid: 99999, check_out: '2026-11-17' }, ctx);
  assert.equal(r.booking.guest_total_paid, 18400);
  assert.equal(r.booking.guest_name, 'Rahul S');
  assert.equal(r.booking.check_out, '2026-11-17');
  assert.deepEqual(plain(r.skipped), ['guest_name', 'guest_total_paid']);
});

test('in-hand, costs and notes are never touched by email', () => {
  const r = gas.mergeParsedIntoBooking(base, { type: 'new', platform_booking_id: 'HM123', in_hand_amount: 1, costs: 1, notes: 'x', guest_total_paid: 18400 }, ctx);
  assert.equal(r.booking.in_hand_amount, 15640);
  assert.equal(r.booking.costs, 500);
  assert.equal(r.booking.notes, 'late arrival');
  assert.equal(r.changed.length, 0);
});

test('cancellation marks cancelled, unless status was edited', () => {
  const c = { type: 'cancellation', platform_booking_id: 'HM123' };
  assert.equal(gas.mergeParsedIntoBooking(base, c, ctx).booking.status, 'cancelled');
  const r = gas.mergeParsedIntoBooking({ ...base, edited_fields: 'status' }, c, ctx);
  assert.equal(r.booking.status, 'confirmed');
  assert.deepEqual(plain(r.skipped), ['status']);
});

test('new booking from a parsed email', () => {
  const b = gas.newBookingFromParsed(
    { platform: 'Agoda', type: 'new', platform_booking_id: 987, guest_name: 'PRIYA K', guests_count: 3, check_in: '2026-12-24', check_out: '2026-12-27', guest_total_paid: 21000 },
    { id: 'msg1' }, { newId: () => 'new1', nowIso: ctx.nowIso, defaultProperty: 'My Homestay' });
  assert.equal(b.platform_booking_id, '987');
  assert.equal(b.guest_name, 'Priya K');
  assert.equal(b.nights, 3);
  assert.equal(b.in_hand_amount, '');
  assert.equal(b.costs, 0);
  assert.equal(b.status, 'confirmed');
  assert.equal(b.source, 'email');
  assert.equal(b.property, 'My Homestay');
});

test('stays past check-out become completed, unless status was edited', () => {
  const list = [
    { ...base, id: 'a', check_out: '2026-11-11' },
    { ...base, id: 'b', check_out: '2026-11-12' },
    { ...base, id: 'c', check_out: '2026-11-13' },
    { ...base, id: 'd', check_out: '2026-11-01', status: 'cancelled' },
    { ...base, id: 'e', check_out: '2026-11-01', edited_fields: 'status' },
  ];
  const done = gas.bookingsToComplete(list, '2026-11-12', ctx.nowIso);
  assert.deepEqual(plain(done.map((b) => b.id)), ['a', 'b']);
  assert.ok(done.every((b) => b.status === 'completed'));
});

test('edited_fields round trip', () => {
  assert.deepEqual(plain(gas.parseEditedFields(' a, b ,,c')), ['a', 'b', 'c']);
  assert.equal(gas.formatEditedFields(['a', 'b', 'a']), 'a,b');
});
