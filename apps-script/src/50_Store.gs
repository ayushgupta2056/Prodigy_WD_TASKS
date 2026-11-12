/**
 * Google Sheet storage. Columns are found by header name, so you can reorder
 * or add your own columns in the Sheet without breaking anything.
 */

function Table(sheet) {
  this.sheet = sheet;
  var lastCol = Math.max(sheet.getLastColumn(), 1);
  this.headers = sheet.getRange(1, 1, 1, lastCol).getValues()[0].map(String);
}

Table.prototype.readAll = function () {
  var last = this.sheet.getLastRow();
  if (last < 2) return [];
  var headers = this.headers;
  var values = this.sheet.getRange(2, 1, last - 1, headers.length).getValues();
  var out = [];
  values.forEach(function (row, i) {
    if (row.every(function (v) { return v === '' || v === null; })) return;
    var o = { _row: i + 2 };
    headers.forEach(function (h, c) { if (h) o[h] = normaliseCell_(row[c]); });
    out.push(o);
  });
  return out;
};

Table.prototype.toRow_ = function (obj, existingRow) {
  return this.headers.map(function (h, c) {
    if (!h) return existingRow ? existingRow[c] : '';
    if (Object.prototype.hasOwnProperty.call(obj, h)) return obj[h] === null || obj[h] === undefined ? '' : obj[h];
    return existingRow ? existingRow[c] : '';
  });
};

Table.prototype.append = function (obj) {
  this.sheet.appendRow(this.toRow_(obj));
  obj._row = this.sheet.getLastRow();
  return obj;
};

Table.prototype.update = function (obj) {
  if (!obj._row) throw new Error('update() needs _row');
  var range = this.sheet.getRange(obj._row, 1, 1, this.headers.length);
  range.setValues([this.toRow_(obj, range.getValues()[0])]);
  return obj;
};

/** Dates typed by hand into the Sheet come back as Date objects: keep them as YYYY-MM-DD. */
function normaliseCell_(v) {
  if (Object.prototype.toString.call(v) === '[object Date]') {
    return Utilities.formatDate(v, Session.getScriptTimeZone(), 'yyyy-MM-dd');
  }
  return v;
}

function SheetStore(ss) {
  this.ss = ss;
  this.tables_ = {};
}

SheetStore.prototype.table = function (name) {
  if (!this.tables_[name]) {
    var sheet = this.ss.getSheetByName(name);
    if (!sheet) throw new Error('Missing tab "' + name + '". Run setup first.');
    this.tables_[name] = new Table(sheet);
  }
  return this.tables_[name];
};

SheetStore.prototype.getSettings = function () {
  var out = {};
  this.table(APP.SHEETS.SETTINGS).readAll().forEach(function (r) {
    if (r.key) out[String(r.key).trim()] = String(r.value === undefined ? '' : r.value).trim();
  });
  return out;
};

SheetStore.prototype.listBookings = function () { return this.table(APP.SHEETS.BOOKINGS).readAll(); };
SheetStore.prototype.insertBooking = function (b) { return this.table(APP.SHEETS.BOOKINGS).append(b); };
SheetStore.prototype.updateBooking = function (b) { return this.table(APP.SHEETS.BOOKINGS).update(b); };

SheetStore.prototype.listLogs = function () { return this.table(APP.SHEETS.PARSER_LOG).readAll(); };
SheetStore.prototype.appendLog = function (entry) { return this.table(APP.SHEETS.PARSER_LOG).append(entry); };
SheetStore.prototype.updateLog = function (entry) { return this.table(APP.SHEETS.PARSER_LOG).update(entry); };

SheetStore.prototype.listBlocks = function () { return this.table(APP.SHEETS.BLOCKS).readAll(); };
SheetStore.prototype.insertBlock = function (b) { return this.table(APP.SHEETS.BLOCKS).append(b); };
SheetStore.prototype.updateBlock = function (b) { return this.table(APP.SHEETS.BLOCKS).update(b); };

/** Delete rows by sheet row number (highest first so numbers stay valid). */
SheetStore.prototype.deleteBookingRow = function (row) { this.table(APP.SHEETS.BOOKINGS).sheet.deleteRow(row); };
SheetStore.prototype.deleteBlockRow = function (row) { this.table(APP.SHEETS.BLOCKS).sheet.deleteRow(row); };

SheetStore.prototype.setSetting = function (key, value) {
  var t = this.table(APP.SHEETS.SETTINGS);
  var row = t.readAll().filter(function (r) { return r.key === key; })[0];
  if (row) { row.value = value; t.update(row); } else t.append({ key: key, value: value, notes: '' });
};
