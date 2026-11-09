import 'package:flutter/material.dart';
import '../design_system.dart';

const _package = 'tankloop_design_system';

/// Icon roles. Each family has one job so a symbol never changes style for the
/// same meaning:
/// - Material Symbols Rounded (`Symbols.*_rounded`): navigation and actions.
/// - Phosphor duotone ([TankAccents]): larger evidence and feature accents.
/// - Lucide ([TankMeta]): quiet metadata beside dates, owners and sources.
/// Water assets use the original pictograms in `artwork.dart` instead.
///
/// Code points come from the bundled font releases listed in
/// THIRD_PARTY_NOTICES.md. Keep every [IconData] constant so release builds
/// can tree-shake the fonts.
abstract final class TankMeta {
  static const calendar = IconData(
    0xe063,
    fontFamily: 'Lucide',
    fontPackage: _package,
  );
  static const clock = IconData(
    0xe087,
    fontFamily: 'Lucide',
    fontPackage: _package,
  );
  static const mapPin = IconData(
    0xe111,
    fontFamily: 'Lucide',
    fontPackage: _package,
  );
  static const user = IconData(
    0xe468,
    fontFamily: 'Lucide',
    fontPackage: _package,
  );
  static const paperclip = IconData(
    0xe12d,
    fontFamily: 'Lucide',
    fontPackage: _package,
  );
  static const link = IconData(
    0xe102,
    fontFamily: 'Lucide',
    fontPackage: _package,
  );
  static const hash = IconData(
    0xe0ef,
    fontFamily: 'Lucide',
    fontPackage: _package,
  );
  static const device = IconData(
    0xe163,
    fontFamily: 'Lucide',
    fontPackage: _package,
  );
  static const fileCheck = IconData(
    0xe0c1,
    fontFamily: 'Lucide',
    fontPackage: _package,
  );
  static const fileText = IconData(
    0xe0cc,
    fontFamily: 'Lucide',
    fontPackage: _package,
  );
  static const cloud = IconData(
    0xe088,
    fontFamily: 'Lucide',
    fontPackage: _package,
  );
  static const building = IconData(
    0xe290,
    fontFamily: 'Lucide',
    fontPackage: _package,
  );
  static const hourglass = IconData(
    0xe296,
    fontFamily: 'Lucide',
    fontPackage: _package,
  );
  static const connected = IconData(
    0xe0a2,
    fontFamily: 'Lucide',
    fontPackage: _package,
  );
  static const listChecks = IconData(
    0xe1d0,
    fontFamily: 'Lucide',
    fontPackage: _package,
  );
  static const source = IconData(
    0xe0d1,
    fontFamily: 'Lucide',
    fontPackage: _package,
  );
}

/// A Phosphor duotone glyph: a translucent fill layer under an outline layer.
class DuotoneGlyph {
  const DuotoneGlyph(this.fill, this.outline);
  final IconData fill;
  final IconData outline;
}

