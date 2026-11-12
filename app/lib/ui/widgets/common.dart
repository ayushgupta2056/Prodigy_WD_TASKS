import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../theme/icons.dart';

import '../../core/format.dart';
import '../../theme/app_theme.dart';

/// Soft rounded card with a hairline border and (light mode) a whisper of shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(Space.xl), this.onTap, this.color, this.borderColor});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(Radii.card);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: color ?? c.surface,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: borderColor ?? c.hairline)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Space.xxl, bottom: Space.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.h2(context)),
              if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: AppText.label(context))),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

/// A number that counts up smoothly when it first appears or changes.
class CountUp extends StatelessWidget {
  final double value;
  final String Function(double) format;
  final TextStyle style;
  final Duration duration;
  const CountUp({super.key, required this.value, required this.format, required this.style, this.duration = const Duration(milliseconds: 900)});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text(format(v), style: style, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
      );
}

/// ▲ 12% / ▼ 8% in green / red. [goodWhenUp] flips the colours (e.g. costs).
class DeltaChip extends StatelessWidget {
  final double? change;
  final bool goodWhenUp;
  final String? suffix;
  const DeltaChip(this.change, {super.key, this.goodWhenUp = true, this.suffix});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (change == null) return const SizedBox.shrink();
    final up = change! >= 0;
    final good = up == goodWhenUp;
    final color = change!.abs() < 0.5 ? c.muted : (good ? c.positive : c.negative);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(up ? '▲' : '▼', style: TextStyle(fontSize: 9, color: color)),
      const SizedBox(width: 3),
      Text('${change!.abs().toStringAsFixed(change!.abs() < 10 ? 1 : 0)}%', style: AppText.num(context, size: 12).copyWith(color: color, fontWeight: FontWeight.w600)),
      if (suffix != null) Text(' $suffix', style: AppText.label(context).copyWith(fontSize: 11.5)),
    ]);
  }
}

/// Label + big number (+ optional comparison).
class StatTile extends StatelessWidget {
  final String label;
  final double? value;
  final String Function(double) format;
  final double? change;
  final double? changeLastYear;
  final bool goodWhenUp;
  final String? footnote;
  final double size;
  final IconData? icon;
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.format = _inr,
    this.change,
    this.changeLastYear,
    this.goodWhenUp = true,
    this.footnote,
    this.size = 24,
    this.icon,
  });

  static String _inr(double v) => inr(v);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          if (icon != null) ...[Icon(icon, size: 15, color: context.colors.muted), const SizedBox(width: 6)],
          Expanded(child: Text(label, style: AppText.label(context), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: Space.sm),
        value == null
            ? Text('—', style: AppText.money(context, size: size).copyWith(color: context.colors.muted))
            : FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: CountUp(value: value!, format: format, style: AppText.money(context, size: size))),
        const SizedBox(height: Space.xs),
        Wrap(spacing: 10, runSpacing: 2, children: [
          if (change != null) DeltaChip(change, goodWhenUp: goodWhenUp, suffix: 'vs prev'),
          if (changeLastYear != null) DeltaChip(changeLastYear, goodWhenUp: goodWhenUp, suffix: 'vs last yr'),
          if (footnote != null) Text(footnote!, style: AppText.label(context).copyWith(fontSize: 11.5)),
        ]),
      ]),
    );
  }
}

class PlatformDot extends StatelessWidget {
  final String platform;
  final double size;
  const PlatformDot(this.platform, {super.key, this.size = 8});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: PlatformColors.of(context, platform), shape: BoxShape.circle),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? background;
  final IconData? icon;
  const Pill(this.text, {super.key, this.color, this.background, this.icon});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = color ?? c.inkSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: background ?? c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.chip)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
        Text(text, style: AppText.label(context).copyWith(color: fg, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return switch (status) {
      'cancelled' => Pill('Cancelled', color: c.negative, background: c.negative.withValues(alpha: 0.1)),
      'completed' => Pill('Completed', color: c.muted),
      _ => Pill('Confirmed', color: c.accent, background: c.accentSoft),
    };
  }
}

/// Small marker shown next to a value the host changed by hand.
class EditedBadge extends StatelessWidget {
  const EditedBadge({super.key});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Edited by you: emails will not overwrite this',
        child: Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(border: Border.all(color: context.colors.warning.withValues(alpha: 0.6)), borderRadius: BorderRadius.circular(6)),
          child: Text('edited', style: AppText.label(context).copyWith(fontSize: 10, color: context.colors.warning, fontWeight: FontWeight.w600)),
        ),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xxxl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 34, color: c.accent),
          ),
          const SizedBox(height: Space.xl),
          Text(title, style: AppText.title(context), textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: Space.sm),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: Text(message!, style: AppText.body(context).copyWith(color: c.muted), textAlign: TextAlign.center)),
          ],
          if (action != null) ...[const SizedBox(height: Space.xl), action!],
        ]),
      ),
    );
  }
}

