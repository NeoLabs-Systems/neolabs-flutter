import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'palette.dart';

/// The building blocks of settings and admin pages: a heading over rows that
/// share one card. Apps supply the wording, the controls and the palette.

/// A titled block of rows on one card with the standard gap below.
class NeoSettingsGroup extends StatelessWidget {
  const NeoSettingsGroup({
    super.key,
    required this.palette,
    required this.title,
    required this.children,
    this.description,
    this.trailing,
    this.gap = 28,
  });

  final NeoLabsPalette palette;
  final String title;
  final String? description;
  final Widget? trailing;
  final List<Widget> children;

  /// Space below the group; smaller where the page spaces its blocks itself.
  final double gap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: gap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        NeoSettingsHeading(
          palette: palette,
          title: title,
          description: description,
          trailing: trailing,
        ),
        if (children.isNotEmpty)
          NeoSettingsCard(palette: palette, children: children),
      ],
    ),
  );
}

/// The heading over a group of settings, also used over content that brings
/// its own layout. On a narrow screen the trailing control moves under it.
class NeoSettingsHeading extends StatelessWidget {
  const NeoSettingsHeading({
    super.key,
    required this.palette,
    required this.title,
    this.description,
    this.trailing,
  });

  final NeoLabsPalette palette;
  final String title;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final trailing = this.trailing;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.titleSmall?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        if (description != null) ...<Widget>[
          const SizedBox(height: 3),
          Text(
            description!,
            style: theme.bodyMedium?.copyWith(
              fontSize: 13,
              color: palette.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 640) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                heading,
                if (trailing != null) ...<Widget>[
                  const SizedBox(height: 12),
                  trailing,
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(child: heading),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 12),
                trailing,
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Rows on a single card, split by hairlines.
class NeoSettingsCard extends StatelessWidget {
  const NeoSettingsCard({
    super.key,
    required this.palette,
    required this.children,
  });

  final NeoLabsPalette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: palette.bgCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: palette.border),
    ),
    clipBehavior: Clip.antiAlias,
    // List tiles and ink paint on the nearest Material, which the card color
    // would otherwise hide.
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, thickness: 1, color: palette.border),
            children[i],
          ],
        ],
      ),
    ),
  );
}

/// One setting: label and help on the left, its control on the right. On a
/// narrow screen the control moves under the label.
class NeoSettingsRow extends StatelessWidget {
  const NeoSettingsRow({
    super.key,
    required this.palette,
    required this.label,
    this.description,
    this.control,
    this.fillControl = false,
    this.tag,
    this.enabled = true,
  });

  final NeoLabsPalette palette;
  final String label;
  final String? description;
  final Widget? control;

  /// Gives the control a fixed width beside the label and the full width
  /// under it. Pickers and text fields need this; switches and buttons size
  /// themselves.
  final bool fillControl;

  /// Short qualifier next to the label, such as "This device".
  final String? tag;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
            if (tag != null) _Tag(palette: palette, label: tag!),
          ],
        ),
        if (description != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            description!,
            style: TextStyle(
              fontSize: 13,
              color: palette.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final control = this.control;
          if (control == null) return text;
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                text,
                const SizedBox(height: 12),
                if (fillControl)
                  control
                else
                  Align(alignment: Alignment.centerLeft, child: control),
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: text),
              const SizedBox(width: 24),
              if (fillControl)
                SizedBox(width: 300, child: control)
              else
                control,
            ],
          );
        },
      ),
    );
    return enabled
        ? row
        : IgnorePointer(child: Opacity(opacity: 0.5, child: row));
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.palette, required this.label});

  final NeoLabsPalette palette;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: palette.bgTertiary,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: palette.border),
    ),
    child: Text(
      label.toUpperCase(),
      style: GoogleFonts.geistMono(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: palette.textSecondary,
      ),
    ),
  );
}
