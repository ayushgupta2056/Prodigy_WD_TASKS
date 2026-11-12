// Concatenates src/*.gs into dist/BookingApp.gs: the single file you paste
// into the Apps Script editor. Run: npm run bundle
const fs = require('fs');
const path = require('path');

function bundle() {
  const dir = path.join(__dirname, '..', 'src');
  const files = fs.readdirSync(dir).filter((f) => f.endsWith('.gs')).sort();
  const header =
    '/**\n * Booking & Profit Manager — Apps Script backend (generated file).\n' +
    ' * Paste this whole file into Code.gs. Do not edit here: edit apps-script/src/ and run `npm run bundle`.\n */\n';
  return header + files.map((f) => `\n// ===== ${f} =====\n` + fs.readFileSync(path.join(dir, f), 'utf8')).join('');
}

module.exports = { bundle };

if (require.main === module) {
  const out = path.join(__dirname, '..', 'dist', 'BookingApp.gs');
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, bundle());
  console.log('Wrote ' + out);
}
