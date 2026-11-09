import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../design_system.dart';

/// Whether the reader's text size is large enough (150% or more) that icon
/// tiles should sit above text instead of beside it, so words never split.
bool isLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(16) >= 24;

/// An identity mark beside its text; at large text sizes the mark moves above
/// the text so the text keeps the full width.
class LeadingRow extends StatelessWidget {
  const LeadingRow({
    super.key,
    required this.leading,
    required this.child,
    this.gap = 14,
  });
  final Widget leading;
  final Widget child;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (isLargeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          SizedBox(height: gap * .7),
          child,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leading,
        SizedBox(width: gap),
        Expanded(child: child),
      ],
    );
  }
}

/// Small uppercase context label above a heading or inside a card.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.icon, this.color});
  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? TankColors.tealDeep;
    final style = Theme.of(context).textTheme.labelSmall!.copyWith(
      color: tint,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    );
    if (icon == null) return Text(text.toUpperCase(), style: style);
    return MetaLine(icon!, text.toUpperCase(), color: tint, strong: true);
  }
}

/// A heading in two weights, after the approved reference: the quiet lead sets
/// context and the emphasis names what matters on the screen.
class TwoToneHeading extends StatelessWidget {
  const TwoToneHeading(this.lead, this.emphasis, {super.key, this.style});
  final String lead;
  final String emphasis;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.headlineLarge!;
    return Semantics(
      header: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: lead,
              style: base.copyWith(
                color: TankColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: emphasis, style: base),
          ],
        ),
      ),
    );
  }
}

/// Page header: an eyebrow for where you are and a two-tone heading for what
/// to do there.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.lead,
    required this.emphasis,
    this.eyebrowIcon,
    this.subtitle,
  });
  final String eyebrow;
  final IconData? eyebrowIcon;
  final String lead;
  final String emphasis;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Eyebrow(eyebrow, icon: eyebrowIcon),
      const SizedBox(height: 8),
      TwoToneHeading(lead, emphasis),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(
          subtitle!,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: TankColors.muted),
        ),
      ],
    ],
  );
}

enum ChipTone { neutral, positive, caution, info }

/// Compact state label. Color reinforces the words; it never replaces them.
class StateChip extends StatelessWidget {
  const StateChip(
    this.label, {
    super.key,
    this.tone = ChipTone.neutral,
    this.icon,
  });
  final String label;
  final ChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      ChipTone.neutral => (const Color(0xFFEAEFF3), TankColors.navy),
      ChipTone.positive => (TankColors.mint, TankColors.tealDeep),
      ChipTone.caution => (TankColors.caution, TankColors.amber),
      ChipTone.info => (const Color(0xFFE4ECF8), const Color(0xFF2B5687)),
    };
    final style = Theme.of(context).textTheme.labelMedium!.copyWith(
      color: foreground,
      fontWeight: FontWeight.w700,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: icon == null
          ? Text(label, style: style)
          : MetaLine(icon!, label, color: foreground, strong: true),
    );
  }
}

BoxDecoration _solidSurface({Color color = Colors.white, double radius = 24}) =>
    BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: TankColors.line),
      boxShadow: [
        BoxShadow(
          color: TankColors.navy.withValues(alpha: .06),
          offset: const Offset(0, 10),
          blurRadius: 26,
        ),
      ],
    );

/// Action card: one task, its due state and a single primary action.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.kind,
    required this.title,
    this.leading,
    this.status,
    this.details = const [],
    this.child,
    this.action,
  });
  final String kind;
  final String title;
  final Widget? leading;
  final Widget? status;
  final List<Widget> details;
  final Widget? child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: _solidSurface(),
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _withLeading(
            leading,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(kind),
                const SizedBox(height: 4),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          ),
          if (status != null || details.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [?status, ...details],
            ),
          ],
          if (child != null) ...[const SizedBox(height: 16), child!],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}

/// Evidence card: warm paper for dated records, with an optional illustration
/// band across the top.
class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.child,
    this.art,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final Widget? art;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    decoration: _solidSurface(color: TankColors.record),
    clipBehavior: Clip.antiAlias,
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?art,
          Padding(padding: padding, child: child),
        ],
      ),
    ),
  );
}

/// Exception panel: amber is reserved for something a person must act on.
class ExceptionPanel extends StatelessWidget {
  const ExceptionPanel({
    super.key,
    required this.label,
    required this.title,
    required this.message,
    this.action,
  });
  final String label;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: TankColors.caution,
      borderRadius: const BorderRadius.horizontal(
        left: Radius.circular(8),
        right: Radius.circular(20),
      ),
      border: const Border(
        left: BorderSide(color: Color(0xFFC27522), width: 4),
      ),
    ),
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label, color: TankColors.amber),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: const Color(0xFF5C3311)),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B3E17)),
          ),
          if (action != null) ...[const SizedBox(height: 6), action!],
        ],
      ),
    ),
  );
}

