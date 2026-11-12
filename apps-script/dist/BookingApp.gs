/**
 * Booking & Profit Manager — Apps Script backend (generated file).
 * Paste this whole file into Code.gs. Do not edit here: edit apps-script/src/ and run `npm run bundle`.
 */

// ===== 00_Config.gs =====
/**
 * Booking & Profit Manager — backend configuration.
 *
 * Everything that is fixed by the app lives here. Everything YOU may want to
 * change (properties, which emails to read, search window) lives in the
 * "Settings" tab of the Google Sheet and is seeded from DEFAULT_SETTINGS below
 * the first time you run setup().
 */
var APP = {
  VERSION: '0.1.0',

  SHEETS: {
    BOOKINGS: 'Bookings',
    BLOCKS: 'Blocks',
    SETTINGS: 'Settings',
    PARSER_LOG: 'ParserLog'
  },

  LABEL_PROCESSED: 'BookingApp/Processed',
  LABEL_UNPARSED: 'BookingApp/Unparsed',

  PLATFORMS: ['Airbnb', 'MakeMyTrip', 'Goibibo', 'Agoda', 'Booking.com', 'Direct', 'Other'],
  EMAIL_PLATFORMS: ['Airbnb', 'MakeMyTrip', 'Goibibo', 'Agoda', 'Booking.com'],
  STATUSES: ['confirmed', 'cancelled', 'completed'],
  SOURCES: ['email', 'manual'],
  BLOCK_REASONS: ['personal use', 'maintenance', 'held', 'other'],
  EMAIL_TYPES: ['new', 'modification', 'cancellation'],

  /** Column order of each tab. Code reads/writes by header name, so the order
   *  only matters when the tab is first created. */
  COLUMNS: {
    Bookings: [
      'id', 'property', 'platform', 'platform_booking_id', 'guest_name', 'guests_count',
      'check_in', 'check_out', 'nights',
      'guest_total_paid', 'in_hand_amount', 'costs',
      'status', 'source', 'edited_fields',
      'email_message_id', 'created_at', 'updated_at', 'notes'
    ],
    Blocks: ['id', 'property', 'start_date', 'end_date', 'reason', 'notes', 'created_at', 'updated_at'],
    Settings: ['key', 'value', 'notes'],
    ParserLog: [
      'email_message_id', 'thread_id', 'platform', 'result', 'type',
      'platform_booking_id', 'booking_id', 'error',
      'subject', 'from', 'received_at', 'timestamp', 'resolved'
    ]
  },

  /** Columns stored as plain text so Sheets never auto-converts them. */
  TEXT_COLUMNS: {
    Bookings: ['id', 'platform_booking_id', 'check_in', 'check_out', 'email_message_id',
      'created_at', 'updated_at', 'edited_fields'],
    Blocks: ['id', 'start_date', 'end_date', 'created_at', 'updated_at'],
    Settings: ['key', 'value'],
    ParserLog: ['email_message_id', 'thread_id', 'platform_booking_id', 'booking_id',
      'received_at', 'timestamp']
  },

  /** Booking fields an email may set or change. Anything listed in a booking's
   *  edited_fields is never touched by the email parser. in_hand_amount, costs
   *  and notes are never set from email at all. */
  EMAIL_OWNED_FIELDS: ['guest_name', 'guests_count', 'check_in', 'check_out', 'guest_total_paid', 'status'],

  /** Stop processing before Apps Script's 6-minute limit. */
  MAX_RUNTIME_MS: 4.5 * 60 * 1000,

  TRIGGER_FUNCTION: 'processNewEmails',
  TRIGGER_EVERY_MINUTES: 5
};

/**
 * Defaults written into the Settings tab on first setup. Edit them in the
 * Sheet afterwards, not here.
 *
 * filter.<Platform>.senders        comma-separated sender domains/addresses
 * filter.<Platform>.subject_regex  an email must ALSO match this subject pattern
 *                                  (case-insensitive) to count as a booking email.
 *
 * NOTE: the subject patterns are deliberately broad placeholders. They will be
 * tightened once real sample emails are in samples/.
 */
