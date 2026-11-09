library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

export 'src/artwork.dart';
export 'src/cards.dart';
export 'src/glyphs.dart';
export 'src/licenses.dart';

abstract final class TankColors {
  static const navy = Color(0xFF102A43);
  static const teal = Color(0xFF0F766E);
  static const tealDeep = Color(0xFF0D5E56);
  static const mint = Color(0xFFEDF6F5);
  static const canvas = Color(0xFFF6F8FA);
  static const paper = Color(0xFFF4EFE9);
  static const paperDeep = Color(0xFFE8E0D4);
  static const record = Color(0xFFFFFCF7);
  static const line = Color(0xFFDCE6E5);
  static const caution = Color(0xFFFFF0DF);
  static const muted = Color(0xFF526777);
  static const amber = Color(0xFF88501C);
  static const white = Colors.white;
  static const black = Colors.black;
}

abstract final class TankSpace {
  static const unit = 4.0;
  static const screen = 16.0;
  static const card = 24.0;
  static const radiusHero = 28.0;
  static const radiusStandard = 20.0;
  static const radiusDense = 12.0;
  static const target = 48.0;
  static const navHeight = 72.0;
}

abstract final class TankElevation {
  static const hero = 8.0;
  static const standard = 2.0;
  static const dense = 0.0;
}

/// Type families. Plus Jakarta Sans carries every interface style; Playfair
/// Display is reserved for the `tankloop` wordmark. Package fonts need the
/// package prefix even inside this package, or Flutter silently falls back.
abstract final class TankType {
  static const package = 'tankloop_design_system';
  static const sans = 'packages/$package/PlusJakartaSans';
  static const wordmark = 'PlayfairDisplay';
}

ThemeData tankLoopTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: TankColors.teal,
    primary: TankColors.teal,
    onPrimary: Colors.white,
    surface: TankColors.canvas,
    onSurface: TankColors.navy,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: TankType.sans,
  );

  // Deliberate scale: 26sp page headings, 18-20sp card titles, 15-16sp body
  // and 12-13sp metadata. Body text uses medium weight for outdoor legibility.
  const navy = TankColors.navy;
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    iconTheme: const IconThemeData(
      color: navy,
      size: 24,
      weight: 500,
      opticalSize: 24,
    ),
    textTheme: base.textTheme
        .apply(bodyColor: navy, displayColor: navy)
        .copyWith(
          displayLarge: const TextStyle(
            fontFamily: TankType.sans,
            fontSize: 40,
            height: 1.1,
            letterSpacing: -1.2,
            fontWeight: FontWeight.w800,
            color: navy,
          ),
          displayMedium: const TextStyle(
            fontFamily: TankType.sans,
            fontSize: 32,
            height: 1.12,
            letterSpacing: -.9,
            fontWeight: FontWeight.w800,
            color: navy,
          ),
          displaySmall: const TextStyle(
            fontFamily: TankType.sans,
            fontSize: 28,
            height: 1.15,
            letterSpacing: -.6,
            fontWeight: FontWeight.w800,
            color: navy,
          ),
          headlineLarge: const TextStyle(
            fontFamily: TankType.sans,
            fontSize: 26,
            height: 1.2,
            letterSpacing: -.5,
            fontWeight: FontWeight.w800,
            color: navy,
          ),
          headlineMedium: const TextStyle(
            fontFamily: TankType.sans,
            fontSize: 22,
            height: 1.25,
            letterSpacing: -.3,
            fontWeight: FontWeight.w700,
            color: navy,
          ),
          headlineSmall: const TextStyle(
            fontFamily: TankType.sans,
            fontSize: 20,
            height: 1.3,
            letterSpacing: -.2,
            fontWeight: FontWeight.w700,
            color: navy,
          ),
          titleLarge: const TextStyle(
            fontFamily: TankType.sans,
            fontSize: 18,
            height: 1.3,
            letterSpacing: -.1,
            fontWeight: FontWeight.w700,
            color: navy,
          ),
          titleMedium: const TextStyle(
            fontFamily: TankType.sans,
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w700,
            color: navy,
          ),
          titleSmall: const TextStyle(
            fontFamily: TankType.sans,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w700,
            color: navy,
          ),
          bodyLarge: const TextStyle(
            fontFamily: TankType.sans,
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: navy,
          ),
          bodyMedium: const TextStyle(
            fontFamily: TankType.sans,
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: navy,
          ),
          bodySmall: const TextStyle(
            fontFamily: TankType.sans,
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w500,
            color: TankColors.muted,
          ),
          labelLarge: const TextStyle(
            fontFamily: TankType.sans,
            fontSize: 15,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
          labelMedium: const TextStyle(
            fontFamily: TankType.sans,
            fontSize: 13,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          labelSmall: const TextStyle(
            fontFamily: TankType.sans,
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w700,
            letterSpacing: .3,
          ),
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: TankType.sans,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: TankColors.navy,
        side: const BorderSide(color: Color(0xFFB3C9C7)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: TankType.sans,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: TankColors.teal,
        textStyle: const TextStyle(
          fontFamily: TankType.sans,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: .72),
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFC2D8D5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFC2D8D5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: TankColors.teal, width: 2),
      ),
      labelStyle: const TextStyle(
        fontFamily: TankType.sans,
        color: TankColors.muted,
      ),
      hintStyle: const TextStyle(
        fontFamily: TankType.sans,
        color: TankColors.muted,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      selectedColor: TankColors.mint,
      labelStyle: const TextStyle(
        fontFamily: TankType.sans,
        color: TankColors.navy,
        fontWeight: FontWeight.w600,
      ),
    ),
    dividerColor: const Color(0xFFD6E3E3),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: TankColors.teal,
    ),
  );
}

