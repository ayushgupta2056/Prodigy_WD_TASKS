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
