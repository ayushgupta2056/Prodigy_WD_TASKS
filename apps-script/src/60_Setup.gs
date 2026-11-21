/**
 * One-time setup and the "Booking App" menu in the Sheet.
 */

function onOpen() {
  SpreadsheetApp.getUi().createMenu('Booking App')
    .addItem('1. Run setup', 'setup')
    .addItem('Process new emails now', 'processNewEmailsFromMenu')
    .addItem('Import last 12 months of emails', 'backfillLastYear')
    .addSeparator()
    .addItem('Show Web App URL and API key', 'showConnectionDetails')
    .addItem('Make a new API key', 'rotateApiKey')
    .addSeparator()
    .addItem('Turn automatic checking on (every 5 min)', 'installTrigger')
    .addItem('Turn automatic checking off', 'removeTrigger')
    .addToUi();
}

/**
 * Safe to run more than once: it only adds what is missing and never deletes
 * your data.
 */
function setup() {
  var ss = SpreadsheetApp.getActive();
  ss.setSpreadsheetTimeZone(Session.getScriptTimeZone());

  [APP.SHEETS.BOOKINGS, APP.SHEETS.BLOCKS, APP.SHEETS.SETTINGS, APP.SHEETS.PARSER_LOG].forEach(function (name) {
    ensureSheet_(ss, name, APP.COLUMNS[name], APP.TEXT_COLUMNS[name] || []);
  });
  seedSettings_(ss.getSheetByName(APP.SHEETS.SETTINGS));
  var first = ss.getSheetByName('Sheet1');
  if (first && first.getLastRow() === 0 && ss.getSheets().length > 1) ss.deleteSheet(first);

  [APP.LABEL_PROCESSED, APP.LABEL_UNPARSED].forEach(function (name) {
    if (!GmailApp.getUserLabelByName(name)) GmailApp.createLabel(name);
  });

  getApiKey_();
  installTrigger();
  ss.toast('Setup complete. Gmail is now checked every 5 minutes.', 'Booking App', 10);
}

function ensureSheet_(ss, name, columns, textColumns) {
  var sheet = ss.getSheetByName(name) || ss.insertSheet(name);
  var lastCol = sheet.getLastColumn();
  var headers = lastCol ? sheet.getRange(1, 1, 1, lastCol).getValues()[0].map(String) : [];
  columns.forEach(function (col) {
    if (headers.indexOf(col) < 0) {
      headers.push(col);
      sheet.getRange(1, headers.length).setValue(col);
    }
  });
  sheet.setFrozenRows(1);
  sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold').setBackground('#f3efe7');
  textColumns.forEach(function (col) {
    var c = headers.indexOf(col) + 1;
    if (c > 0 && sheet.getMaxRows() > 1) sheet.getRange(2, c, sheet.getMaxRows() - 1, 1).setNumberFormat('@');
  });
  return sheet;
}

function seedSettings_(sheet) {
  var existing = {};
  var last = sheet.getLastRow();
  if (last >= 2) {
    sheet.getRange(2, 1, last - 1, 1).getValues().forEach(function (r) { existing[String(r[0]).trim()] = true; });
  }
  DEFAULT_SETTINGS.forEach(function (row) {
    if (!existing[row[0]]) sheet.appendRow(row);
  });
  sheet.autoResizeColumns(1, 3);
}

function processNewEmailsFromMenu() {
  var r = processNewEmails();
  SpreadsheetApp.getActive().toast(
    r.skipped ? 'Another run is in progress, try again in a minute.' :
      'Processed ' + r.processed + ', unparsed ' + r.failed + ', new ' + r.created + ', updated ' + r.updated,
    'Booking App', 10);
}

function installTrigger() {
  removeTrigger();
  ScriptApp.newTrigger(APP.TRIGGER_FUNCTION).timeBased().everyMinutes(APP.TRIGGER_EVERY_MINUTES).create();
}

function removeTrigger() {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === APP.TRIGGER_FUNCTION) ScriptApp.deleteTrigger(t);
  });
}
