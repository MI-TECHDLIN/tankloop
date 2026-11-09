import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tankloop_domain/domain.dart';
import '../design_system.dart';

/// Original TankLoop pictograms for the water assets people maintain. They are
/// drawn on a 24-unit grid with the same stroke weight as the Lucide metadata
/// glyphs and a translucent fill like the Phosphor accents. None of them shows
/// a water level, so decoration can never be mistaken for telemetry.
class AssetPictogram extends StatelessWidget {
  const AssetPictogram(this.type, {super.key, this.size = 24, this.color});
  final AssetType type;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _PictogramPainter(
        type,
        color ?? IconTheme.of(context).color ?? TankColors.teal,
      ),
    ),
  );
}

class _PictogramPainter extends CustomPainter {
  const _PictogramPainter(this.type, this.color);
  final AssetType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color.withValues(alpha: .22);
    switch (type) {
      case AssetType.tank:
        final body = RRect.fromLTRBR(5, 4, 19, 14, const Radius.circular(3.5));
        canvas.drawRRect(body, fill);
        canvas.drawRRect(body, stroke);
        canvas.drawLine(
          const Offset(5.5, 7.5),
          const Offset(18.5, 7.5),
          stroke,
        );
        canvas.drawLine(const Offset(8, 14), const Offset(6.5, 21), stroke);
        canvas.drawLine(const Offset(16, 14), const Offset(17.5, 21), stroke);
        canvas.drawLine(
          const Offset(7.4, 17.5),
          const Offset(16.6, 17.5),
          stroke,
        );
      case AssetType.borehole:
        final head = RRect.fromLTRBR(
          8.5,
          5,
          15.5,
          11,
          const Radius.circular(1.8),
        );
        canvas.drawRRect(head, fill);
        canvas.drawRRect(head, stroke);
        canvas.drawLine(const Offset(3, 13), const Offset(21, 13), stroke);
        canvas.drawLine(const Offset(10.5, 11), const Offset(10.5, 21), stroke);
        canvas.drawLine(const Offset(13.5, 11), const Offset(13.5, 21), stroke);
        canvas.drawLine(const Offset(15.5, 8), const Offset(19, 8), stroke);
        canvas.drawLine(const Offset(19, 8), const Offset(19, 10), stroke);
        canvas.drawLine(const Offset(5, 16), const Offset(7, 16), stroke);
        canvas.drawLine(const Offset(17, 18), const Offset(19, 18), stroke);
      case AssetType.pump:
        canvas.drawCircle(const Offset(10, 13), 5.5, fill);
        canvas.drawCircle(const Offset(10, 13), 5.5, stroke);
        canvas.drawCircle(const Offset(10, 13), 1.6, stroke);
        canvas.drawLine(const Offset(2.5, 13), const Offset(4.5, 13), stroke);
        final outlet = Path()
          ..moveTo(13.9, 9.1)
          ..lineTo(13.9, 5)
          ..lineTo(21, 5);
        canvas.drawPath(outlet, stroke);
        canvas.drawLine(const Offset(5, 21), const Offset(15, 21), stroke);
        canvas.drawLine(const Offset(10, 18.5), const Offset(10, 21), stroke);
      case AssetType.line:
        final pipe = Path()
          ..moveTo(3, 8)
          ..lineTo(12, 8)
          ..quadraticBezierTo(15, 8, 15, 11)
          ..lineTo(15, 13)
          ..quadraticBezierTo(15, 16, 18, 16)
          ..lineTo(21, 16);
        canvas.drawPath(
          pipe,
          Paint()
            ..color = color.withValues(alpha: .22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawPath(pipe, stroke);
        canvas.drawLine(const Offset(7, 5.5), const Offset(7, 10.5), stroke);
        canvas.drawLine(const Offset(12.5, 13), const Offset(17.5, 13), stroke);
      case AssetType.tap:
        final body = RRect.fromLTRBR(3, 8, 15, 12.5, const Radius.circular(2));
        canvas.drawRRect(body, fill);
        canvas.drawRRect(body, stroke);
        final spout = Path()
          ..moveTo(15, 10.2)
          ..lineTo(17, 10.2)
          ..quadraticBezierTo(19, 10.2, 19, 12.2)
          ..lineTo(19, 14);
        canvas.drawPath(spout, stroke);
        canvas.drawLine(const Offset(9, 8), const Offset(9, 4.5), stroke);
        canvas.drawLine(
          const Offset(6.5, 4.5),
          const Offset(11.5, 4.5),
          stroke,
        );
        final drop = Path()
          ..moveTo(19, 16.2)
          ..cubicTo(19, 16.2, 17.2, 18.4, 17.2, 19.6)
          ..arcToPoint(
            const Offset(20.8, 19.6),
            radius: const Radius.circular(1.8),
            clockwise: false,
          )
          ..cubicTo(20.8, 18.4, 19, 16.2, 19, 16.2)
          ..close();
        canvas.drawPath(drop, fill);
        canvas.drawPath(drop, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PictogramPainter old) =>
      old.type != type || old.color != color;
}

/// Plain names for asset types, written for people outside the water team.
String assetTypeName(AssetType type) => switch (type) {
  AssetType.borehole => 'Borehole',
  AssetType.pump => 'Pump',
  AssetType.tank => 'Storage tank',
  AssetType.line => 'Pipe line',
  AssetType.tap => 'Tap',
};

/// Tile colors per asset type. Foregrounds keep at least 4.5:1 contrast on
/// their tile so the pictogram stays legible outdoors.
(Color, Color) assetTint(AssetType type) => switch (type) {
  AssetType.tank => (const Color(0xFFDDF1EC), TankColors.tealDeep),
  AssetType.borehole => (const Color(0xFFF8EAD8), const Color(0xFF7A4B17)),
  AssetType.pump => (const Color(0xFFE2EBF8), const Color(0xFF2B5687)),
  AssetType.line => (const Color(0xFFEAE6F6), const Color(0xFF4F427F)),
  AssetType.tap => (const Color(0xFFDBEFF4), const Color(0xFF14637A)),
};

/// A rounded tile holding an [AssetPictogram], used as a card's identity mark.
class AssetBadge extends StatelessWidget {
  const AssetBadge(this.type, {super.key, this.size = 48});
  final AssetType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = assetTint(type);
    return Semantics(
      label: assetTypeName(type),
      image: true,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size * .3),
          border: Border.all(color: foreground.withValues(alpha: .12)),
        ),
        alignment: Alignment.center,
        child: AssetPictogram(type, size: size * .58, color: foreground),
      ),
    );
  }
}

