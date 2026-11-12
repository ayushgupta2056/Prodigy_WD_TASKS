// Loads every src/*.gs file into one sandbox, the same way Apps Script does
// (all files share one global scope), and returns that sandbox.
const fs = require('fs');
const path = require('path');
const vm = require('vm');

function loadGas(extraGlobals = {}) {
  const ctx = vm.createContext({ console, ...extraGlobals });
  const dir = path.join(__dirname, '..', 'src');
  for (const f of fs.readdirSync(dir).filter((f) => f.endsWith('.gs')).sort()) {
    vm.runInContext(fs.readFileSync(path.join(dir, f), 'utf8'), ctx, { filename: f });
  }
  return ctx;
}

// Values created inside the vm have a different Array/Object prototype, which
// trips deepStrictEqual. Round-trip through JSON for comparisons.
const plain = (v) => JSON.parse(JSON.stringify(v));

module.exports = { loadGas, plain };
