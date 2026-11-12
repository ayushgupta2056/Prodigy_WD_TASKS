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