/// Original layered-record illustration: translucent sheets stacked behind a
/// paper record, after the layered color composition approved in review. The
/// front sheet shows only the asset mark and the caller's [caption], so it
/// never invents a reading or a result.
class LayeredRecordArt extends StatelessWidget {
  const LayeredRecordArt({
    super.key,
    this.type,
    this.accent,
    this.label = 'FIELD RECORD',
    this.caption,
    this.height = 168,
  });
  final AssetType? type;
  final DuotoneGlyph? accent;
  final String label;
  final String? caption;
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD9EFEA), Color(0xFFE4ECF8), Color(0xFFF6EBDD)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sheet = math.min(height * .7, 150.0);
            final center = constraints.maxWidth / 2;
            Widget layer(Color color, double angle, double dx, double dy) =>
                Positioned(
                  left: center - sheet / 2 + dx,
                  top: (height - sheet) / 2 + dy,
                  child: Transform.rotate(
                    angle: angle,
                    child: Container(
                      width: sheet,
                      height: sheet * .9,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                );
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  right: -26,
                  top: -30,
                  child: _Halo(
                    color: Colors.white.withValues(alpha: .55),
                    size: 110,
                  ),
                ),
                Positioned(
                  left: -18,
                  bottom: -36,
                  child: _Halo(
                    color: const Color(0xFFF2C894).withValues(alpha: .35),
                    size: 96,
                  ),
                ),
                layer(
                  const Color(0xFF7CC2B5).withValues(alpha: .75),
                  -.22,
                  -sheet * .34,
                  6,
                ),
                layer(
                  const Color(0xFF9DB7E3).withValues(alpha: .7),
                  .18,
                  sheet * .3,
                  2,
                ),
                layer(
                  const Color(0xFFF0B97C).withValues(alpha: .55),
                  .05,
                  sheet * .02,
                  -6,
                ),
                Positioned(
                  left: center - sheet * .48,
                  top: (height - sheet * .86) / 2,
                  child: Transform.rotate(
                    angle: -.05,
                    child: _FrontSheet(
                      width: sheet * .96,
                      height: sheet * .86,
                      type: type,
                      accent: accent,
                      label: label,
                      caption: caption,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _Halo extends StatelessWidget {
  const _Halo({required this.color, required this.size});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _FrontSheet extends StatelessWidget {
  const _FrontSheet({
    required this.width,
    required this.height,
    required this.label,
    this.type,
    this.accent,
    this.caption,
  });
  final double width;
  final double height;
  final AssetType? type;
  final DuotoneGlyph? accent;
  final String label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    Widget bar(double factor, {double opacity = .1}) => Container(
      height: 6,
      width: width * factor,
      decoration: BoxDecoration(
        color: TankColors.navy.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: TankColors.navy.withValues(alpha: .12),
            offset: const Offset(0, 10),
            blurRadius: 22,
          ),
        ],
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Padding(
          padding: EdgeInsets.all(width * .1),
          child: MediaQuery.withNoTextScaling(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width * .8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (type != null)
                          AssetBadge(type!, size: width * .26)
                        else
                          Container(
                            width: width * .26,
                            height: width * .26,
                            decoration: BoxDecoration(
                              color: TankColors.mint,
                              borderRadius: BorderRadius.circular(width * .08),
                            ),
                            alignment: Alignment.center,
                            child: DuotoneIcon(
                              accent ?? TankAccents.inspection,
                              size: width * .16,
                              color: TankColors.teal,
                            ),
                          ),
                        SizedBox(width: width * .3),
                        Icon(
                          TankMeta.fileCheck,
                          size: width * .13,
                          color: TankColors.teal.withValues(alpha: .7),
                        ),
                      ],
                    ),
                    SizedBox(height: width * .1),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: math.max(8, width * .07),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: TankColors.tealDeep,
                      ),
                    ),
                    SizedBox(height: width * .04),
                    if (caption != null)
                      Text(
                        caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: math.max(9, width * .085),
                          fontWeight: FontWeight.w800,
                          color: TankColors.navy,
                        ),
                      )
                    else
                      bar(.7, opacity: .16),
                    SizedBox(height: width * .05),
                    bar(.55),
                    SizedBox(height: width * .035),
                    bar(.38),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A source-to-tap diagram of the asset types a facility actually has, with
/// their counts. It reads left to right on wide screens and top to bottom when
/// labels would not fit, such as on narrow phones with large text.
class NetworkFlowDiagram extends StatelessWidget {
  const NetworkFlowDiagram({super.key, required this.counts});
  final Map<AssetType, int> counts;

  static const order = [
    AssetType.borehole,
    AssetType.pump,
    AssetType.tank,
    AssetType.line,
    AssetType.tap,
  ];

  @override
  Widget build(BuildContext context) {
    final present = [
      for (final type in order)
        if ((counts[type] ?? 0) > 0) type,
    ];
    if (present.isEmpty) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.labelMedium!.copyWith(
      fontWeight: FontWeight.w700,
      color: TankColors.navy,
    );
    final scaler = MediaQuery.textScalerOf(context);
    return Semantics(
      label:
          'Water path: ${present.map((t) => '${counts[t]} ${assetTypeName(t).toLowerCase()}').join(', then ')}',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = constraints.maxWidth / present.length;
          final widest = present
              .map(
                (t) => (TextPainter(
                  text: TextSpan(text: _shortName(t), style: labelStyle),
                  textScaler: scaler,
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                )..layout()).width,
              )
              .reduce(math.max);
          final horizontal = widest + 6 <= slot && slot >= 52;
          return horizontal
              ? _horizontal(present, labelStyle, slot)
              : _vertical(present, labelStyle);
        },
      ),
    );
  }

  String _shortName(AssetType type) => switch (type) {
    AssetType.borehole => 'Borehole',
    AssetType.pump => 'Pump',
    AssetType.tank => 'Tank',
    AssetType.line => 'Pipes',
    AssetType.tap => 'Taps',
  };

  Widget _count(AssetType type) =>
      Positioned(right: -6, top: -6, child: _countChip(type));

  Widget _countChip(AssetType type) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: 1.3,
    child: Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: TankColors.navy,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        '${counts[type]}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  Widget _horizontal(List<AssetType> present, TextStyle style, double slot) {
    const badge = 50.0;
    return Stack(
      children: [
        Positioned(
          left: slot / 2,
          right: slot / 2,
          top: badge / 2 - 3,
          child: const _Pipe(horizontal: true),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final type in present)
              Expanded(
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AssetBadge(type, size: badge),
                        _count(type),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _shortName(type),
                      style: style,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _vertical(List<AssetType> present, TextStyle style) {
    const badge = 44.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, type) in present.indexed) ...[
          Row(
            children: [
              AssetBadge(type, size: badge),
              const SizedBox(width: 14),
              Expanded(child: Text(assetTypeName(type), style: style)),
              const SizedBox(width: 8),
              _countChip(type),
            ],
          ),
          if (index < present.length - 1)
            const Padding(
              padding: EdgeInsets.only(left: badge / 2 - 3),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(height: 18, child: _Pipe(horizontal: false)),
              ),
            ),
        ],
      ],
    );
  }
}

class _Pipe extends StatelessWidget {
  const _Pipe({required this.horizontal});
  final bool horizontal;
  @override
  Widget build(BuildContext context) => Container(
    width: horizontal ? null : 6,
    height: horizontal ? 6 : null,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: horizontal ? Alignment.centerLeft : Alignment.topCenter,
        end: horizontal ? Alignment.centerRight : Alignment.bottomCenter,
        colors: const [Color(0xFF8BC7BC), Color(0xFF9DB7E3)],
      ),
      borderRadius: BorderRadius.circular(3),
    ),
  );
}
