const test = require('node:test');
const assert = require('node:assert/strict');
const { loadGas, plain } = require('./load');
const gas = loadGas();

test('nights between dates', () => {
  assert.equal(gas.nightsBetween('2026-11-12', '2026-11-16'), 4);
  assert.equal(gas.nightsBetween('2026-12-30', '2027-01-02'), 3);
  assert.equal(gas.nightsBetween('2028-02-28', '2028-03-01'), 2); // leap year
  assert.equal(gas.nightsBetween('2026-11-16', '2026-11-12'), 0);
  assert.equal(gas.nightsBetween('', '2026-11-12'), 0);
});

test('financials: example from the brief', () => {
  const f = plain(gas.bookingFinancials({
    check_in: '2026-11-12', check_out: '2026-11-16',
    guest_total_paid: 18400, in_hand_amount: 15640, costs: 1200,
  }));
  assert.deepEqual(f, {
    nights: 4, guest_paid: 18400, in_hand: 15640, costs: 1200,
    platform_cut: 2760, platform_cut_pct: 15, profit: 14440,
    in_hand_per_night: 3910, pending_in_hand: false,
  });
});

test('financials: no in-hand yet means pending, nothing guessed', () => {
  const f = gas.bookingFinancials({ check_in: '2026-11-12', check_out: '2026-11-14', guest_total_paid: 9000, in_hand_amount: '' });
  assert.equal(f.pending_in_hand, true);
  assert.equal(f.platform_cut, null);
  assert.equal(f.profit, null);
  assert.equal(f.in_hand_per_night, null);
  assert.equal(f.costs, 0);
});

test('financials: amounts stored as text with ₹ and commas', () => {
  const f = gas.bookingFinancials({ check_in: '2026-11-01', check_out: '2026-11-04', guest_total_paid: '₹12,450.00', in_hand_amount: 'Rs. 10,000', costs: '' });
  assert.equal(f.platform_cut, 2450);
  assert.equal(f.platform_cut_pct, 19.68);
  assert.equal(f.profit, 10000);
  assert.equal(f.in_hand_per_night, 3333.33);
});

test('financials: zero guest paid gives no cut %', () => {
  const f = gas.bookingFinancials({ check_in: '2026-11-01', check_out: '2026-11-02', guest_total_paid: 0, in_hand_amount: 0 });
  assert.equal(f.platform_cut_pct, null);
});
