import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// VCTRL Design System — Premium dark gaming aesthetic
class AppTheme {
  AppTheme._();

  // ── Core Palette ────────────────────────────────────────────────────────────
  static const Color bgDeep   = Color(0xFF060810); // deepest background
  static const Color bgBase   = Color(0xFF0A0C14); // primary background
  static const Color bgCard   = Color(0xFF111520); // card / surface
  static const Color bgPanel  = Color(0xFF161B28); // panel / overlay

  // Neon accents
  static const Color neonCyan    = Color(0xFF00E5FF); // primary — racing
  static const Color neonAmber   = Color(0xFFFFB300); // RPG / warning
  static const Color neonGreen   = Color(0xFF00E676); // throttle / healthy
  static const Color neonRed     = Color(0xFFFF1744); // brake / danger
  static const Color neonPurple  = Color(0xFFD500F9); // gamepad mode

  // Neutral
  static const Color textPrimary   = Color(0xFFEAECF5);
  static const Color textSecondary = Color(0xFF8A90A8);
  static const Color textDim       = Color(0xFF4A5068);
  static const Color divider       = Color(0xFF1E2438);

  // ── Glow Shadows ────────────────────────────────────────────────────────────
  static List<BoxShadow> glowCyan({double intensity = 1.0}) => [
        BoxShadow(color: neonCyan.withOpacity(0.55 * intensity), blurRadius: 18, spreadRadius: 2),
        BoxShadow(color: neonCyan.withOpacity(0.25 * intensity), blurRadius: 40, spreadRadius: 8),
      ];

  static List<BoxShadow> glowAmber({double intensity = 1.0}) => [
        BoxShadow(color: neonAmber.withOpacity(0.55 * intensity), blurRadius: 18, spreadRadius: 2),
        BoxShadow(color: neonAmber.withOpacity(0.25 * intensity), blurRadius: 40, spreadRadius: 8),
      ];

  static List<BoxShadow> glowGreen({double intensity = 1.0}) => [
        BoxShadow(color: neonGreen.withOpacity(0.55 * intensity), blurRadius: 18, spreadRadius: 2),
        BoxShadow(color: neonGreen.withOpacity(0.25 * intensity), blurRadius: 40, spreadRadius: 8),
      ];

  static List<BoxShadow> glowRed({double intensity = 1.0}) => [
        BoxShadow(color: neonRed.withOpacity(0.55 * intensity), blurRadius: 18, spreadRadius: 2),
        BoxShadow(color: neonRed.withOpacity(0.25 * intensity), blurRadius: 40, spreadRadius: 8),
      ];

  static List<BoxShadow> glowPurple({double intensity = 1.0}) => [
        BoxShadow(color: neonPurple.withOpacity(0.55 * intensity), blurRadius: 18, spreadRadius: 2),
        BoxShadow(color: neonPurple.withOpacity(0.25 * intensity), blurRadius: 40, spreadRadius: 8),
      ];

  // ── Typography ──────────────────────────────────────────────────────────────
  static TextStyle hud({double size = 11, Color? color, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.rajdhani(
        fontSize: size,
        fontWeight: weight,
        color: color ?? textSecondary,
        letterSpacing: 1.0,
      );

  static TextStyle digit({double size = 22, Color? color}) =>
      GoogleFonts.orbitron(
        fontSize: size,
        fontWeight: FontWeight.bold,
        color: color ?? neonCyan,
        letterSpacing: 2,
      );

  static TextStyle label({double size = 13, Color? color}) =>
      GoogleFonts.rajdhani(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? textSecondary,
        letterSpacing: 1.5,
      );

  static TextStyle title({double size = 20, Color? color}) =>
      GoogleFonts.orbitron(
        fontSize: size,
        fontWeight: FontWeight.bold,
        color: color ?? textPrimary,
        letterSpacing: 2,
      );

  // ── MaterialApp Theme ───────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: bgBase,
        colorScheme: const ColorScheme.dark(
          primary: neonCyan,
          secondary: neonAmber,
          error: neonRed,
          surface: bgCard,
        ),
        textTheme: GoogleFonts.rajdhaniTextTheme(ThemeData.dark().textTheme).copyWith(
          bodyMedium: GoogleFonts.rajdhani(color: textPrimary),
        ),
      );
}

// ── Game Mode Enum ──────────────────────────────────────────────────────────
enum GameMode {
  racing('Racing',  '🏎️', AppTheme.neonCyan),
  rpg   ('RPG',     '⚔️', AppTheme.neonAmber),
  pad   ('Gamepad', '🎮', AppTheme.neonPurple);

  const GameMode(this.label, this.emoji, this.color);
  final String label;
  final String emoji;
  final Color color;
}
