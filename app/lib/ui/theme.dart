import 'package:flutter/material.dart';

/// Visual tokens from docs/DESIGN.md §5.
class Palette {
  const Palette({
    required this.bodyTop,
    required this.bodyBottom,
    required this.screen,
    required this.screenBorder,
    required this.text,
    required this.subtext,
    required this.wheel,
    required this.wheelCenter,
    required this.wheelLabel,
  });

  final Color bodyTop, bodyBottom, screen, screenBorder, text, subtext;
  final Color wheel, wheelCenter, wheelLabel;

  static const accentTop = Color(0xFF5B9BEA);
  static const accentBottom = Color(0xFF2F6FCB);

  static const light = Palette(
    bodyTop: Color(0xFFF2F2F0),
    bodyBottom: Color(0xFFDCDCDA),
    screen: Color(0xFFFBFBF8),
    screenBorder: Color(0xFFBDBDBA),
    text: Color(0xFF111111),
    subtext: Color(0xFF6B6B68),
    wheel: Color(0xFFE6E6E4),
    wheelCenter: Color(0xFFF7F7F5),
    wheelLabel: Color(0xFF9A9A97),
  );

  static const dark = Palette(
    bodyTop: Color(0xFF1C1C1E),
    bodyBottom: Color(0xFF0E0E10),
    screen: Color(0xFF2A2A2C),
    screenBorder: Color(0xFF3E3E41),
    text: Color(0xFFF0F0F0),
    subtext: Color(0xFF9C9CA0),
    wheel: Color(0xFF2C2C2E),
    wheelCenter: Color(0xFF3A3A3C),
    wheelLabel: Color(0xFF8E8E93),
  );

  static Palette of(BuildContext context) =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark ? dark : light;
}
