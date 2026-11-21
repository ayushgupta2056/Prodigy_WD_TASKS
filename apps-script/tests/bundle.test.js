const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { bundle } = require('../tools/bundle');

test('dist/BookingApp.gs is up to date (run `npm run bundle`)', () => {
  const dist = fs.readFileSync(path.join(__dirname, '..', 'dist', 'BookingApp.gs'), 'utf8');
  assert.equal(dist, bundle());
});
