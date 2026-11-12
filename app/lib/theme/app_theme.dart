import 'dart:ui' show FontFeature;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

/// The design system: colours, type scale, spacing and radii.
/// Every screen uses these tokens; nothing is styled ad hoc.

class Space {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 20.0, xxl = 24.0, xxxl = 32.0;
  static const gutter = 20.0;
}

class Radii {
  static const card = 18.0, sheet = 26.0, field = 14.0, chip = 999.0, bar = 9.0;
}

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color inkSoft;
  final Color muted;
  final Color hairline;
  final Color accent;
  final Color accentSoft;
  final Color onAccent;
  final Color positive;
  final Color negative;
  final Color warning;
  final Color danger;
  final Color dangerSoft;
  final Color shadow;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.hairline,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.danger,
    required this.dangerSoft,
    required this.shadow,
  });

  /// Warm off-white with a deep emerald accent.
  static const light = AppColors(
    background: Color(0xFFF7F4EE),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0EBE1),
    ink: Color(0xFF1C1B18),
    inkSoft: Color(0xFF45423C),
    muted: Color(0xFF8A8377),
    hairline: Color(0xFFE7E1D6),
    accent: Color(0xFF1F4D3F),
    accentSoft: Color(0xFFE2EDE7),
    onAccent: Color(0xFFFFFFFF),
    positive: Color(0xFF2F7D52),
    negative: Color(0xFFB9533B),
    warning: Color(0xFFB0832F),
    danger: Color(0xFFC0392B),
    dangerSoft: Color(0xFFF8E3DF),
    shadow: Color(0x14201A10),
  );

  /// True near-black, not grey.
  static const dark = AppColors(
    background: Color(0xFF0A0A09),
    surface: Color(0xFF141412),
    surfaceAlt: Color(0xFF1C1C19),
    ink: Color(0xFFF2EFE8),
    inkSoft: Color(0xFFCFCAC0),
    muted: Color(0xFF8F897E),
    hairline: Color(0xFF26251F),
    accent: Color(0xFF6FBF9F),
    accentSoft: Color(0xFF16261F),
    onAccent: Color(0xFF07130E),
    positive: Color(0xFF6CC28E),
    negative: Color(0xFFE38A72),
    warning: Color(0xFFD9AE5C),
    danger: Color(0xFFE5675A),
    dangerSoft: Color(0xFF331713),
    shadow: Color(0x00000000),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      ink: l(ink, other.ink),
      inkSoft: l(inkSoft, other.inkSoft),
      muted: l(muted, other.muted),
      hairline: l(hairline, other.hairline),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      onAccent: l(onAccent, other.onAccent),
      positive: l(positive, other.positive),
      negative: l(negative, other.negative),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      shadow: l(shadow, other.shadow),
    );
  }
}

/// Muted, harmonious platform colours (not the brands' loud colours).
class PlatformColors {
  static const _light = {
    'Airbnb': Color(0xFFC77D74),
    'MakeMyTrip': Color(0xFF5E7FAF),
    'Goibibo': Color(0xFFCB9357),
    'Agoda': Color(0xFF8C70A6),
    'Booking.com': Color(0xFF4A8A88),
    'Direct': Color(0xFF7C9463),
    'Other': Color(0xFF9A9388),
  };
  static const _dark = {
    'Airbnb': Color(0xFFD9958C),
    'MakeMyTrip': Color(0xFF86A2CC),
    'Goibibo': Color(0xFFDDAA72),
    'Agoda': Color(0xFFAE93C6),
    'Booking.com': Color(0xFF6FB1AE),
    'Direct': Color(0xFF9DB584),
    'Other': Color(0xFFA7A196),
  };
  static Color of(BuildContext context, String platform) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return (dark ? _dark : _light)[platform] ?? (dark ? _dark : _light)['Other']!;
  }
}

/// Type scale. Money uses tabular figures so columns line up.
class AppText {
  static const _tab = [FontFeature.tabularFigures()];
  static TextStyle _base(Color c) => GoogleFonts.plusJakartaSans(color: c);