var DEFAULT_SETTINGS = [
  ['currency', 'INR', 'Fixed'],
  ['properties', 'My Homestay', 'Comma-separated list of your properties'],
  ['default_property', 'My Homestay', 'Property used for emailed bookings when the email does not say which one'],
  ['search_window_days', '30', 'How many days back each 5-minute run looks in Gmail'],
  ['filter.Airbnb.senders', 'airbnb.com', ''],
  ['filter.Airbnb.subject_regex', 'reservation|booking|cancel', 'Provisional'],
  ['filter.MakeMyTrip.senders', 'makemytrip.com', ''],
  ['filter.MakeMyTrip.subject_regex', 'booking|reservation|cancel', 'Provisional'],
  ['filter.Goibibo.senders', 'goibibo.com', ''],
  ['filter.Goibibo.subject_regex', 'booking|reservation|cancel', 'Provisional'],
  ['filter.Agoda.senders', 'agoda.com', ''],
  ['filter.Agoda.subject_regex', 'booking|reservation|cancel', 'Provisional'],
  ['filter.Booking.com.senders', 'booking.com', ''],
  ['filter.Booking.com.subject_regex', 'booking|reservation|cancel', 'Provisional']
];

// ===== 01_ParseUtil.gs =====
/**
 * Format-agnostic helpers shared by every platform parser: Indian money
 * amounts, dates, HTML-to-text. They know nothing about any platform's layout.
 */

/**
 * Parse an Indian-formatted money amount.
 *   "₹12,450.00" -> 12450, "INR 1,23,456" -> 123456, "Rs. 500/-" -> 500,
 *   "₹ 1,200" -> 1200, "-₹300" -> -300. Returns null when no number is found.
 */
function parseAmount(input) {
  if (input === null || input === undefined) return null;
  if (typeof input === 'number') return isFinite(input) ? round2(input) : null;
  var s = String(input).replace(/ /g, ' ').trim();
  if (!s) return null;
  var negative = /^\s*(-|−|\()/.test(s) || /-\s*(₹|inr|rs\.?)/i.test(s);
  s = s.replace(/(₹|inr|rs\.?|\/-)/gi, ' ');
  var m = s.match(/\d[\d,]*(\.\d+)?/);
  if (!m) return null;
  var n = parseFloat(m[0].replace(/,/g, ''));
  if (!isFinite(n)) return null;
  return round2(negative ? -n : n);
}

/**
 * Find the first amount that follows a label in a block of text, e.g.
 * findAmountAfter(text, /total\s*\(INR\)/i). Returns null if absent.
 */
function findAmountAfter(text, labelRegex) {
  if (!text) return null;
  var re = new RegExp(labelRegex.source + '[^\\d₹]{0,40}((?:₹|INR|Rs\\.?)?\\s*-?\\d[\\d,]*(?:\\.\\d+)?)', labelRegex.flags.replace('g', ''));
  var m = String(text).match(re);
  return m ? parseAmount(m[1]) : null;
}

var MONTHS_ = {
  jan: 1, january: 1, feb: 2, february: 2, mar: 3, march: 3, apr: 4, april: 4,
  may: 5, jun: 6, june: 6, jul: 7, july: 7, aug: 8, august: 8,
  sep: 9, sept: 9, september: 9, oct: 10, october: 10, nov: 11, november: 11,
  dec: 12, december: 12
};

/**
 * Parse a date written in any common Indian/international style into
 * 'YYYY-MM-DD'. Numeric dates are read as DAY first (12/11/2026 = 12 Nov).
 *
 * Supported: 2026-11-12 | 12/11/2026 | 12-11-2026 | 12.11.26 | 12 Nov 2026 |
 * 12-Nov-2026 | 12th November, 2026 | Nov 12, 2026 | Thu, 12 Nov 2026 |
 * Thursday, November 12, 2026 | "Thu, Nov 12" (needs opts.refDate).
 *
 * opts.refDate ('YYYY-MM-DD' or Date): when the text has no year, pick the
 * year that puts the date nearest after (refDate - 31 days). Returns null if
 * the text is not a valid date.
 */
function parseDateFlexible(input, opts) {
  if (input === null || input === undefined || input === '') return null;
  if (Object.prototype.toString.call(input) === '[object Date]') return toIsoDate(input);
  var s = String(input).replace(/ /g, ' ').trim().toLowerCase()
    .replace(/(\d)(st|nd|rd|th)\b/g, '$1')
    .replace(/^(mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)[a-z]*,?\s+/, '');
  var m, y, mo, d;

  if ((m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/))) {
    y = +m[1]; mo = +m[2]; d = +m[3];
  } else if ((m = s.match(/^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})\b/))) {
    d = +m[1]; mo = +m[2]; y = fullYear_(+m[3]);
  } else if ((m = s.match(/^(\d{1,2})[\s\-]+([a-z]+)\.?,?[\s\-]*(\d{2,4})?\b/)) && MONTHS_[m[2]]) {
    d = +m[1]; mo = MONTHS_[m[2]]; y = m[3] ? fullYear_(+m[3]) : null;
  } else if ((m = s.match(/^([a-z]+)\.?\s+(\d{1,2}),?\s*(\d{4})?\b/)) && MONTHS_[m[1]]) {
    mo = MONTHS_[m[1]]; d = +m[2]; y = m[3] ? +m[3] : null;
  } else {
    return null;
  }

  if (y === null) {
    if (!opts || !opts.refDate) return null;
    y = inferYear_(mo, d, opts.refDate);
  }
  if (!isValidYmd_(y, mo, d)) return null;
  return ymd_(y, mo, d);
}

