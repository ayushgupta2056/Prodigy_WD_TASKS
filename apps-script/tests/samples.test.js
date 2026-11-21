// Runs every platform parser on every sample email in ../samples/.
//
//   samples/<platform>/<name>.eml             the email (Gmail: ⋮ > Download message)
//   samples/<platform>/<name>.expected.json   what the parser must return
//
// Platform folders: airbnb, makemytrip, goibibo, agoda, booking.com
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { simpleParser } = require('mailparser');
const { loadGas, plain } = require('./load');
const gas = loadGas();

const SAMPLES = path.join(__dirname, '..', '..', 'samples');
const FOLDERS = { airbnb: 'Airbnb', makemytrip: 'MakeMyTrip', goibibo: 'Goibibo', agoda: 'Agoda', 'booking.com': 'Booking.com' };

const found = [];
for (const [folder, platform] of Object.entries(FOLDERS)) {
  const dir = path.join(SAMPLES, folder);
  if (!fs.existsSync(dir)) continue;
  for (const f of fs.readdirSync(dir).filter((f) => f.endsWith('.eml')).sort()) found.push({ platform, file: path.join(dir, f) });
}

if (!found.length) {
  test('sample emails', { skip: 'samples/ has no .eml files yet' }, () => {});
}

for (const { platform, file } of found) {
  test(`${platform}: ${path.relative(SAMPLES, file)}`, async () => {
    const m = await simpleParser(fs.readFileSync(file));
    const email = {
      id: path.basename(file), threadId: 't', from: m.from ? m.from.text : '', subject: m.subject || '',
      date: m.date || new Date(), plain: m.text || '', html: typeof m.html === 'string' ? m.html : '',
    };
    const settings = {};
    gas.DEFAULT_SETTINGS.forEach((r) => { settings[r[0]] = r[1]; });
    assert.equal(gas.detectPlatform(email.from, email.subject, gas.buildFilters(settings)), platform, 'detected platform');

    const expectedFile = file.replace(/\.eml$/, '.expected.json');
    assert.ok(fs.existsSync(expectedFile), `missing ${path.basename(expectedFile)}`);
    const expected = JSON.parse(fs.readFileSync(expectedFile, 'utf8'));
    assert.deepEqual(plain(gas.parseEmail(platform, email)), { platform, ...expected });
  });
}