  static TextStyle hero(BuildContext c) => _base(c.colors.ink).copyWith(fontSize: 40, fontWeight: FontWeight.w600, letterSpacing: -1.2, height: 1.05, fontFeatures: _tab);
  static TextStyle display(BuildContext c) => _base(c.colors.ink).copyWith(fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: -0.8, height: 1.1, fontFeatures: _tab);
  static TextStyle h1(BuildContext c) => _base(c.colors.ink).copyWith(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.6, height: 1.15);
  static TextStyle h2(BuildContext c) => _base(c.colors.ink).copyWith(fontSize: 19, fontWeight: FontWeight.w600, letterSpacing: -0.3);
  static TextStyle title(BuildContext c) => _base(c.colors.ink).copyWith(fontSize: 15.5, fontWeight: FontWeight.w600, letterSpacing: -0.1);
  static TextStyle body(BuildContext c) => _base(c.colors.inkSoft).copyWith(fontSize: 14.5, height: 1.45);
  static TextStyle label(BuildContext c) => _base(c.colors.muted).copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, letterSpacing: 0.1);
  static TextStyle overline(BuildContext c) => _base(c.colors.muted).copyWith(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.1);
  static TextStyle money(BuildContext c, {double size = 22}) => _base(c.colors.ink).copyWith(fontSize: size, fontWeight: FontWeight.w600, letterSpacing: -0.4, fontFeatures: _tab);
  static TextStyle num(BuildContext c, {double size = 14}) => _base(c.colors.inkSoft).copyWith(fontSize: size, fontWeight: FontWeight.w500, fontFeatures: _tab);
}

extension AppThemeX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  bool get isWide => MediaQuery.sizeOf(this).width >= 900;
  bool get isPhone => MediaQuery.sizeOf(this).width < 640;
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: c.accent,
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    surface: c.surface,
    onSurface: c.ink,
    error: c.danger,
  );
  final text = GoogleFonts.plusJakartaSansTextTheme(ThemeData(brightness: brightness).textTheme).apply(bodyColor: c.ink, displayColor: c.ink);
  final fieldBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.field), borderSide: BorderSide(color: c.hairline));

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    canvasColor: c.background,
    textTheme: text,
    extensions: [c],
    splashFactory: kIsWeb ? InkRipple.splashFactory : InkSparkle.splashFactory,
    dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: c.ink,
      centerTitle: false,
      titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w600, color: c.ink, letterSpacing: -0.3),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card), side: BorderSide(color: c.hairline)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.field)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        minimumSize: const Size(64, 52),
        side: BorderSide(color: c.hairline),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.field)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.accent,
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.field)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceAlt.withValues(alpha: brightness == Brightness.dark ? 0.6 : 0.55),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: fieldBorder,
      enabledBorder: fieldBorder.copyWith(borderSide: BorderSide(color: Colors.transparent)),
      focusedBorder: fieldBorder.copyWith(borderSide: BorderSide(color: c.accent, width: 1.4)),
      labelStyle: GoogleFonts.plusJakartaSans(color: c.muted, fontSize: 14),
      floatingLabelStyle: GoogleFonts.plusJakartaSans(color: c.accent, fontSize: 13, fontWeight: FontWeight.w600),
      hintStyle: GoogleFonts.plusJakartaSans(color: c.muted.withValues(alpha: 0.7)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface,
      selectedColor: c.accentSoft,
      side: BorderSide(color: c.hairline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.chip)),
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500, color: c.inkSoft),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      showCheckmark: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.accentSoft,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => GoogleFonts.plusJakartaSans(
          fontSize: 11.5, fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500, color: s.contains(WidgetState.selected) ? c.ink : c.muted)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(size: 23, color: s.contains(WidgetState.selected) ? c.accent : c.muted)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.accentSoft,
      selectedIconTheme: IconThemeData(color: c.accent, size: 22),
      unselectedIconTheme: IconThemeData(color: c.muted, size: 22),
      selectedLabelTextStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: c.ink),
      unselectedLabelTextStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, color: c.muted),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.hairline,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sheet)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      contentTextStyle: GoogleFonts.plusJakartaSans(color: c.background, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.field)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: c.surface,
        selectedBackgroundColor: c.accentSoft,
        selectedForegroundColor: c.accent,
        foregroundColor: c.inkSoft,
        side: BorderSide(color: c.hairline),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
    }),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(8)),
      textStyle: GoogleFonts.plusJakartaSans(color: c.background, fontSize: 12),
    ),
  );
}
