import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Offline-safe 8-bit retro typography for 《罪普拉 RPG》.
/// Wraps 'Press Start 2P' and 'VT323' with robust fallback to system monospace
/// ('VT323', 'Courier New', 'Consolas', 'monospace').
/// Prevents unhandled network socket exceptions when running tests or offline.
class RetroTypography {
  static const String primaryFont = 'Press Start 2P';
  static const String secondaryFont = 'VT323';

  static const List<String> monospaceFallback = [
    'VT323',
    'Courier New',
    'Consolas',
    'monospace',
  ];

  /// Safe runtime check to determine whether we should bypass GoogleFonts network calls.
  static bool get isTestOrOffline {
    // 1. Check if runtime fetching was explicitly disabled (e.g. in tests)
    if (!GoogleFonts.config.allowRuntimeFetching) {
      return true;
    }
    // 2. Check flutter test binding
    final binding = WidgetsBinding.instance;
    if (binding.runtimeType.toString().contains('Test')) {
      return true;
    }
    return false;
  }

  /// Primary 8-bit pixel header style ('Press Start 2P' with monospace fallback)
  static TextStyle pixelHeader({
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.bold,
    Color color = Colors.white,
    double letterSpacing = 1.2,
    double? height,
  }) {
    if (isTestOrOffline) {
      return TextStyle(
        fontFamily: primaryFont,
        fontFamilyFallback: monospaceFallback,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }
    try {
      return GoogleFonts.pressStart2p(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      ).copyWith(fontFamilyFallback: monospaceFallback);
    } catch (_) {
      return TextStyle(
        fontFamily: primaryFont,
        fontFamilyFallback: monospaceFallback,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }
  }

  /// Secondary pixel body/monospace style ('VT323' with monospace fallback)
  static TextStyle pixelBody({
    double fontSize = 10,
    FontWeight fontWeight = FontWeight.normal,
    Color color = Colors.white,
    double letterSpacing = 1.0,
    double? height,
  }) {
    if (isTestOrOffline) {
      return TextStyle(
        fontFamily: secondaryFont,
        fontFamilyFallback: monospaceFallback,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }
    try {
      return GoogleFonts.vt323(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      ).copyWith(fontFamilyFallback: monospaceFallback);
    } catch (_) {
      return TextStyle(
        fontFamily: secondaryFont,
        fontFamilyFallback: monospaceFallback,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );
    }
  }
}
