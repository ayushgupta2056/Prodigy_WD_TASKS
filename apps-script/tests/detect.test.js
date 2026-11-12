const test = require('node:test');
const assert = require('node:assert/strict');
const { loadGas } = require('./load');
const { settingsFromDefaults } = require('./fakes');
const gas = loadGas();
const filters = gas.buildFilters(settingsFromDefaults(gas));

test('sender domain + subject pick the platform', () => {
  assert.equal(gas.detectPlatform('Airbnb <automated@airbnb.com>', 'Reservation confirmed', filters), 'Airbnb');
  assert.equal(gas.detectPlatform('noreply@email.makemytrip.com', 'New Booking', filters), 'MakeMyTrip');
  assert.equal(gas.detectPlatform('Booking.com <noreply@booking.com>', 'Cancellation', filters), 'Booking.com');
  assert.equal(gas.detectPlatform('x@goibibo.com', 'booking', filters), 'Goibibo');
  assert.equal(gas.detectPlatform('x@agoda.com', 'Reservation', filters), 'Agoda');
});

test('marketing mail and look-alike domains are ignored', () => {
  assert.equal(gas.detectPlatform('Airbnb <news@airbnb.com>', 'Tips for hosts this winter', filters), null);
  assert.equal(gas.detectPlatform('evil@notairbnb.com', 'Reservation confirmed', filters), null);
  assert.equal(gas.detectPlatform('friend@gmail.com', 'booking', filters), null);
});

test('gmail query covers every sender', () => {
  assert.equal(gas.buildGmailQuery(filters, 30),
    'from:(airbnb.com OR makemytrip.com OR goibibo.com OR agoda.com OR booking.com) newer_than:30d');
});

test('validation rejects incomplete parses', () => {
  const ok = { type: 'new', platform_booking_id: 'X1', guest_name: 'A', check_in: '2026-11-12', check_out: '2026-11-14', guest_total_paid: 5000 };
  assert.equal(gas.validateParsed(ok).length, 0);
  assert.ok(gas.validateParsed({ ...ok, guest_total_paid: null }).length);
  assert.ok(gas.validateParsed({ ...ok, check_out: '2026-11-12' }).length);
  assert.ok(gas.validateParsed({ ...ok, type: 'hello' }).length);
  assert.equal(gas.validateParsed({ type: 'cancellation', platform_booking_id: 'X1' }).length, 0);
  assert.ok(gas.validateParsed({ type: 'modification', platform_booking_id: 'X1' }).length);
});

test('placeholder parsers refuse to guess', () => {
  for (const p of gas.APP.EMAIL_PLATFORMS) {
    assert.throws(() => gas.parseEmail(p, { subject: 's', plain: '', html: '' }), /waiting for sample emails/);
  }
});
