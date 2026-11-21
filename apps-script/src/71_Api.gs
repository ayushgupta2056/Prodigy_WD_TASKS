/**
 * Web App entry points (Deploy > New deployment > Web app, Execute as: Me,
 * Who has access: Anyone). Every request must carry the secret API key as the
 * `key` parameter or POST body field; Apps Script cannot read custom headers.
 *
 *   GET  ?key=…&action=ping
 *   GET  ?key=…&action=snapshot
 *   POST {"key":"…","action":"apply","ops":[…]}   -> { results, snapshot }
 *   POST {"key":"…","action":"sync"}               -> checks Gmail, then snapshot
 *
 * Responses are always JSON: { ok: true, data } or { ok: false, error }.
 */

function doGet(e) {
  return handleRequest_((e && e.parameter) || {});
}

function doPost(e) {
  var body = {};
  try {
    body = JSON.parse((e && e.postData && e.postData.contents) || '{}');
  } catch (err) {
    return jsonOut_({ ok: false, error: 'Body must be JSON' });
  }
  var params = (e && e.parameter) || {};
  for (var k in params) if (!(k in body)) body[k] = params[k];
  return handleRequest_(body);
}

function handleRequest_(req) {
  try {
    if (!checkApiKey_(req.key)) return jsonOut_({ ok: false, error: 'unauthorized' });
    var action = req.action || 'snapshot';
    if (action === 'ping') return jsonOut_({ ok: true, data: { version: APP.VERSION } });

    var lock = LockService.getScriptLock();
    if (!lock.tryLock(25000)) return jsonOut_({ ok: false, error: 'busy, try again' });
    try {
      var ctx = apiCtx_();
      var store = new SheetStore(SpreadsheetApp.getActive());
      var data;
      if (action === 'snapshot') {
        data = buildSnapshot(store, ctx);
      } else if (action === 'apply') {
        var ops = typeof req.ops === 'string' ? JSON.parse(req.ops) : req.ops;
        data = { results: applyOps(store, ops, ctx), snapshot: buildSnapshot(new SheetStore(SpreadsheetApp.getActive()), ctx) };
      } else if (action === 'sync') {
        lock.releaseLock(); // processNewEmails takes the lock itself
        lock = null;
        var summary = processNewEmails();
        data = { summary: summary, snapshot: buildSnapshot(new SheetStore(SpreadsheetApp.getActive()), apiCtx_()) };
      } else {
        return jsonOut_({ ok: false, error: 'unknown action ' + action });
      }
      return jsonOut_({ ok: true, data: data });
    } finally {
      if (lock) lock.releaseLock();
    }
  } catch (err) {
    return jsonOut_({ ok: false, error: String(err && err.message || err) });
  }
}

function apiCtx_() {
  var now = new Date();
  var tz = Session.getScriptTimeZone();
  var ss = SpreadsheetApp.getActive();
  return {
    now: now,
    nowIso: Utilities.formatDate(now, tz, "yyyy-MM-dd'T'HH:mm:ssXXX"),
    todayIso: Utilities.formatDate(now, tz, 'yyyy-MM-dd'),
    sheetXlsxUrl: 'https://docs.google.com/spreadsheets/d/' + ss.getId() + '/export?format=xlsx'
  };
}

function jsonOut_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

/** The key lives in Script Properties, never in the code or the Sheet. */
function getApiKey_() {
  var props = PropertiesService.getScriptProperties();
  var key = props.getProperty('API_KEY');
  if (!key) {
    key = (Utilities.getUuid() + Utilities.getUuid()).replace(/-/g, '');
    props.setProperty('API_KEY', key);
  }
  return key;
}

function checkApiKey_(given) {
  var key = getApiKey_();
  if (typeof given !== 'string' || given.length !== key.length) return false;
  var diff = 0;
  for (var i = 0; i < key.length; i++) diff |= key.charCodeAt(i) ^ given.charCodeAt(i);
  return diff === 0;
}

/** Menu: show the details to paste into the app. */
function showConnectionDetails() {
  var url = ScriptApp.getService().getUrl() || '(not deployed yet: see SETUP.md step 7)';
  var html = HtmlService.createHtmlOutput(
    '<div style="font-family:Arial;font-size:13px">' +
    '<p><b>Web App URL</b></p><textarea style="width:100%;height:60px" readonly onclick="this.select()">' + url + '</textarea>' +
    '<p><b>API key</b> (keep it secret)</p><textarea style="width:100%;height:40px" readonly onclick="this.select()">' + getApiKey_() + '</textarea>' +
    '<p>Paste both into the app\'s Settings screen.</p></div>').setWidth(460).setHeight(280);
  SpreadsheetApp.getUi().showModalDialog(html, 'Connect the app');
}

/** Menu: make a new key (the apps will need the new one). */
function rotateApiKey() {
  PropertiesService.getScriptProperties().deleteProperty('API_KEY');
  getApiKey_();
  showConnectionDetails();
}