/// Shimmering placeholder block.
class Skeleton extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 10});
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.colors.surfaceAlt;
    final hi = Color.lerp(base, context.colors.surface, 0.7)!;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1.5 + 3 * _c.value, 0),
            end: Alignment(-0.5 + 3 * _c.value, 0),
            colors: [base, hi, base],
          ),
        ),
      ),
    );
  }
}

/// Fades and slides a child in, with an optional stagger [index].
class EaseIn extends StatelessWidget {
  final Widget child;
  final int index;
  const EaseIn({super.key, required this.child, this.index = 0});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 420 + 60 * index.clamp(0, 8)),
        curve: Curves.easeOutCubic,
        builder: (_, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child)),
        child: child,
      );
}

/// ₹-prefixed amount input with the numeric keyboard.
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final bool large;
  final Widget? suffix;
  const AmountField({super.key, required this.controller, required this.label, this.hint, this.autofocus = false, this.onChanged, this.large = false, this.suffix});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        style: large ? AppText.money(context, size: 26) : AppText.num(context, size: 16).copyWith(color: context.colors.ink),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffix,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 6),
            child: Text('₹', style: (large ? AppText.money(context, size: 24) : AppText.num(context, size: 16)).copyWith(color: context.colors.muted)),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        ),
      );
}

/// Bottom sheet on phones, centred dialog on wide screens.
Future<T?> showAdaptiveSheet<T>(BuildContext context, {required WidgetBuilder builder, double maxWidth = 560}) {
  if (MediaQuery.sizeOf(context).width >= 700) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(Space.xxl),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: MediaQuery.sizeOf(ctx).height * 0.88),
          child: Padding(padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xxl, Space.xxl, Space.lg), child: builder(ctx)),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, MediaQuery.viewInsetsOf(ctx).bottom + Space.lg),
      child: builder(ctx),
    ),
  );
}

/// Gentle haptic tap (Android) after saving.
void savedFeedback(BuildContext context, String message) {
  HapticFeedback.lightImpact();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Row(children: [
      Icon(LucideIcons300.circleCheck, color: context.colors.background, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(message)),
    ]), duration: const Duration(seconds: 2)));
}

void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: context.colors.danger));
}

/// Page scaffold body with consistent max width and gutters.
class PageBody extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final double maxWidth;
  final EdgeInsets padding;
  const PageBody({super.key, required this.children, this.onRefresh, this.maxWidth = 1180, this.padding = const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 96)});

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: padding,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, color: context.colors.accent, backgroundColor: context.colors.surface, child: list);
  }
}

/// Two-up / four-up responsive grid of equal tiles.
class TileGrid extends StatelessWidget {
  final List<Widget> children;
  final int phoneColumns;
  final int wideColumns;
  final double spacing;
  const TileGrid({super.key, required this.children, this.phoneColumns = 2, this.wideColumns = 4, this.spacing = Space.md});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth >= 860 ? wideColumns : (box.maxWidth >= 560 ? (wideColumns + phoneColumns) ~/ 2 : phoneColumns);
        final w = (box.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(spacing: spacing, runSpacing: spacing, children: [for (final c in children) SizedBox(width: w, child: c)]);
      });
}

String greeting(DateTime now) => now.hour < 12 ? 'Good morning' : (now.hour < 17 ? 'Good afternoon' : 'Good evening');

/// Compact rounded filter control (used in toolbars and filter rows).
class FilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Widget? leading;
  final bool active;
  final VoidCallback? onTap;
  const FilterPill({super.key, required this.label, this.icon, this.leading, this.active = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? c.accentSoft : c.surface,
        borderRadius: BorderRadius.circular(Radii.chip),
        border: Border.all(color: active ? c.accent.withValues(alpha: 0.35) : c.hairline),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (leading != null) ...[leading!, const SizedBox(width: 7)],
        if (icon != null) ...[Icon(icon, size: 15, color: active ? c.accent : c.inkSoft), const SizedBox(width: 6)],
        Text(label, style: AppText.label(context).copyWith(fontSize: 13, color: active ? c.accent : c.inkSoft, fontWeight: FontWeight.w600)),
      ]),
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}
