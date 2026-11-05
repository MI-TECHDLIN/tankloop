library;

import 'dart:ui';
import 'package:flutter/material.dart';

abstract final class TankColors {
  static const navy = Color(0xFF102A43);
  static const teal = Color(0xFF0F766E);
  static const mint = Color(0xFFEDF6F5);
  static const canvas = Color(0xFFF6F8FA);
  static const caution = Color(0xFFFFF0DF);
  static const muted = Color(0xFF526777);
  static const amber = Color(0xFF88501C);
}

abstract final class TankSpace {
  static const unit = 4.0;
  static const screen = 16.0;
  static const card = 24.0;
  static const radius = 28.0;
  static const target = 48.0;
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
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: base.textTheme
        .apply(bodyColor: TankColors.navy, displayColor: TankColors.navy)
        .copyWith(
          displaySmall: const TextStyle(
            fontSize: 44,
            height: 1.12,
            letterSpacing: -1.8,
            fontWeight: FontWeight.w800,
            color: TankColors.navy,
          ),
          headlineLarge: const TextStyle(
            fontSize: 36,
            height: 1.16,
            letterSpacing: -1.2,
            fontWeight: FontWeight.w800,
            color: TankColors.navy,
          ),
          headlineMedium: const TextStyle(
            fontSize: 28,
            height: 1.2,
            letterSpacing: -.7,
            fontWeight: FontWeight.w700,
            color: TankColors.navy,
          ),
          titleLarge: const TextStyle(
            fontSize: 22,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: TankColors.navy,
          ),
          bodyLarge: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: TankColors.navy,
          ),
          bodyMedium: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: TankColors.navy,
          ),
          labelLarge: const TextStyle(
            fontSize: 15,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: TankColors.navy,
        side: const BorderSide(color: Color(0xFFB3C9C7)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: TankColors.teal,
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
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          Color(0xFFF4EFE9),
        ],
        stops: [0, .35, .78, 1],
      ),
    ),
    child: child,
  );
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color,
    this.radius = 28,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: TankColors.navy.withValues(alpha: .04),
          offset: const Offset(0, 8),
          blurRadius: 32,
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: .9),
              width: 1.25,
            ),
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
  const TankBrand({super.key, this.surface = 'FIELD'});
  final String surface;
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
              const Text(
                'tankloop',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7,
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
    ],
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    this.icon = Icons.info_outline_rounded,
    this.caution = false,
    this.compact = false,
  });
  final String label;
  final IconData icon;
  final bool caution;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: 8),
    decoration: BoxDecoration(
      color: caution ? TankColors.caution : TankColors.mint,
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

class SimulationNotice extends StatelessWidget {
  const SimulationNotice({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Simulated demonstration. No real water tests.',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: TankColors.navy.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              compact
                  ? 'SIMULATED DATA · No real water tests'
                  : 'SIMULATED DEMONSTRATION\nGenerated records, not real water tests.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: caution ? TankColors.amber : TankColors.teal),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(message, style: const TextStyle(color: TankColors.muted)),
              if (action != null)
                Padding(padding: const EdgeInsets.only(top: 8), child: action!),
            ],
          ),
        ),
      ],
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?trailing,
      ],
    ),
  );
}

class FloatingNav extends StatelessWidget {
  const FloatingNav({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;
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
          child: GlassCard(
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

/// Original vector artwork, drawn from product topology rather than stock or
/// third-party inspiration assets. It stays static when reduce motion is on.
class WaterNetworkArtwork extends StatelessWidget {
  const WaterNetworkArtwork({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'A borehole connected to an overhead storage tank and tap',
    image: true,
    child: const AspectRatio(
      aspectRatio: 1.5,
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
