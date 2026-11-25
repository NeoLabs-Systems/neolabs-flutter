import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'palette.dart';

class NeoSidebarButton extends StatefulWidget {
  const NeoSidebarButton({
    required this.label,
    required this.icon,
    this.active = false,
    this.iconSize = 18,
    this.fontSize = 13,
    this.compact = false,
    this.trailing,
    required this.onTap,
    required this.palette,
  });

  final NeoLabsPalette palette;
  final String label;
  final IconData icon;
  final bool active;
  final double iconSize;
  final double fontSize;
  final bool compact;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  State<NeoSidebarButton> createState() => _NeoSidebarButtonState();
}

class _NeoSidebarButtonState extends State<NeoSidebarButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final radius = BorderRadius.circular(widget.compact ? 12 : 14);
    // Flat control-surface finish: the active row is a single accent wash —
    // no gradient, no drop shadows, no left rail bar. Selection reads from
    // the fill plus the gold glyph, the way the sibling app states it.
    final decoration = BoxDecoration(
      color: active
          ? widget.palette.accentMuted
          : (_hovering
                ? widget.palette.bgTertiary.withValues(alpha: 0.66)
                : Colors.transparent),
      borderRadius: radius,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 10 : 11,
                vertical: widget.compact ? 7 : 9,
              ),
              decoration: decoration,
              child: Row(
                children: <Widget>[
                  Icon(
                    widget.icon,
                    size: widget.iconSize,
                    color: active
                        ? widget.palette.accent
                        : widget.palette.textMuted,
                  ),
                  SizedBox(width: widget.compact ? 9 : 11),
                  Expanded(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.geist(
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        color: active
                            ? widget.palette.textPrimary
                            : widget.palette.textSecondary,
                      ),
                    ),
                  ),
                  if (widget.trailing != null) ...<Widget>[
                    const SizedBox(width: 8),
                    widget.trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
