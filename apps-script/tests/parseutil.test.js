const test = require('node:test');
const assert = require('node:assert/strict');
const { loadGas } = require('./load');
const gas = loadGas();

test('Indian money amounts', () => {
  const cases = {
    '₹12,450.00': 12450, '₹ 1,23,456': 123456, 'INR 18,400': 18400, 'Rs. 500/-': 500,
    'Rs 2,000.50': 2000.5, 'Total: ₹9,999': 9999, '-₹300': -300, '₹ 1,200': 1200,
    '12450': 12450, 'free': null, '': null,
  };
  for (const [input, want] of Object.entries(cases)) assert.equal(gas.parseAmount(input), want, input);
  assert.equal(gas.parseAmount(4500), 4500);
  assert.equal(gas.parseAmount(null), null);
});

test('amount after a label', () => {
  const text = 'Nightly rate ₹4,000\nTotal (INR)   ₹ 18,400.00\nPayout ₹15,640';
  assert.equal(gas.findAmountAfter(text, /total \(inr\)/i), 18400);
  assert.equal(gas.findAmountAfter(text, /payout/i), 15640);
  assert.equal(gas.findAmountAfter(text, /tax/i), null);
});

test('dates in common formats, day first', () => {
  const cases = {
    '2026-11-12': '2026-11-12', '12/11/2026': '2026-11-12', '12-11-2026': '2026-11-12',
    '12.11.26': '2026-11-12', '12 Nov 2026': '2026-11-12', '12-Nov-2026': '2026-11-12',
    '12th November, 2026': '2026-11-12', 'Nov 12, 2026': '2026-11-12',
    'Thu, 12 Nov 2026': '2026-11-12', 'Thursday, November 12, 2026': '2026-11-12',
    '1 Sept 2026': '2026-09-01', '31/02/2026': null, 'tomorrow': null,
  };
  for (const [input, want] of Object.entries(cases)) assert.equal(gas.parseDateFlexible(input), want, input);
});

test('dates without a year need a reference date', () => {
  assert.equal(gas.parseDateFlexible('Thu, Nov 12'), null);
  assert.equal(gas.parseDateFlexible('Thu, Nov 12', { refDate: '2026-11-01' }), '2026-11-12');
  assert.equal(gas.parseDateFlexible('Jan 5', { refDate: '2026-11-20' }), '2027-01-05');
  assert.equal(gas.parseDateFlexible('Oct 30', { refDate: '2026-11-20' }), '2026-10-30');
});

test('html to text', () => {
  const html = '<html><head><style>p{}</style></head><body><p>Guest:&nbsp;<b>RAHUL S</b></p><table><tr><td>Total</td><td>&#8377;18,400</td></tr></table></body></html>';
  assert.equal(gas.htmlToText(html), 'Guest: RAHUL S\nTotal\t₹18,400');
});

test('guest names', () => {
  assert.equal(gas.cleanName('  RAHUL   SHARMA '), 'Rahul Sharma');
  assert.equal(gas.cleanName('Priya d’Souza'), 'Priya d’Souza');
});