function fullYear_(y) { return y < 100 ? 2000 + y : y; }

function isValidYmd_(y, m, d) {
  if (!(y >= 2000 && y <= 2100 && m >= 1 && m <= 12 && d >= 1)) return false;
  return d <= new Date(Date.UTC(y, m, 0)).getUTCDate();
}

function ymd_(y, m, d) {
  return y + '-' + (m < 10 ? '0' : '') + m + '-' + (d < 10 ? '0' : '') + d;
}

function inferYear_(mo, d, refDate) {
  var ref = typeof refDate === 'string' ? isoToUtc_(refDate) : Date.UTC(refDate.getFullYear(), refDate.getMonth(), refDate.getDate());
  var floor = ref - 31 * 86400000;
  var refYear = new Date(ref).getUTCFullYear();
  for (var y = refYear - 1; y <= refYear + 1; y++) {
    if (Date.UTC(y, mo - 1, d) >= floor) return y;
  }
  return refYear + 1;
}

/** Date object -> 'YYYY-MM-DD' using its local calendar day. */
function toIsoDate(date) {
  return ymd_(date.getFullYear(), date.getMonth() + 1, date.getDate());
}

function isoToUtc_(iso) {
  var p = String(iso).split('-');
  return Date.UTC(+p[0], +p[1] - 1, +p[2]);
}

/** Convert an HTML email body to readable text, one block per line. */
function htmlToText(html) {
  if (!html) return '';
  return String(html)
    .replace(/<(script|style|head)[^>]*>[\s\S]*?<\/\1>/gi, ' ')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(p|div|tr|li|h[1-6]|table|section)>/gi, '\n')
    .replace(/<\/t[dh]>/gi, '\t')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&#8377;|&#x20b9;/gi, '₹')
    .replace(/&#(\d+);/g, function (_, n) { return String.fromCharCode(+n); })
    .replace(/[  ]+/g, ' ')
    .replace(/ *\t */g, '\t')
    .replace(/\t*\n\t*/g, '\n')
    .replace(/ *\n */g, '\n')
    .replace(/\n{2,}/g, '\n')
    .trim();
}

/** Tidy a guest name: collapse spaces, Title Case if it arrived all-caps. */
function cleanName(name) {
  if (!name) return '';
  var s = String(name).replace(/\s+/g, ' ').trim();
  if (s === s.toUpperCase()) {
    s = s.toLowerCase().replace(/\b[a-z]/g, function (c) { return c.toUpperCase(); });
  }
  return s;
}

