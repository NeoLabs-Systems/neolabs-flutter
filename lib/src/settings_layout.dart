import 'package:flutter/material.dart';

/// Responsive settings shell. Apps own the navigation and page contents.
class NeoSettingsLayout extends StatelessWidget {
  const NeoSettingsLayout({
    super.key,
    required this.navigation,
    required this.content,
    required this.showNavigationOnCompact,
    required this.railColor,
    required this.borderColor,
    this.breakpoint = 760,
    this.railWidth = 268,
  });

  final Widget navigation;
  final Widget content;
  final bool showNavigationOnCompact;
  final Color railColor;
  final Color borderColor;
  final double breakpoint;
  final double railWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < breakpoint) {
        return showNavigationOnCompact ? navigation : content;
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: railWidth,
            decoration: BoxDecoration(
              color: railColor,
              border: Border(right: BorderSide(color: borderColor)),
            ),
            child: navigation,
          ),
          Expanded(child: content),
        ],
      );
    },
  );
}
