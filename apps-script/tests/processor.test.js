const test = require('node:test');
const assert = require('node:assert/strict');
const { loadGas } = require('./load');
const { MemoryStore, FakeSource, settingsFromDefaults, ctx } = require('./fakes');
const gas = loadGas();

// Test-only parser: reads a JSON body. Real parsers come from sample emails.
const jsonParser = (email) => JSON.parse(email.plain);
const mail = (id, day, subject, body, from = 'Airbnb <automated@airbnb.com>') => ({
  id, from, subject, date: new Date(`2026-11-${day}T09:00:00Z`), plainText: JSON.stringify(body),
});
const newBooking = { type: 'new', platform_booking_id: 'HM1', guest_name: 'Rahul S', guests_count: 2, check_in: '2026-11-20', check_out: '2026-11-24', guest_total_paid: 18400 };

test('booking then cancellation (out of order in inbox) ends cancelled', () => {
  const store = new MemoryStore(settingsFromDefaults(gas));
  const src = new FakeSource([
    mail('m2', '05', 'Reservation cancelled', { type: 'cancellation', platform_booking_id: 'HM1' }),
    mail('m1', '01', 'Reservation confirmed', newBooking),
  ]);
  const r = gas.runProcessor(store, src, ctx({ parserOverride: jsonParser }));
  assert.equal(r.created, 1);
  assert.equal(r.updated, 1);
  assert.equal(store.bookings.length, 1);
  assert.equal(store.bookings[0].status, 'cancelled');
  assert.equal(store.bookings[0].email_message_id, 'm1');
  assert.deepEqual(src.labels, [['m1', 'BookingApp/Processed'], ['m2', 'BookingApp/Processed']]);
});

test('second run does not reprocess the same messages', () => {
  const store = new MemoryStore(settingsFromDefaults(gas));
  const src = new FakeSource([mail('m1', '01', 'Reservation confirmed', newBooking)]);
  gas.runProcessor(store, src, ctx({ parserOverride: jsonParser }));
  const r = gas.runProcessor(store, src, ctx({ parserOverride: jsonParser }));
  assert.equal(r.processed, 0);
  assert.equal(store.bookings.length, 1);
  assert.equal(store.logs.length, 1);
});

test('same booking id resent in a new email is not duplicated', () => {
  const store = new MemoryStore(settingsFromDefaults(gas));
  const src = new FakeSource([mail('m1', '01', 'Reservation confirmed', newBooking), mail('m9', '02', 'Reservation reminder', newBooking)]);
  const r = gas.runProcessor(store, src, ctx({ parserOverride: jsonParser }));
  assert.equal(store.bookings.length, 1);
  assert.equal(r.unchanged, 1);
});

test('same booking id on two platforms are two bookings', () => {
  const store = new MemoryStore(settingsFromDefaults(gas));
  const src = new FakeSource([
    mail('m1', '01', 'Reservation confirmed', newBooking),
    mail('m2', '01', 'New booking', newBooking, 'Agoda <no-reply@agoda.com>'),
  ]);
  gas.runProcessor(store, src, ctx({ parserOverride: jsonParser }));
  assert.deepEqual(store.bookings.map((b) => b.platform).sort(), ['Agoda', 'Airbnb']);
});

test('unparseable emails are logged and labelled Unparsed', () => {
  const store = new MemoryStore(settingsFromDefaults(gas));
  const src = new FakeSource([mail('m1', '01', 'Reservation confirmed', { ...newBooking, check_in: null })]);
  const r = gas.runProcessor(store, src, ctx({ parserOverride: jsonParser }));
  assert.equal(r.failed, 1);
  assert.equal(store.bookings.length, 0);
  assert.equal(store.logs[0].result, 'failed');
  assert.match(store.logs[0].error, /missing check_in/);
  assert.equal(store.logs[0].subject, 'Reservation confirmed');
  assert.deepEqual(src.labels, [['m1', 'BookingApp/Unparsed']]);
});

test('with the placeholder parsers, everything matched goes to Unparsed', () => {
  const store = new MemoryStore(settingsFromDefaults(gas));
  const src = new FakeSource([mail('m1', '01', 'Reservation confirmed', newBooking), mail('m2', '01', 'Hosting tips', {})]);
  const r = gas.runProcessor(store, src, ctx());
  assert.equal(r.failed, 1); // tips email is not a booking email: ignored, not logged
  assert.equal(store.logs.length, 1);
  assert.match(store.logs[0].error, /waiting for sample emails/);
});

test('hand edits survive a modification email; edit noted in log', () => {
  const store = new MemoryStore(settingsFromDefaults(gas), [{
    id: 'b1', platform: 'Airbnb', platform_booking_id: 'HM1', guest_name: 'Rahul S', check_in: '2026-11-20',
    check_out: '2026-11-24', guest_total_paid: 17000, status: 'confirmed', edited_fields: 'guest_total_paid',
  }]);
  const src = new FakeSource([mail('m3', '03', 'Reservation changed', { type: 'modification', platform_booking_id: 'HM1', check_out: '2026-11-25', guest_total_paid: 22000 })]);
  gas.runProcessor(store, src, ctx({ parserOverride: jsonParser }));
  assert.equal(store.bookings[0].guest_total_paid, 17000);
  assert.equal(store.bookings[0].check_out, '2026-11-25');
  assert.equal(store.bookings[0].nights, 5);
  assert.match(store.logs[0].error, /Kept your edits to: guest_total_paid/);
});

test('cancellation for unknown booking without dates does not create a row', () => {
  const store = new MemoryStore(settingsFromDefaults(gas));
  const src = new FakeSource([mail('m1', '01', 'Reservation cancelled', { type: 'cancellation', platform_booking_id: 'OLD' })]);
  gas.runProcessor(store, src, ctx({ parserOverride: jsonParser }));
  assert.equal(store.bookings.length, 0);
  assert.equal(store.logs[0].result, 'ok');
});

test('stops before the time limit and finishes on the next run', () => {
  const store = new MemoryStore(settingsFromDefaults(gas));
  const src = new FakeSource([mail('m1', '01', 'Reservation confirmed', newBooking), mail('m2', '02', 'Reservation confirmed', { ...newBooking, platform_booking_id: 'HM2' })]);
  let t = 1;
  const r = gas.runProcessor(store, src, ctx({ parserOverride: jsonParser, deadline: 1, clock: () => t++ }));
  assert.equal(r.timedOut, true);
  assert.equal(r.processed, 1);
  const r2 = gas.runProcessor(store, src, ctx({ parserOverride: jsonParser }));
  assert.equal(r2.processed, 1);
  assert.equal(store.bookings.length, 2);
});

test('past stays are marked completed', () => {
  const store = new MemoryStore(settingsFromDefaults(gas), [{ id: 'b1', platform: 'Direct', check_in: '2026-11-01', check_out: '2026-11-03', status: 'confirmed', edited_fields: '' }]);
  const r = gas.runProcessor(store, new FakeSource([]), ctx());
  assert.equal(r.completed, 1);
  assert.equal(store.bookings[0].status, 'completed');
});