class TankBackdrop extends StatelessWidget {
  const TankBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFDDF3EF),
          Color(0xFFEDF3F8),
          TankColors.canvas,
          TankColors.paper,
        ],
        stops: [0, .35, .78, 1],
      ),
    ),
    child: child,
  );
}

/// Standard content card - frosted glass
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color,
    this.radius = TankSpace.radiusStandard,
    this.elevation = TankElevation.standard,
    this.border = true,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final double elevation;
  final bool border;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: elevation > 0
          ? [
              BoxShadow(
                color: TankColors.navy.withValues(alpha: .05),
                offset: Offset(0, elevation * 2.5),
                blurRadius: elevation * 10,
              ),
            ]
          : null,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withValues(alpha: .78),
            borderRadius: BorderRadius.circular(radius),
            border: border
                ? Border.all(
                    color: Colors.white.withValues(alpha: .95),
                    width: 1.25,
                  )
                : null,
          ),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    ),
  );
}

class FrostedSkeleton extends StatefulWidget {
  const FrostedSkeleton({
    super.key,
    this.height = 16,
    this.width,
    this.radius = 10,
  });
  final double height;
  final double? width;
  final double radius;

  @override
  State<FrostedSkeleton> createState() => _FrostedSkeletonState();
}

bool debugDisableSkeletonAnimations = false;

class _FrostedSkeletonState extends State<FrostedSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion || debugDisableSkeletonAnimations) {
      controller.stop();
    } else {
      controller.repeat();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final base = Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: TankColors.navy.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );
    if (reduceMotion || debugDisableSkeletonAnimations) return base;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(-1.5 + controller.value * 3, 0),
          end: Alignment(-.5 + controller.value * 3, 0),
          colors: [
            TankColors.navy.withValues(alpha: .06),
            Colors.white.withValues(alpha: .55),
            TankColors.navy.withValues(alpha: .06),
          ],
        ).createShader(bounds),
        child: child,
      ),
      child: base,
    );
  }
}

class FrostedSkeletonCard extends StatelessWidget {
  const FrostedSkeletonCard({super.key, this.lines = 2, this.showIcon = true});
  final int lines;
  final bool showIcon;

  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showIcon) ...[
          const FrostedSkeleton(height: 32, width: 32, radius: 12),
          const SizedBox(height: 16),
        ],
        const FrostedSkeleton(height: 18, width: 180),
        for (var index = 0; index < lines; index++) ...[
          const SizedBox(height: 12),
          FrostedSkeleton(height: 14, width: index.isEven ? 240 : 160),
        ],
      ],
    ),
  );
}

class TankBrand extends StatelessWidget {
  const TankBrand({
    super.key,
    this.surface = 'FIELD',
    this.showSimulationBadge = false,
  });
  final String surface;
  final bool showSimulationBadge;

  // The wordmark is a logo: it grows a little with the reader's text size but
  // never so far that the name itself truncates.
  @override
  Widget build(BuildContext context) =>
      MediaQuery.withClampedTextScaling(maxScaleFactor: 1.25, child: _build());

