/**
 * The email pipeline. runProcessor() is written against two small interfaces
 * so it can be tested without Google:
 *
 *   store:  getSettings(), listBookings(), insertBooking(b), updateBooking(b),
 *           listLogs(), appendLog(entry), updateLog(entry)
 *   source: search(query) -> [email], label(email, labelName)
 *           where email = { id, threadId, from, subject, date, plain(), html() }
 *
 * Note on de-duplication: Gmail labels belong to whole threads, and platforms
 * often send the booking and its cancellation in the same thread. So the
 * search does NOT skip labelled threads; each message is processed once,
 * tracked by its Gmail message id in ParserLog. A booking is matched by
 * platform + platform booking id.
 *
 * Retry: an email that failed to parse is tried again (once) whenever
 * APP.PARSER_VERSION is bumped, i.e. after a parser is improved.
 */

/** Entry point for the 5-minute trigger. */
function processNewEmails() {
  return processEmailsWithWindow_(null);
}

/** Menu action: look much further back once, e.g. after first setup. */
function backfillLastYear() {
  var r = processEmailsWithWindow_(365);
  SpreadsheetApp.getActive().toast(
    'Processed ' + r.processed + ', unparsed ' + r.failed + (r.timedOut ? ' (stopped early, run again)' : ''),
    'Booking App', 10);
}

function processEmailsWithWindow_(windowDays) {
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(10000)) return { skipped: 'another run in progress' };
  try {
    var now = new Date();
    var tz = Session.getScriptTimeZone();
    return runProcessor(new SheetStore(SpreadsheetApp.getActive()), new GmailSource(), {
      now: now,
      nowIso: Utilities.formatDate(now, tz, "yyyy-MM-dd'T'HH:mm:ssXXX"),
      todayIso: Utilities.formatDate(now, tz, 'yyyy-MM-dd'),
      newId: function () { return Utilities.getUuid(); },
      windowDays: windowDays,
      deadline: now.getTime() + APP.MAX_RUNTIME_MS
    });
  } finally {
    lock.releaseLock();
  }
}

/**
 * ctx: { nowIso, todayIso, newId(), windowDays?, deadline?, clock?(), parserOverride? }
 * Returns a summary { processed, failed, created, updated, unchanged, completed, timedOut }.
 */
function runProcessor(store, source, ctx) {
  var settings = store.getSettings();
  var filters = buildFilters(settings);
  var summary = { processed: 0, failed: 0, created: 0, updated: 0, unchanged: 0, completed: 0, timedOut: false };
  var clock = ctx.clock || function () { return new Date().getTime(); };

  if (filters.length) {
    var windowDays = ctx.windowDays || parseInt(settings.search_window_days, 10) || 30;
    var logIndex = {};
    store.listLogs().forEach(function (l) { if (l.email_message_id) logIndex[l.email_message_id] = l; });
    var emails = source.search(buildGmailQuery(filters, windowDays))
      .filter(function (e) { return !isDone_(logIndex[e.id]); })
      .sort(function (a, b) { return a.date - b.date; }); // booking before its cancellation

    var bookings = store.listBookings();
    var index = {};
    bookings.forEach(function (b) { index[b.platform + '|' + b.platform_booking_id] = b; });

    for (var i = 0; i < emails.length; i++) {
      if (ctx.deadline && clock() > ctx.deadline) { summary.timedOut = true; break; }
      var email = emails[i];
      var platform = detectPlatform(email.from, email.subject, filters);
      if (!platform) continue; // e.g. marketing mail from the same sender: ignore silently

      var log = {
        email_message_id: email.id, thread_id: email.threadId, platform: platform,
        result: '', type: '', platform_booking_id: '', booking_id: '', error: '',
        subject: email.subject || '', from: email.from || '',
        received_at: email.date ? email.date.toISOString() : '', timestamp: ctx.nowIso, resolved: '',
        parser_version: APP.PARSER_VERSION
      };
      var previous = logIndex[email.id];
      var writeLog = function (entry) {
        if (previous) { entry._row = previous._row; store.updateLog(entry); } else store.appendLog(entry);
      };

      var parsed;
      try {
        parsed = parseEmail(platform, {
          id: email.id, threadId: email.threadId, from: email.from, subject: email.subject,
          date: email.date, plain: email.plain(), html: email.html()
        }, ctx.parserOverride);
      } catch (err) {
        log.result = 'failed';
        log.error = String(err && err.message || err);
        writeLog(log);
        source.label(email, APP.LABEL_UNPARSED);
        summary.failed++;
        continue;
      }

      log.type = parsed.type;
      log.platform_booking_id = String(parsed.platform_booking_id);
      var key = platform + '|' + parsed.platform_booking_id;
      var existing = index[key];

      if (!existing) {
        if (parsed.type === 'cancellation' && !(parsed.check_in && parsed.check_out)) {
          log.result = 'ok';
          log.error = 'Cancellation for a booking not in the Sheet (no dates in email); nothing to update';
        } else {
          var created = newBookingFromParsed(parsed, email, {
            newId: ctx.newId, nowIso: ctx.nowIso, defaultProperty: settings.default_property
          });
          store.insertBooking(created);
          index[key] = created;
          log.result = 'ok';
          log.booking_id = created.id;
          summary.created++;
        }
      } else {
        var m = mergeParsedIntoBooking(existing, parsed, { nowIso: ctx.nowIso });
        log.result = 'ok';
        log.booking_id = existing.id;
        if (m.skipped.length) log.error = 'Kept your edits to: ' + m.skipped.join(', ');
        if (m.changed.length) {
          m.booking._row = existing._row;
          store.updateBooking(m.booking);
          index[key] = m.booking;
          summary.updated++;
        } else {
          summary.unchanged++;
        }
      }
      writeLog(log);
      source.label(email, APP.LABEL_PROCESSED);
      summary.processed++;
    }
  }

  var toComplete = bookingsToComplete(store.listBookings(), ctx.todayIso, ctx.nowIso);
  toComplete.forEach(function (b) { store.updateBooking(b); });
  summary.completed = toComplete.length;
  return summary;
}

function isDone_(log) {
  if (!log) return false;
  if (log.result === 'ok' || log.resolved) return true;
  return String(log.parser_version) === String(APP.PARSER_VERSION);
}

/** Gmail implementation of the `source` interface. */
function GmailSource() {
  this.labels_ = {};
}

GmailSource.prototype.search = function (query) {
  var out = [], start = 0, page;
  do {
    page = GmailApp.search(query, start, 100);
    page.forEach(function (thread) {
      thread.getMessages().forEach(function (msg) {
        out.push({
          id: msg.getId(),
          threadId: thread.getId(),
          from: msg.getFrom(),
          subject: msg.getSubject(),
          date: msg.getDate(),
          plain: function () { return msg.getPlainBody(); },
          html: function () { return msg.getBody(); },
          _thread: thread
        });
      });
    });
    start += page.length;
  } while (page.length === 100 && start < 1000);
  return out;
};

GmailSource.prototype.label = function (email, name) {
  if (!this.labels_[name]) this.labels_[name] = GmailApp.getUserLabelByName(name) || GmailApp.createLabel(name);
  email._thread.addLabel(this.labels_[name]);
};
