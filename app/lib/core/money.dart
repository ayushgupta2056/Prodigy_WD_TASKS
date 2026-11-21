import 'models.dart';

/// The app's money definitions, identical to apps-script/src/02_Money.gs:
///
///   platform cut ₹  = guest paid − in-hand
///   platform cut %  = cut ÷ guest paid
///   profit          = in-hand − costs
///   in-hand / night = in-hand ÷ nights
///
/// Nothing is estimated: with no in-hand amount, cut/profit/per-night are null.
class Financials {
  final int nights;
  final double? guestPaid;
  final double? inHand;
  final double costs;
  final double? cut;
  final double? cutPct;
  final double? profit;
  final double? perNight;

  const Financials({
    required this.nights,
    this.guestPaid,
    this.inHand,
    this.costs = 0,
    this.cut,
    this.cutPct,
    this.profit,
    this.perNight,
  });

  bool get pending => inHand == null;

  factory Financials.of({required int nights, double? guestPaid, double? inHand, double costs = 0}) {
    if (inHand == null) {
      return Financials(nights: nights, guestPaid: guestPaid, costs: costs);
    }
    final cut = guestPaid == null ? null : round2(guestPaid - inHand);
    return Financials(
      nights: nights,
      guestPaid: guestPaid,
      inHand: inHand,
      costs: costs,
      cut: cut,
      cutPct: (cut != null && guestPaid != null && guestPaid > 0) ? round2(cut / guestPaid * 100) : null,
      profit: round2(inHand - costs),
      perNight: nights > 0 ? round2(inHand / nights) : null,
    );
  }

  factory Financials.ofBooking(Booking b) =>
      Financials.of(nights: b.nights, guestPaid: b.guestTotalPaid, inHand: b.inHandAmount, costs: b.costs);
}

double round2(double v) => (v * 100).roundToDouble() / 100;
