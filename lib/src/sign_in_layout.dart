import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_visuals.dart';
import 'palette.dart';

/// The NeoLabs sign-in screen: a card with the app's mark set into its top
/// edge, a centred heading, the phone sign-in code above the password form and
/// quiet links under the card. Apps supply the wording and their own state.

const Color _qrInk = Color(0xFF0E1511);

/// The backdrop, scrolling and width of a sign-in screen. The content rises in
/// once unless the platform asks for reduced motion.
class NeoAuthPage extends StatelessWidget {
  const NeoAuthPage({
    super.key,
    required this.palette,
    required this.compact,
    required this.children,
  });

  final NeoLabsPalette palette;
  final bool compact;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => NeoAuthBackdrop(
    palette: palette,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: viewport.maxHeight),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 14 : 24,
                  vertical: compact ? 20 : 32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _Entrance(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
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

class _Entrance extends StatefulWidget {
  const _Entrance({required this.child});

  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    const duration = Duration(milliseconds: 700);
    return AnimatedSlide(
      duration: duration,
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : const Offset(0, 0.035),
      child: AnimatedOpacity(
        duration: duration,
        curve: Curves.easeOutCubic,
        opacity: _visible ? 1 : 0,
        child: widget.child,
      ),
    );
  }
}

/// The card, with [mark] (a mascot or logo, [markSize] square) in its top edge.
class NeoAuthCard extends StatelessWidget {
  const NeoAuthCard({
    super.key,
    required this.palette,
    required this.compact,
    required this.mark,
    required this.child,
    this.markSize = 76,
  });

  final NeoLabsPalette palette;
  final bool compact;
  final Widget mark, child;
  final double markSize;

  @override
  Widget build(BuildContext context) {
    const ring = 6.0;
    final overlap = markSize / 2 + ring;
    final side = compact ? 20.0 : 32.0;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(top: overlap),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.bgCard,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: palette.border),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 40,
                  offset: const Offset(0, 18),
                ),
                BoxShadow(
                  color: palette.accent.withValues(alpha: 0.07),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(side, overlap + 18, side, 28),
              child: child,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(ring),
          decoration: BoxDecoration(
            color: palette.bgCard,
            borderRadius: BorderRadius.circular(34),
          ),
          child: SizedBox.square(dimension: markSize, child: mark),
        ),
      ],
    );
  }
}

class NeoAuthHeading extends StatelessWidget {
  const NeoAuthHeading({
    super.key,
    required this.palette,
    required this.title,
    required this.subtitle,
  });

  final NeoLabsPalette palette;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.15,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: 14,
          height: 1.45,
        ),
      ),
    ],
  );
}

/// The decoration of a sign-in field; its label sits above it.
InputDecoration neoAuthInputDecoration(
  NeoLabsPalette palette, {
  String? errorText,
  Widget? suffixIcon,
}) => InputDecoration(
  filled: true,
  fillColor: palette.bgPrimary,
  errorText: errorText,
  suffixIcon: suffixIcon,
);

/// The style of the small links beside labels and under the card.
ButtonStyle neoAuthLinkStyle() => TextButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 4),
  minimumSize: const Size(0, 32),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
);

/// A field with its label above it; [trailing] ends the label row. The label is
/// the field's accessible name.
class NeoLabeledField extends StatelessWidget {
  const NeoLabeledField({
    super.key,
    required this.palette,
    required this.label,
    required this.field,
    this.trailing,
  });

  final NeoLabsPalette palette;
  final String label;
  final Widget field;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            // The field announces the label itself, below.
            child: ExcludeSemantics(
              child: Text(
                label,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
      const SizedBox(height: 6),
      Semantics(label: label, child: field),
    ],
  );
}

class NeoOrDivider extends StatelessWidget {
  const NeoOrDivider({super.key, required this.palette, required this.label});

  final NeoLabsPalette palette;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(child: Divider(color: palette.border)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          label,
          style: TextStyle(color: palette.textMuted, fontSize: 12),
        ),
      ),
      Expanded(child: Divider(color: palette.border)),
    ],
  );
}

/// The code a signed-in phone scans: beside its instructions where there is
/// room, otherwise a row that opens it.
class NeoQrSignInCard extends StatelessWidget {
  const NeoQrSignInCard({
    super.key,
    required this.palette,
    required this.payload,
    required this.preparing,
    required this.title,
    required this.instructions,
    required this.status,
    required this.refreshLabel,
    required this.openLabel,
    required this.onRefresh,
    required this.onOpen,
    this.onLayout,
  });

  /// Below this width the code is not shown inline.
  static const double inlineWidth = 340;

  final NeoLabsPalette palette;

  /// Null while there is no usable code.
  final String? payload;
  final bool preparing;
  final String title, instructions;

  /// The countdown, or that a code is being waited for.
  final String status;
  final String refreshLabel, openLabel;
  final VoidCallback onRefresh, onOpen;

  /// Told whether the code is on screen, so the app polls only then. Called
  /// during layout.
  final ValueChanged<bool>? onLayout;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: palette.bgPrimary,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: palette.accent.withValues(alpha: 0.38)),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final inline = constraints.maxWidth >= inlineWidth;
        onLayout?.call(inline);
        return inline ? _inline(decoration) : _row(decoration);
      },
    );
  }

  Widget _inline(BoxDecoration decoration) => Container(
    padding: const EdgeInsets.all(16),
    decoration: decoration,
    child: Row(
      children: <Widget>[
        NeoAuthQrPlate(size: 116, payload: payload, preparing: preparing),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                instructions,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      status,
                      style: GoogleFonts.geistMono(
                        color: palette.textMuted,
                        fontSize: 11,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: refreshLabel,
                    onPressed: preparing ? null : onRefresh,
                    color: palette.textSecondary,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _row(BoxDecoration decoration) => Material(
    color: Colors.transparent,
    child: Ink(
      decoration: decoration,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: preparing ? null : onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: NeoAuthQrPlate.paper,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_2_rounded, color: _qrInk),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      openLabel,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.textMuted),
            ],
          ),
        ),
      ),
    ),
  );
}
