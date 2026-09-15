import 'package:flutter/material.dart';

/// Retro Dark Workbench Palette for 《罪普拉 RPG》
/// Unifies hex codes into a cohesive 8-bit arcade workbench color system.
class RetroColors {
  // --- Workbench & Surface Bases ---
  /// Main workbench scaffold background (#12141F)
  static const Color darkSlate = Color(0xFF12141F);

  /// Battle stage background & deep modal inner box (#0D0E15)
  static const Color darkSlateDeep = Color(0xFF0D0E15);

  /// Card backgrounds & drawer panels (#1B1B26)
  static const Color surfaceDark = Color(0xFF1B1B26);

  /// App bar headers, HUD panels & tab bars (#212234)
  static const Color surfaceElevated = Color(0xFF212234);

  // --- Retro Arcade Accents & Grade Colors ---
  /// Primary arcade gold, quest clear title, gold coins, active stars (#FFD54F)
  static const Color retroAmber = Color(0xFFFFD54F);

  /// MG grade badge, showcase action accent (#FFB86C)
  static const Color retroOrange = Color(0xFFFFB86C);

  /// Tech subtitles, Detailing skill, HG grade, CRT grid (#8BE9FD)
  static const Color cyberCyan = Color(0xFF8BE9FD);

  /// Start button, Rest phase HUD, EG grade, HP > 50% (#50FA7B)
  static const Color neonGreen = Color(0xFF50FA7B);

  /// Interruption button, Boss hurt flash, HP <= 20%, delete buttons (#FF5252)
  static const Color crimsonRed = Color(0xFFFF5252);

  /// Dialogue border, Finishing phase skill, PG grade (#BD93F9)
  static const Color retroPurple = Color(0xFFBD93F9);

  // --- Borders & Separators ---
  /// Primary retro panel borders (2px / 3px) (#383A59)
  static const Color borderDark = Color(0xFF383A59);

  /// Inactive kit card borders, inactive tab borders (#44475A)
  static const Color borderMuted = Color(0xFF44475A);

  /// Active filter chips, hover highlights (#6272A4)
  static const Color borderLight = Color(0xFF6272A4);
}
