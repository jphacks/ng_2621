import 'package:flutter/material.dart';

/// A crisp, one-logical-pixel outline without duplicating text or semantics.
/// Inherited by ordinary Text widgets; layout and text scaling stay unchanged.
class PixelTextOutline extends StatelessWidget {
  const PixelTextOutline({
    super.key,
    required this.child,
    this.lightText = false,
  });

  final Widget child;
  final bool lightText;
  static const ink = Color(0xFF17241C);

  static List<Shadow> shadowsFor({bool lightText = false}) => [
    for (final offset in const [
      Offset(-1, -1),
      Offset(0, -1),
      Offset(1, -1),
      Offset(-1, 0),
      Offset(1, 0),
      Offset(-1, 1),
      Offset(0, 1),
      Offset(1, 1),
    ])
      Shadow(
        color: lightText ? const Color(0xFF101810) : const Color(0xFFFFFFFF),
        offset: offset,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: lightText ? const Color(0xFFFFFFFF) : ink,
      shadows: shadowsFor(lightText: lightText),
    );
    // Nested Material/ListTile widgets obtain their text styles from Theme,
    // replacing DefaultTextStyle. Cover both inheritance paths locally.
    final overlay = TextTheme(
      displayLarge: style,
      displayMedium: style,
      displaySmall: style,
      headlineLarge: style,
      headlineMedium: style,
      headlineSmall: style,
      titleLarge: style,
      titleMedium: style,
      titleSmall: style,
      bodyLarge: style,
      bodyMedium: style,
      bodySmall: style,
      labelLarge: style,
      labelMedium: style,
      labelSmall: style,
    );
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme.merge(overlay),
        primaryTextTheme: base.primaryTextTheme.merge(overlay),
      ),
      child: DefaultTextStyle.merge(style: style, child: child),
    );
  }
}