  Widget _build() => LayoutBuilder(
    builder: (context, constraints) {
      const iconWidth = 40.0;
      const iconGap = 12.0;
      const inlineBadgeGap = 8.0;
      const stackedBadgeGap = 4.0;
      const compactBadgeWidth = 120.0;

      final hasBadge = showSimulationBadge;
      final inlineReserved =
          iconWidth +
          iconGap +
          (hasBadge ? inlineBadgeGap + compactBadgeWidth : 0);
      final inlineAvailable = constraints.maxWidth - inlineReserved;
      final canFitInline = inlineAvailable >= 80;

      final showFullBrand = constraints.maxWidth > 200;
      final fontSize = showFullBrand ? 22.0 : 16.0;

      final brandColumn = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'tankloop',
            style: TextStyle(
              fontFamily: TankType.wordmark,
              package: TankType.package,
              fontSize: fontSize + 2,
              fontWeight: FontWeight.w700,
              fontVariations: const [FontVariation.weight(700)],
              letterSpacing: -.4,
              height: 1.1,
              color: TankColors.navy,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          if (showFullBrand)
            Text(
              surface,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: TankColors.muted,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
        ],
      );

      if (!hasBadge) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _icon(),
            const SizedBox(width: iconGap),
            Flexible(child: brandColumn),
          ],
        );
      }

      if (canFitInline) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _icon(),
            const SizedBox(width: iconGap),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: inlineAvailable),
                child: brandColumn,
              ),
            ),
            const SizedBox(width: inlineBadgeGap),
            const SimulationBadge(compact: true),
          ],
        );
      }

      // Stack badge below when space is tight
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _icon(),
              const SizedBox(width: iconGap),
              Flexible(child: brandColumn),
            ],
          ),
          const SizedBox(height: stackedBadgeGap),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: const SimulationBadge(compact: true),
          ),
        ],
      );
    },
  );
}

Widget _icon() => Container(
  width: 40,
  height: 40,
  decoration: BoxDecoration(
    color: TankColors.teal,
    borderRadius: BorderRadius.circular(14),
  ),
  child: const Icon(
    Symbols.water_drop_rounded,
    fill: 1,
    color: Colors.white,
    size: 24,
  ),
);

/// Prominent simulation badge - designed to be visible beside the brand
class SimulationBadge extends StatelessWidget {
  const SimulationBadge({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 4 : 6,
      ),
      constraints: compact
          ? BoxConstraints(maxWidth: constraints.maxWidth)
          : null,
      decoration: BoxDecoration(
        color: TankColors.tealDeep.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        border: Border.all(
          color: TankColors.teal.withValues(alpha: .35),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.science_outlined,
            size: compact ? 12 : 14,
            color: TankColors.teal,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'SIMULATED DEMO',
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: compact ? 0.5 : 0.8,
                  color: TankColors.tealDeep,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Inline simulation notice for screen content
class SimulationNotice extends StatelessWidget {
  const SimulationNotice({
    super.key,
    this.compact = false,
    this.prominent = false,
  });
  final bool compact;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Simulated demonstration. No real water tests.',
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: prominent
            ? TankColors.tealDeep.withValues(alpha: .12)
            : TankColors.navy.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        border: prominent
            ? Border.all(color: TankColors.teal.withValues(alpha: .3), width: 1)
            : null,
      ),
      child: Row(
        children: [
          Icon(
            Icons.science_outlined,
            size: compact ? 18 : 20,
            color: prominent ? TankColors.teal : TankColors.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              compact
                  ? 'SIMULATED DATA · No real water tests'
                  : 'SIMULATED DEMONSTRATION\nGenerated records, not real water tests.',
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: prominent ? TankColors.tealDeep : TankColors.navy,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    this.icon = Icons.info_outline_rounded,
    this.caution = false,
    this.compact = false,
    this.color,
  });
  final String label;
  final IconData icon;
  final bool caution;
  final bool compact;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: 8),
    decoration: BoxDecoration(
      color: color ?? (caution ? TankColors.caution : TankColors.mint),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: caution ? TankColors.amber : TankColors.teal,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w600,
              color: caution ? TankColors.amber : TankColors.navy,
            ),
          ),
        ),
      ],
    ),
  );
}