// ===== 02_Money.gs =====
/**
 * Money maths. These are the ONLY definitions the app uses; the Flutter app
 * mirrors them exactly.
 *
 *   nights          = check_out - check_in (days)
 *   platform cut ₹  = guest_total_paid - in_hand_amount
 *   platform cut %  = cut / guest_total_paid
 *   profit          = in_hand_amount - costs
 *   in-hand / night = in_hand_amount / nights
 *
 * A booking with no in_hand_amount is "pending": cut, profit and per-night
 * stay null rather than being guessed.
 */

function round2(n) {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

/** Whole nights between two 'YYYY-MM-DD' dates; 0 if missing or reversed. */
function nightsBetween(checkIn, checkOut) {
  if (!checkIn || !checkOut) return 0;
  var a = isoToUtc_(checkIn), b = isoToUtc_(checkOut);
  if (!isFinite(a) || !isFinite(b) || b <= a) return 0;
  return Math.round((b - a) / 86400000);
}

/** Blank/empty -> null, otherwise a number (or null if not numeric). */
function toNumberOrNull(v) {
  if (v === null || v === undefined || v === '') return null;
  var n = typeof v === 'number' ? v : parseAmount(v);
  return n === null || !isFinite(n) ? null : n;
}

function bookingFinancials(b) {
  var nights = nightsBetween(b.check_in, b.check_out);
  var guestPaid = toNumberOrNull(b.guest_total_paid);
  var inHand = toNumberOrNull(b.in_hand_amount);
  var costs = toNumberOrNull(b.costs);
  if (costs === null) costs = 0;

  var pending = inHand === null;
  var cut = null, cutPct = null, profit = null, perNight = null;
  if (!pending) {
    profit = round2(inHand - costs);
    perNight = nights > 0 ? round2(inHand / nights) : null;
    if (guestPaid !== null) {
      cut = round2(guestPaid - inHand);
      cutPct = guestPaid > 0 ? round2((cut / guestPaid) * 100) : null;
    }
  }
  return {
    nights: nights,
    guest_paid: guestPaid,
    in_hand: inHand,
    costs: costs,
    platform_cut: cut,
    platform_cut_pct: cutPct,
    profit: profit,
    in_hand_per_night: perNight,
    pending_in_hand: pending
  };
}

// ===== 10_Parsers.gs =====
/**
 * Shared parser interface.
 *
 * Every platform parser is a function  parseXxxEmail(email) -> ParsedEmail
 *
 * `email` (input) is a plain object:
 *   { id, threadId, from, subject, date (Date), plain (string), html (string) }
 *
 * ParsedEmail (output):
 *   {
 *     platform:            'Airbnb' | 'MakeMyTrip' | 'Goibibo' | 'Agoda' | 'Booking.com',
 *     type:                'new' | 'modification' | 'cancellation',
 *     platform_booking_id: string,
 *     guest_name:          string | null,
 *     guests_count:        number | null,
 *     check_in:            'YYYY-MM-DD' | null,
 *     check_out:           'YYYY-MM-DD' | null,
 *     guest_total_paid:    number (₹) | null,
 *     property:            string | null   // only if the email names the listing
 *   }
 *
 * A parser throws when it cannot read the email; the email then goes to the
 * "Unparsed emails" list. It must never return guessed values.
 */

function ParserNotReadyError(platform) {
  this.name = 'ParserNotReadyError';
  this.message = platform + ' parser not built yet: waiting for sample emails in samples/' + platform.toLowerCase() + '/';
}
ParserNotReadyError.prototype = Object.create(Error.prototype);

function getParser(platform) {
  switch (platform) {
    case 'Airbnb': return parseAirbnbEmail;
    case 'MakeMyTrip': return parseMakeMyTripEmail;
    case 'Goibibo': return parseGoibiboEmail;
    case 'Agoda': return parseAgodaEmail;
    case 'Booking.com': return parseBookingComEmail;
    default: return null;
  }
}

/** Run the right parser and validate its output. Throws on any problem. */
function parseEmail(platform, email, parserOverride) {
  var parser = parserOverride || getParser(platform);
  if (!parser) throw new Error('No parser for platform ' + platform);
  var result = parser(email);
  if (!result) throw new Error('Parser returned nothing');
  result.platform = platform;
  var problems = validateParsed(result);
  if (problems.length) throw new Error('Incomplete parse: ' + problems.join('; '));
  return result;
}

/** Returns a list of problems; empty means the parse is complete. */
function validateParsed(p) {
  var problems = [];
  if (APP.EMAIL_TYPES.indexOf(p.type) < 0) problems.push('unknown type "' + p.type + '"');
  if (!p.platform_booking_id) problems.push('missing booking id');
  if (p.check_in && !/^\d{4}-\d{2}-\d{2}$/.test(p.check_in)) problems.push('bad check_in');
  if (p.check_out && !/^\d{4}-\d{2}-\d{2}$/.test(p.check_out)) problems.push('bad check_out');
  if (p.check_in && p.check_out && nightsBetween(p.check_in, p.check_out) < 1) problems.push('check_out not after check_in');
  if (p.guest_total_paid !== null && p.guest_total_paid !== undefined &&
      (typeof p.guest_total_paid !== 'number' || !isFinite(p.guest_total_paid) || p.guest_total_paid < 0)) {
    problems.push('bad guest_total_paid');
  }
  if (p.type === 'new') {
    if (!p.check_in) problems.push('missing check_in');
    if (!p.check_out) problems.push('missing check_out');
    if (!p.guest_name) problems.push('missing guest_name');
    if (p.guest_total_paid === null || p.guest_total_paid === undefined) problems.push('missing guest_total_paid');
  }
  if (p.type === 'modification' && !p.check_in && !p.check_out && p.guest_total_paid == null &&
      !p.guest_name && p.guests_count == null) {
    problems.push('modification with no changed fields');
  }
  return problems;
}

/**
 * Build per-platform email filters from the Settings tab.
 * Returns [{ platform, senders: [..], subjectRegex: RegExp }]
 */
function buildFilters(settings) {
  return APP.EMAIL_PLATFORMS.map(function (platform) {
    var senders = String(settings['filter.' + platform + '.senders'] || '')
      .split(',').map(function (s) { return s.trim().toLowerCase(); }).filter(String);
    var pattern = settings['filter.' + platform + '.subject_regex'];
    return {
      platform: platform,
      senders: senders,
      subjectRegex: pattern ? new RegExp(pattern, 'i') : null
    };
  }).filter(function (f) { return f.senders.length > 0; });
}

/** Gmail search query covering every configured sender. */
function buildGmailQuery(filters, windowDays) {
  var senders = [];
  filters.forEach(function (f) { senders = senders.concat(f.senders); });
  return 'from:(' + senders.join(' OR ') + ') newer_than:' + (windowDays || 30) + 'd';
}

/** Which platform (if any) does this email belong to? */
function detectPlatform(from, subject, filters) {
  var addr = extractAddress_(from);
  for (var i = 0; i < filters.length; i++) {
    var f = filters[i];
    var senderOk = f.senders.some(function (s) {
      return s.indexOf('@') >= 0 ? addr === s : (addr.slice(-(s.length + 1)) === '@' + s || addr.slice(-(s.length + 1)) === '.' + s);
    });
    if (senderOk && (!f.subjectRegex || f.subjectRegex.test(subject || ''))) return f.platform;
  }
  return null;
}

function extractAddress_(from) {
  var s = String(from || '').toLowerCase();
  var m = s.match(/<([^>]+)>/);
  return (m ? m[1] : s).trim();
}

// ===== 20_Parser_Agoda.gs =====
/**
 * Agoda email parser.
 *
 * NOT IMPLEMENTED YET. It will be written against real (anonymised) sample
 * emails in samples/agoda/ rather than guessed. Until then every Agoda
 * booking email is sent to "Unparsed emails" so nothing is lost.
 *
 * Contract: see 10_Parsers.gs. Return a ParsedEmail or throw.
 */
function parseAgodaEmail(email) {
  throw new ParserNotReadyError('Agoda');
}

// ===== 20_Parser_Airbnb.gs =====
/**
 * Airbnb email parser.
 *
 * NOT IMPLEMENTED YET. It will be written against real (anonymised) sample
 * emails in samples/airbnb/ rather than guessed. Until then every Airbnb
 * booking email is sent to "Unparsed emails" so nothing is lost.
 *
 * Contract: see 10_Parsers.gs. Return a ParsedEmail or throw.
 */
function parseAirbnbEmail(email) {
  throw new ParserNotReadyError('Airbnb');
}

// ===== 20_Parser_BookingCom.gs =====
/**
 * Booking.com email parser.
 *
 * NOT IMPLEMENTED YET. It will be written against real (anonymised) sample
 * emails in samples/booking.com/ rather than guessed. Until then every Booking.com
 * booking email is sent to "Unparsed emails" so nothing is lost.
 *
 * Contract: see 10_Parsers.gs. Return a ParsedEmail or throw.
 */
function parseBookingComEmail(email) {
  throw new ParserNotReadyError('Booking.com');
}

// ===== 20_Parser_Goibibo.gs =====
/**
 * Goibibo email parser.
 *
 * NOT IMPLEMENTED YET. It will be written against real (anonymised) sample
 * emails in samples/goibibo/ rather than guessed. Until then every Goibibo
 * booking email is sent to "Unparsed emails" so nothing is lost.
 *
 * Contract: see 10_Parsers.gs. Return a ParsedEmail or throw.
 */
function parseGoibiboEmail(email) {
  throw new ParserNotReadyError('Goibibo');
}

// ===== 20_Parser_MakeMyTrip.gs =====
/**
 * MakeMyTrip email parser.
 *
 * NOT IMPLEMENTED YET. It will be written against real (anonymised) sample
 * emails in samples/makemytrip/ rather than guessed. Until then every MakeMyTrip
 * booking email is sent to "Unparsed emails" so nothing is lost.
 *
 * Contract: see 10_Parsers.gs. Return a ParsedEmail or throw.
 */
function parseMakeMyTripEmail(email) {
  throw new ParserNotReadyError('MakeMyTrip');
}

// ===== 30_Merge.gs =====
/**
 * Pure booking logic: turning a parsed email into a new booking or applying it
 * to an existing one. No Sheets or Gmail calls here, so it is fully testable.
 *
 * Golden rule: a field listed in booking.edited_fields is NEVER changed by an
 * email. in_hand_amount, costs and notes are never set from email at all.
 */

/** edited_fields is stored as "a,b,c" in the Sheet. */
function parseEditedFields(value) {
  if (!value) return [];
  if (Array.isArray(value)) return value.slice();
  return String(value).split(',').map(function (s) { return s.trim(); }).filter(String);
}

function formatEditedFields(list) {
  var seen = {};
  return list.filter(function (f) { return f && !seen[f] && (seen[f] = true); }).join(',');
}

function newBookingFromParsed(parsed, email, ctx) {
  var b = {
    id: ctx.newId(),
    property: parsed.property || ctx.defaultProperty || '',
    platform: parsed.platform,
    platform_booking_id: String(parsed.platform_booking_id),
    guest_name: parsed.guest_name ? cleanName(parsed.guest_name) : '',
    guests_count: parsed.guests_count == null ? '' : parsed.guests_count,
    check_in: parsed.check_in || '',
    check_out: parsed.check_out || '',
    nights: 0,
    guest_total_paid: parsed.guest_total_paid == null ? '' : parsed.guest_total_paid,
    in_hand_amount: '',
    costs: 0,
    status: parsed.type === 'cancellation' ? 'cancelled' : 'confirmed',
    source: 'email',
    edited_fields: '',
    email_message_id: email.id,
    created_at: ctx.nowIso,
    updated_at: ctx.nowIso,
    notes: ''
  };
  b.nights = nightsBetween(b.check_in, b.check_out);
  return b;
}

/**
 * Apply a parsed email to an existing booking.
 * Returns { booking, changed: [field names], skipped: [protected field names] }.
 * The input booking is not mutated.
 */
function mergeParsedIntoBooking(existing, parsed, ctx) {
  var b = shallowCopy_(existing);
  var edited = parseEditedFields(b.edited_fields);
  var changed = [], skipped = [];

  function set(field, value) {
    if (value === null || value === undefined || value === '') return;
    if (field === 'guest_name') value = cleanName(value);
    if (String(b[field]) === String(value)) return;
    if (edited.indexOf(field) >= 0) { skipped.push(field); return; }
    b[field] = value;
    changed.push(field);
  }

  if (parsed.type === 'cancellation') {
    if (b.status !== 'cancelled') set('status', 'cancelled');
  } else {
    // 'new' (a resend of the confirmation) or 'modification'.
    set('guest_name', parsed.guest_name);
    set('guests_count', parsed.guests_count);
    set('check_in', parsed.check_in);
    set('check_out', parsed.check_out);
    set('guest_total_paid', parsed.guest_total_paid);
    if (!b.property && parsed.property) set('property', parsed.property);
  }

  if (changed.length) {
    b.nights = nightsBetween(b.check_in, b.check_out);
    b.updated_at = ctx.nowIso;
  }
  return { booking: b, changed: changed, skipped: skipped };
}

/**
 * Confirmed stays whose check-out date has passed become 'completed', unless
 * status was edited by hand. Returns the bookings that changed (copies).
 */
function bookingsToComplete(bookings, todayIso, nowIso) {
  var out = [];
  bookings.forEach(function (b) {
    if (b.status !== 'confirmed' || !b.check_out) return;
    if (parseEditedFields(b.edited_fields).indexOf('status') >= 0) return;
    if (String(b.check_out) <= todayIso) {
      var c = shallowCopy_(b);
      c.status = 'completed';
      c.updated_at = nowIso;
      out.push(c);
    }
  });
  return out;
}

function shallowCopy_(o) {
  var c = {};
  for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) c[k] = o[k];
  return c;
}