abstract final class TankAccents {
  static const inspection = DuotoneGlyph(
    IconData(0xe198, fontFamily: 'PhosphorDuotone', fontPackage: _package),
    IconData(0xe199, fontFamily: 'PhosphorDuotone', fontPackage: _package),
  );
  static const checklist = DuotoneGlyph(
    IconData(0xeadc, fontFamily: 'PhosphorDuotone', fontPackage: _package),
    IconData(0xeadd, fontFamily: 'PhosphorDuotone', fontPackage: _package),
  );
  static const repair = DuotoneGlyph(
    IconData(0xe5d4, fontFamily: 'PhosphorDuotone', fontPackage: _package),
    IconData(0xe5d5, fontFamily: 'PhosphorDuotone', fontPackage: _package),
  );
  static const receipt = DuotoneGlyph(
    IconData(0xe3ec, fontFamily: 'PhosphorDuotone', fontPackage: _package),
    IconData(0xe3f1, fontFamily: 'PhosphorDuotone', fontPackage: _package),
  );
  static const verified = DuotoneGlyph(
    IconData(0xe606, fontFamily: 'PhosphorDuotone', fontPackage: _package),
    IconData(0xe607, fontFamily: 'PhosphorDuotone', fontPackage: _package),
  );
  static const concern = DuotoneGlyph(
    IconData(0xe4e2, fontFamily: 'PhosphorDuotone', fontPackage: _package),
    IconData(0xe4e3, fontFamily: 'PhosphorDuotone', fontPackage: _package),
  );
  static const report = DuotoneGlyph(
    IconData(0xe324, fontFamily: 'PhosphorDuotone', fontPackage: _package),
    IconData(0xe325, fontFamily: 'PhosphorDuotone', fontPackage: _package),
  );
  static const photo = DuotoneGlyph(
    IconData(0xe10e, fontFamily: 'PhosphorDuotone', fontPackage: _package),
    IconData(0xe10f, fontFamily: 'PhosphorDuotone', fontPackage: _package),
  );
  static const waiting = DuotoneGlyph(
    IconData(0xe2b8, fontFamily: 'PhosphorDuotone', fontPackage: _package),
    IconData(0xe2b9, fontFamily: 'PhosphorDuotone', fontPackage: _package),
  );
  static const upload = DuotoneGlyph(
    IconData(0xe1ae, fontFamily: 'PhosphorDuotone', fontPackage: _package),
    IconData(0xe1af, fontFamily: 'PhosphorDuotone', fontPackage: _package),
  );
  static const synced = DuotoneGlyph(
    IconData(0xe1b0, fontFamily: 'PhosphorDuotone', fontPackage: _package),
    IconData(0xe1b1, fontFamily: 'PhosphorDuotone', fontPackage: _package),
  );
  static const offline = DuotoneGlyph(
    IconData(0xe1b6, fontFamily: 'PhosphorDuotone', fontPackage: _package),
    IconData(0xe1b7, fontFamily: 'PhosphorDuotone', fontPackage: _package),
  );
  static const point = DuotoneGlyph(
    IconData(0xe316, fontFamily: 'PhosphorDuotone', fontPackage: _package),
    IconData(0xe317, fontFamily: 'PhosphorDuotone', fontPackage: _package),
  );
  static const facility = DuotoneGlyph(
    IconData(0xe102, fontFamily: 'PhosphorDuotone', fontPackage: _package),
    IconData(0xe105, fontFamily: 'PhosphorDuotone', fontPackage: _package),
  );
  static const records = DuotoneGlyph(
    IconData(0xe710, fontFamily: 'PhosphorDuotone', fontPackage: _package),
    IconData(0xe711, fontFamily: 'PhosphorDuotone', fontPackage: _package),
  );
  static const badge = DuotoneGlyph(
    IconData(0xe6f6, fontFamily: 'PhosphorDuotone', fontPackage: _package),
    IconData(0xe6f7, fontFamily: 'PhosphorDuotone', fontPackage: _package),
  );
  static const scan = DuotoneGlyph(
    IconData(0xe3e6, fontFamily: 'PhosphorDuotone', fontPackage: _package),
    IconData(0xe3e7, fontFamily: 'PhosphorDuotone', fontPackage: _package),
  );
  static const scheduled = DuotoneGlyph(
    IconData(0xe712, fontFamily: 'PhosphorDuotone', fontPackage: _package),
    IconData(0xe713, fontFamily: 'PhosphorDuotone', fontPackage: _package),
  );
  static const limits = DuotoneGlyph(
    IconData(0xe40c, fontFamily: 'PhosphorDuotone', fontPackage: _package),
    IconData(0xe40f, fontFamily: 'PhosphorDuotone', fontPackage: _package),
  );
}

/// Renders a [DuotoneGlyph] in one color, with the fill layer at 22% opacity.
class DuotoneIcon extends StatelessWidget {
  const DuotoneIcon(
    this.glyph, {
    super.key,
    this.size = 28,
    this.color,
    this.semanticLabel,
  });
  final DuotoneGlyph glyph;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color ?? TankColors.teal;
    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            Icon(glyph.fill, size: size, color: tint.withValues(alpha: .22)),
            Icon(glyph.outline, size: size, color: tint),
          ],
        ),
      ),
    );
  }
}

/// One quiet metadata fact, such as a date, owner or source, with a Lucide
/// glyph that grows with the reader's text size.
class MetaLine extends StatelessWidget {
  const MetaLine(this.icon, this.text, {super.key, this.color, this.strong});
  final IconData icon;
  final String text;
  final Color? color;
  final bool? strong;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? TankColors.muted;
    final style = Theme.of(context).textTheme.labelMedium!.copyWith(
      color: tint,
      fontWeight: strong == true ? FontWeight.w700 : FontWeight.w600,
    );
    final iconSize = MediaQuery.textScalerOf(
      context,
    ).scale(15).clamp(15, 26).toDouble();
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: iconSize, color: tint),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: style)),
      ],
    );
  }
}