class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Symbols.info_rounded,
    this.caution = false,
    this.action,
  });
  final String title;
  final String message;
  final IconData icon;
  final bool caution;
  final Widget? action;

  @override
  Widget build(BuildContext context) => GlassCard(
    color: caution ? TankColors.caution.withValues(alpha: .9) : null,
    padding: const EdgeInsets.all(20),
    child: _buildContent(),
  );

  Widget _buildContent() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: caution ? TankColors.amber : TankColors.teal, size: 22),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                height: 1.35,
                color: caution ? const Color(0xFF5C3311) : TankColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(color: TankColors.muted, height: 1.5),
            ),
            if (action != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: action!),
          ],
        ),
      ),
    ],
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.trailing, this.style});
  final String title;
  final Widget? trailing;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: style ?? Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        if (trailing != null) ...[trailing!],
      ],
    ),
  );
}

/// The approved floating navigation: five labelled destinations with a navy
/// pill on the current one. When the reader's text size leaves too little room
/// for every label, the bar keeps the current label visible inside the pill
/// and shows the others as icons with tooltips and spoken labels, instead of
/// truncating every word.
class FloatingNav extends StatelessWidget {
  const FloatingNav({
    super.key,
    required this.selected,
    required this.onSelected,
    this.onHeightMeasured,
  });
  final int selected;
  final ValueChanged<int> onSelected;

  /// The bar's full height, including its bottom safe-area inset.
  final ValueChanged<double>? onHeightMeasured;
  static const icons = [
    Symbols.today_rounded,
    Symbols.water_drop_rounded,
    Symbols.assignment_late_rounded,
    Symbols.history_rounded,
    Symbols.person_rounded,
  ];
  static const labels = ['Today', 'Water', 'Cases', 'Activity', 'Profile'];
  static const _label = TextStyle(
    fontFamily: TankType.sans,
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: .1,
  );
  static const _iconSlot = 50.0;

  /// Whether every label fits its share of [width] at the current text scale.
  static bool labelsFit(double width, TextScaler scaler) {
    final slot = width / labels.length;
    return labels.every((label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: _label),
        textScaler: scaler,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      return painter.width + 12 <= slot;
    });
  }

  @override
  Widget build(BuildContext context) => _Measured(
    onHeightMeasured: onHeightMeasured,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _NavSurface(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scaler = MediaQuery.textScalerOf(context);
                  final full = labelsFit(constraints.maxWidth, scaler);
                  return Row(
                    children: [
                      for (var index = 0; index < icons.length; index++)
                        full || index == selected
                            ? Expanded(child: _item(context, index, full))
                            : SizedBox(
                                width: _iconSlot,
                                child: _item(context, index, full),
                              ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _item(BuildContext context, int index, bool full) {
    final active = selected == index;
    final color = active ? Colors.white : TankColors.muted;
    final icon = Icon(
      icons[index],
      color: color,
      size: 24,
      fill: active ? 1 : 0,
      weight: active ? 600 : 500,
    );
    final label = Text(
      labels[index],
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.center,
      style: _label.copyWith(
        color: color,
        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
      ),
    );
    final Widget content;
    if (full) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [icon, const SizedBox(height: 3), label],
      );
    } else if (active) {
      // Keep the whole word: drop the icon first, and only scale the word
      // down when even the label alone cannot fit the remaining width.
      content = LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: labels[index], style: _label),
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          final withIcon = painter.width + 24 + 6 <= constraints.maxWidth;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (withIcon) ...[icon, const SizedBox(width: 6)],
              Flexible(
                child: FittedBox(fit: BoxFit.scaleDown, child: label),
              ),
            ],
          );
        },
      );
    } else {
      content = icon;
    }
    // Children are excluded so the label is announced once; the tap action
    // must therefore be restated here for screen readers.
    return Semantics(
      button: true,
      selected: active,
      label: labels[index],
      onTap: () => onSelected(index),
      excludeSemantics: true,
      child: Tooltip(
        message: labels[index],
        excludeFromSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: () => onSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 56),
            padding: EdgeInsets.symmetric(
              vertical: full ? 8 : 10,
              horizontal: full ? 2 : 8,
            ),
            decoration: BoxDecoration(
              color: active ? TankColors.navy : Colors.transparent,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(heightFactor: 1, child: content),
          ),
        ),
      ),
    );
  }
}

/// Reports its child's laid-out height after every layout, so a text-size or
/// safe-area change resizes the content inset beneath the bar.
class _Measured extends StatefulWidget {
  const _Measured({required this.child, this.onHeightMeasured});
  final Widget child;
  final ValueChanged<double>? onHeightMeasured;