// ===== 40_Processor.gs =====
/**
 * The email pipeline. runProcessor() is written against two small interfaces
 * so it can be tested without Google:
 *
 *   store:  getSettings(), listBookings(), insertBooking(b), updateBooking(b),
 *           processedMessageIds() -> object set, appendLog(entry)
 *   source: search(query) -> [email], label(email, labelName)
 *           where email = { id, threadId, from, subject, date, plain(), html() }
 *
 * Note on de-duplication: Gmail labels belong to whole threads, and platforms
 * often send the booking and its cancellation in the same thread. So the
 * search does NOT skip labelled threads; each message is processed once,
 * tracked by its Gmail message id in ParserLog. A booking is matched by
 * platform + platform booking id.
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
    var seen = store.processedMessageIds();
    var emails = source.search(buildGmailQuery(filters, windowDays))
      .filter(function (e) { return !seen[e.id]; })
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
        received_at: email.date ? email.date.toISOString() : '', timestamp: ctx.nowIso, resolved: ''
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
        store.appendLog(log);
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
      store.appendLog(log);
      source.label(email, APP.LABEL_PROCESSED);
      summary.processed++;
    }
  }

  var toComplete = bookingsToComplete(store.listBookings(), ctx.todayIso, ctx.nowIso);
  toComplete.forEach(function (b) { store.updateBooking(b); });
  summary.completed = toComplete.length;
  return summary;
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

// ===== 50_Store.gs =====
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

SheetStore.prototype.processedMessageIds = function () {
  var set = {};
  this.table(APP.SHEETS.PARSER_LOG).readAll().forEach(function (r) {
    if (r.email_message_id) set[r.email_message_id] = true;
  });
  return set;
};

SheetStore.prototype.appendLog = function (entry) { return this.table(APP.SHEETS.PARSER_LOG).append(entry); };

// ===== 60_Setup.gs =====
/**
 * One-time setup and the "Booking App" menu in the Sheet.
 */

function onOpen() {
  SpreadsheetApp.getUi().createMenu('Booking App')
    .addItem('1. Run setup', 'setup')
    .addItem('Process new emails now', 'processNewEmailsFromMenu')
    .addItem('Import last 12 months of emails', 'backfillLastYear')
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
