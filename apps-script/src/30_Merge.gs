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