  @override
  State<_Measured> createState() => _MeasuredState();
}

class _MeasuredState extends State<_Measured> {
  double? _reported;

  void _report() {
    final renderBox = context.findRenderObject() as RenderBox?;
    final height = renderBox?.hasSize == true ? renderBox!.size.height : null;
    if (height == null || height == _reported) return;
    _reported = height;
    widget.onHeightMeasured?.call(height);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _report();
    });
    return widget.child;
  }
}

class _NavSurface extends StatelessWidget {
  const _NavSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(
          color: TankColors.navy.withValues(alpha: .14),
          offset: const Offset(0, 12),
          blurRadius: 32,
        ),
      ],
    ),
    child: GlassCard(
      radius: 30,
      padding: const EdgeInsets.all(5),
      elevation: 0,
      color: Colors.white.withValues(alpha: .95),
      child: child,
    ),
  );
}

/// Original vector artwork, drawn from product topology rather than stock or
/// third-party inspiration assets. It stays static when reduce motion is on.
class WaterNetworkArtwork extends StatelessWidget {
  const WaterNetworkArtwork({super.key, this.size = 220});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'A borehole connected to an overhead storage tank and tap',
    image: true,
    child: SizedBox(
      width: size * 1.5,
      height: size,
      child: CustomPaint(painter: _WaterPainter()),
    ),
  );
}

class _WaterPainter extends CustomPainter {
  const _WaterPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300, size.height / 200);
    final pale = Paint()..color = const Color(0xFFD3ECE8);
    canvas.drawOval(
      const Rect.fromLTWH(28, 152, 254, 30),
      Paint()..color = TankColors.navy.withValues(alpha: .06),
    );
    canvas.drawCircle(const Offset(158, 90), 82, pale);
    final leg = Paint()
      ..color = const Color(0xFF7FA9A6)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(128, 108), const Offset(116, 165), leg);
    canvas.drawLine(const Offset(198, 108), const Offset(208, 165), leg);
    canvas.drawLine(
      const Offset(124, 143),
      const Offset(201, 143),
      leg..strokeWidth = 4,
    );
    final tank = RRect.fromRectAndRadius(
      const Rect.fromLTWH(105, 44, 116, 82),
      const Radius.circular(22),
    );
    canvas.drawRRect(
      tank,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF83C6BB), Color(0xFF358D84)],
        ).createShader(tank.outerRect),
    );
    canvas.drawOval(
      const Rect.fromLTWH(105, 34, 116, 28),
      Paint()..color = const Color(0xFFBCE1D9),
    );
    canvas.drawOval(
      const Rect.fromLTWH(127, 33, 70, 12),
      Paint()..color = const Color(0xFF73AFA5),
    );
    final stripe = Paint()
      ..color = Colors.white.withValues(alpha: .35)
      ..strokeWidth = 3;
    canvas.drawLine(const Offset(116, 78), const Offset(210, 78), stripe);
    canvas.drawLine(const Offset(116, 94), const Offset(210, 94), stripe);
    final pipe = Path()
      ..moveTo(64, 150)
      ..lineTo(64, 86)
      ..quadraticBezierTo(64, 72, 80, 72)
      ..lineTo(102, 72);
    canvas.drawPath(
      pipe,
      Paint()
        ..color = TankColors.teal
        ..strokeWidth = 9
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(42, 132, 42, 33),
        const Radius.circular(9),
      ),
      Paint()..color = const Color(0xFFBDD2E0),
    );
    canvas.drawCircle(
      const Offset(62, 146),
      7,
      Paint()..color = const Color(0xFF6B91A7),
    );
    final tap = Path()
      ..moveTo(222, 103)
      ..lineTo(250, 103)
      ..quadraticBezierTo(260, 103, 260, 114)
      ..lineTo(260, 127);
    canvas.drawPath(
      tap,
      Paint()
        ..color = TankColors.teal
        ..strokeWidth = 9
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      const Offset(260, 147),
      6,
      Paint()..color = const Color(0xFF83C6BB),
    );
    canvas.drawCircle(
      const Offset(56, 46),
      14,
      Paint()..color = Colors.white.withValues(alpha: .65),
    );
    canvas.drawCircle(
      const Offset(264, 64),
      7,
      Paint()..color = const Color(0xFFB8D5E9),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