/// One step in a [FlowSteps] tracker.
class FlowStep {
  const FlowStep(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Plain-language progress tracker, so anyone can see where a record is and
/// what comes next. [current] is the index of the step in progress; steps
/// before it are done. Use -1 to explain the flow without showing progress.
class FlowSteps extends StatelessWidget {
  const FlowSteps({super.key, required this.steps, this.current = -1});
  final List<FlowStep> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium!.copyWith(
      fontWeight: FontWeight.w700,
      color: TankColors.navy,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final summary = current < 0
        ? 'Steps: ${steps.map((s) => s.label).join(', then ')}'
        : current >= steps.length
        ? 'All ${steps.length} steps done'
        : 'Step ${current + 1} of ${steps.length}: ${steps[current].label}';
    return Semantics(
      label: summary,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = constraints.maxWidth / steps.length;
          final widest = steps
              .map(
                (s) => (TextPainter(
                  text: TextSpan(text: s.label, style: style),
                  textScaler: scaler,
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                )..layout()).width,
              )
              .reduce(math.max);
          if (widest + 4 > slot) return _vertical(style);
          return Stack(
            children: [
              Positioned(
                left: slot / 2,
                right: slot / 2,
                top: 15,
                child: Row(
                  children: [
                    for (var i = 0; i < steps.length - 1; i++)
                      Expanded(child: _connector(i < current)),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (index, step) in steps.indexed)
                    Expanded(
                      child: Column(
                        children: [
                          _dot(index, step),
                          const SizedBox(height: 6),
                          Text(
                            step.label,
                            style: _labelStyle(style, index),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  TextStyle _labelStyle(TextStyle style, int index) =>
      index > current && current >= 0
      ? style.copyWith(color: TankColors.muted, fontWeight: FontWeight.w600)
      : style;

  Widget _connector(bool done) => Container(
    height: 3,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(
      color: done ? TankColors.teal : TankColors.line,
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _dot(int index, FlowStep step) {
    final explaining = current < 0;
    final done = !explaining && index < current;
    final active = !explaining && index == current;
    final color = done
        ? TankColors.teal
        : active
        ? TankColors.navy
        : explaining
        ? TankColors.mint
        : Colors.white;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: done || active
              ? color
              : explaining
              ? TankColors.teal.withValues(alpha: .35)
              : TankColors.line,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        done ? Symbols.check_rounded : step.icon,
        size: 17,
        weight: 600,
        color: done || active
            ? Colors.white
            : explaining
            ? TankColors.tealDeep
            : TankColors.muted,
      ),
    );
  }

  Widget _vertical(TextStyle style) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (index, step) in steps.indexed) ...[
        Row(
          children: [
            _dot(index, step),
            const SizedBox(width: 12),
            Expanded(child: Text(step.label, style: _labelStyle(style, index))),
          ],
        ),
        if (index < steps.length - 1)
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: SizedBox(
              width: 3,
              height: 14,
              child: _connector(index < current),
            ),
          ),
      ],
    ],
  );
}

/// A white group of [TankListRow]s separated by hairlines, for quiet queues
/// and history.
class ListGroupCard extends StatelessWidget {
  const ListGroupCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: _solidSurface(radius: 20),
    clipBehavior: Clip.antiAlias,
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0)
              const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
            child,
          ],
        ],
      ),
    ),
  );
}

class TankListRow extends StatelessWidget {
  const TankListRow({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.meta = const [],
    this.trailing,
    this.onTap,
  });
  final Widget? leading;
  final String title;
  final String? subtitle;
  final List<Widget> meta;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final content = _withLeading(
      leading,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: textTheme.bodySmall),
          ],
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 12, runSpacing: 4, children: meta),
          ],
        ],
      ),
    );
    // A trailing action moves under the text at large sizes so the text
    // keeps the full width.
    final stacked = trailing != null && isLargeText(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [content, const SizedBox(height: 8), trailing!],
                )
              : Row(
                  children: [
                    Expanded(child: content),
                    if (trailing != null)
                      trailing!
                    else if (onTap != null)
                      const Icon(
                        Symbols.chevron_right_rounded,
                        color: TankColors.muted,
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Friendly empty state with original artwork. The message must say what the
/// emptiness does and does not mean.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.title,
    required this.message,
    this.art,
    this.child,
    this.actions = const [],
  });
  final String title;
  final String message;
  final Widget? art;
  final Widget? child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Container(
    decoration: _solidSurface(),
    clipBehavior: Clip.antiAlias,
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          art ?? const LayeredRecordArt(height: 150),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: TankColors.muted),
                ),
                if (child != null) ...[const SizedBox(height: 18), child!],
                for (final (index, action) in actions.indexed) ...[
                  SizedBox(height: index == 0 ? 20 : 10),
                  action,
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// A tinted tile holding a Phosphor duotone accent, the identity mark for
/// non-asset records such as a facility, a repair or the upload queue.
class AccentTile extends StatelessWidget {
  const AccentTile(
    this.glyph, {
    super.key,
    this.size = 44,
    this.background = TankColors.mint,
    this.foreground = TankColors.tealDeep,
  });
  final DuotoneGlyph glyph;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(size * .3),
    ),
    alignment: Alignment.center,
    child: DuotoneIcon(glyph, size: size * .56, color: foreground),
  );
}

Widget _withLeading(Widget? leading, Widget child) =>
    leading == null ? child : LeadingRow(leading: leading, child: child);
