library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class TankColors {
  static const navy = Color(0xFF102A43);
  static const teal = Color(0xFF0F766E);
  static const tealDeep = Color(0xFF0D5E56);
  static const mint = Color(0xFFEDF6F5);
  static const canvas = Color(0xFFF6F8FA);
  static const paper = Color(0xFFF4EFE9);
  static const paperDeep = Color(0xFFE8E0D4);
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

ThemeData tankLoopTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: TankColors.teal,
    primary: TankColors.teal,
    onPrimary: Colors.white,
    surface: TankColors.canvas,
    onSurface: TankColors.navy,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  // Display typeface: Playfair Display for headlines only
  final displayFont = GoogleFonts.playfairDisplay(
    fontWeight: FontWeight.w700,
    color: TankColors.navy,
  );
  final displayFontMedium = GoogleFonts.playfairDisplay(
    fontWeight: FontWeight.w500,
    color: TankColors.navy,
  );
  final displayFontLight = GoogleFonts.playfairDisplay(
    fontWeight: FontWeight.w400,
    color: TankColors.navy,
  );

  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: base.textTheme
        .apply(bodyColor: TankColors.navy, displayColor: TankColors.navy)
        .copyWith(
          displayLarge: displayFontLight.copyWith(
            fontSize: 52,
            height: 1.1,
            letterSpacing: -2.0,
            fontWeight: FontWeight.w400,
          ),
          displayMedium: displayFont.copyWith(
            fontSize: 40,
            height: 1.15,
            letterSpacing: -1.6,
            fontWeight: FontWeight.w700,
          ),
          displaySmall: displayFontMedium.copyWith(
            fontSize: 32,
            height: 1.2,
            letterSpacing: -1.0,
            fontWeight: FontWeight.w600,
          ),
          headlineLarge: displayFont.copyWith(
            fontSize: 28,
            height: 1.25,
            letterSpacing: -.8,
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: displayFontMedium.copyWith(
            fontSize: 22,
            height: 1.3,
            letterSpacing: -.6,
            fontWeight: FontWeight.w600,
          ),
          headlineSmall: displayFontMedium.copyWith(
            fontSize: 18,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: displayFontMedium.copyWith(
            fontSize: 20,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            height: 1.45,
            fontWeight: FontWeight.w600,
            color: TankColors.navy,
          ),
          titleSmall: const TextStyle(
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w600,
            color: TankColors.navy,
          ),
          bodyLarge: const TextStyle(
            fontSize: 16,
            height: 1.55,
            color: TankColors.navy,
          ),
          bodyMedium: const TextStyle(
            fontSize: 15,
            height: 1.55,
            color: TankColors.navy,
          ),
          bodySmall: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: TankColors.muted,
          ),
          labelLarge: const TextStyle(
            fontSize: 15,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
          labelMedium: const TextStyle(
            fontSize: 13,
            height: 1.25,
            fontWeight: FontWeight.w600,
          ),
          labelSmall: const TextStyle(
            fontSize: 11,
            height: 1.25,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: TankColors.navy,
        side: const BorderSide(color: Color(0xFFB3C9C7)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: TankColors.teal,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
      labelStyle: const TextStyle(color: TankColors.muted),
      hintStyle: const TextStyle(color: TankColors.muted),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      selectedColor: TankColors.mint,
      labelStyle: const TextStyle(
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

/// Hero card - deepest surface, reserved for the single most important block per screen
class HeroSurface extends StatelessWidget {
  const HeroSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(28),
    this.color,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(TankSpace.radiusHero),
      boxShadow: [
        BoxShadow(
          color: TankColors.tealDeep.withValues(alpha: .18),
          offset: const Offset(0, 16),
          blurRadius: 48,
        ),
        BoxShadow(
          color: TankColors.navy.withValues(alpha: .08),
          offset: const Offset(0, 6),
          blurRadius: 20,
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(TankSpace.radiusHero),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? TankColors.tealDeep,
            borderRadius: BorderRadius.circular(TankSpace.radiusHero),
            border: Border.all(
              color: Colors.white.withValues(alpha: .18),
              width: 1,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white),
              child: child,
            ),
          ),
        ),
      ),
    ),
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

/// Dense card - flat surface for list rows
class DenseCard extends StatelessWidget {
  const DenseCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? TankColors.paper.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(TankSpace.radiusDense),
      border: Border.all(
        color: TankColors.navy.withValues(alpha: .06),
        width: 1,
      ),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

/// Paper card - warm paper surface for record/print moments
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = TankSpace.radiusStandard,
    this.elevation = TankElevation.standard,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double elevation;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: elevation > 0
          ? [
              BoxShadow(
                color: TankColors.navy.withValues(alpha: .05),
                offset: Offset(0, elevation * 2),
                blurRadius: elevation * 8,
              ),
            ]
          : null,
    ),
    child: Container(
      padding: padding,
      decoration: BoxDecoration(
        color: TankColors.paper,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevation > 0 ? null : null,
        border: Border.all(
          color: TankColors.navy.withValues(alpha: .05),
          width: 1,
        ),
      ),
      child: Material(type: MaterialType.transparency, child: child),
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

class _FrostedSkeletonState extends State<FrostedSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
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
    if (reduceMotion) return base;
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

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: TankColors.teal,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.water_drop_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'tankloop',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.7,
                  color: TankColors.navy,
                ),
              ),
              Text(
                surface,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: TankColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
      if (showSimulationBadge) ...[
        const SizedBox(width: 10),
        const SimulationBadge(),
      ],
    ],
  );
}

/// Prominent simulation badge - designed to be visible beside the brand
class SimulationBadge extends StatelessWidget {
  const SimulationBadge({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 10 : 12,
      vertical: compact ? 4 : 6,
    ),
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
        Text(
          'SIMULATED DEMO',
          style: TextStyle(
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w700,
            letterSpacing: compact ? 0.5 : 0.8,
            color: TankColors.tealDeep,
          ),
        ),
      ],
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
    this.icon = Icons.info_outline_rounded,
    this.caution = false,
    this.action,
    this.prominent = false,
    this.paperSurface = false,
  });
  final String title;
  final String message;
  final IconData icon;
  final bool caution;
  final Widget? action;
  final bool prominent;
  final bool paperSurface;

  @override
  Widget build(BuildContext context) {
    final cardChild = _buildContent();
    if (prominent) {
      return HeroSurface(padding: const EdgeInsets.all(20), child: cardChild);
    }
    if (paperSurface) {
      return PaperCard(padding: const EdgeInsets.all(20), child: cardChild);
    }
    return GlassCard(
      color: caution ? TankColors.caution.withValues(alpha: .9) : null,
      padding: const EdgeInsets.all(20),
      child: cardChild,
    );
  }

  Widget _buildContent() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: caution ? TankColors.amber : TankColors.teal, size: 22),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: prominent ? Colors.white : TankColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: TextStyle(
                color: prominent
                    ? Colors.white.withValues(alpha: .9)
                    : TankColors.muted,
                height: 1.5,
              ),
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
    padding: const EdgeInsets.only(top: 28, bottom: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: style ?? Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class FloatingNav extends StatelessWidget {
  const FloatingNav({
    super.key,
    required this.selected,
    required this.onSelected,
    this.onHeightMeasured,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  final ValueChanged<double>? onHeightMeasured;
  static const icons = [
    Icons.today_outlined,
    Icons.account_tree_outlined,
    Icons.work_outline_rounded,
    Icons.history_rounded,
    Icons.person_outline_rounded,
  ];
  static const labels = ['Today', 'Water', 'Cases', 'Activity', 'Profile'];

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _MeasuredGlassCard(
            onHeightMeasured: onHeightMeasured,
            radius: 28,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: List.generate(
                icons.length,
                (index) => Expanded(
                  child: Semantics(
                    selected: selected == index,
                    label: labels[index],
                    child: Tooltip(
                      message: labels[index],
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => onSelected(index),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 56),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 4,
                          ),
                          decoration: BoxDecoration(
                            color: selected == index
                                ? TankColors.navy
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icons[index],
                                color: selected == index
                                    ? Colors.white
                                    : TankColors.muted,
                                size: 22,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                labels[index],
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected == index
                                      ? Colors.white
                                      : TankColors.muted,
                                  fontSize: 10,
                                  fontWeight: selected == index
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _MeasuredGlassCard extends StatefulWidget {
  const _MeasuredGlassCard({
    required this.child,
    required this.radius,
    required this.padding,
    this.onHeightMeasured,
  });
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final ValueChanged<double>? onHeightMeasured;

  @override
  State<_MeasuredGlassCard> createState() => _MeasuredGlassCardState();
}

class _MeasuredGlassCardState extends State<_MeasuredGlassCard> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox != null && widget.onHeightMeasured != null) {
            widget.onHeightMeasured!(renderBox.size.height);
          }
        });
        return GlassCard(
          radius: widget.radius,
          padding: widget.padding,
          child: widget.child,
        );
      },
    );
  }
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
