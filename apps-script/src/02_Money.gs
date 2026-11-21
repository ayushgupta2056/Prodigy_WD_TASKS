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
