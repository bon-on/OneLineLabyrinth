import 'package:flutter/painting.dart';

/// Cosmetic night-sky themes, unlocked by sky level. Themes never change rules.
enum SkyTheme {
  twilight(
    requiredLevel: 1,
    label: 'Twilight',
    palette: SkyPalette(
      skyTop: Color(0xFF070B1F),
      skyMid: Color(0xFF1B1745),
      skyBottom: Color(0xFF4A2A5E),
      nebulaA: Color(0xFF5B3FA8),
      nebulaB: Color(0xFFC0587E),
      horizon: Color(0xFF0B0A1C),
      thread: Color(0xFFFFC46B),
      threadCore: Color(0xFFFFF4D6),
      star: Color(0xFFE9E6FF),
      accent: Color(0xFF9F8CFF),
      panel: Color(0xFF14123A),
      panelBorder: Color(0xFF3F3A7A),
      text: Color(0xFFF1EEFF),
      muted: Color(0xFFADA6D6),
      danger: Color(0xFFFF6B7D),
    ),
  ),
  aurora(
    requiredLevel: 3,
    label: 'Aurora',
    palette: SkyPalette(
      skyTop: Color(0xFF02101A),
      skyMid: Color(0xFF06283A),
      skyBottom: Color(0xFF0E4A4E),
      nebulaA: Color(0xFF26D69B),
      nebulaB: Color(0xFF3AA0E8),
      horizon: Color(0xFF020B10),
      thread: Color(0xFF7CFFD0),
      threadCore: Color(0xFFE8FFF6),
      star: Color(0xFFE2FBFF),
      accent: Color(0xFF52E3C2),
      panel: Color(0xFF062433),
      panelBorder: Color(0xFF1E5E6A),
      text: Color(0xFFEAFDFB),
      muted: Color(0xFF94C9C7),
      danger: Color(0xFFFF7A85),
    ),
  ),
  nebula(
    requiredLevel: 6,
    label: 'Nebula',
    palette: SkyPalette(
      skyTop: Color(0xFF12041C),
      skyMid: Color(0xFF34103F),
      skyBottom: Color(0xFF6A1E55),
      nebulaA: Color(0xFFE0479E),
      nebulaB: Color(0xFF7B5CFF),
      horizon: Color(0xFF0D0313),
      thread: Color(0xFFFF8FD0),
      threadCore: Color(0xFFFFEAF6),
      star: Color(0xFFFFE6F7),
      accent: Color(0xFFFF79C6),
      panel: Color(0xFF2A0C33),
      panelBorder: Color(0xFF6B2A6E),
      text: Color(0xFFFFF0FA),
      muted: Color(0xFFD7A5CB),
      danger: Color(0xFFFFA14D),
    ),
  ),
  eclipse(
    requiredLevel: 10,
    label: 'Eclipse',
    palette: SkyPalette(
      skyTop: Color(0xFF030304),
      skyMid: Color(0xFF0E0C0A),
      skyBottom: Color(0xFF2A1A0C),
      nebulaA: Color(0xFFFFB347),
      nebulaB: Color(0xFFB0472B),
      horizon: Color(0xFF050404),
      thread: Color(0xFFFFD27A),
      threadCore: Color(0xFFFFFBEA),
      star: Color(0xFFFFF3DC),
      accent: Color(0xFFFFC25C),
      panel: Color(0xFF16110C),
      panelBorder: Color(0xFF5A4223),
      text: Color(0xFFFFF7E8),
      muted: Color(0xFFCDB592),
      danger: Color(0xFFFF5E5E),
    ),
  );

  const SkyTheme({
    required this.requiredLevel,
    required this.label,
    required this.palette,
  });

  /// Sky level at which the theme becomes selectable.
  final int requiredLevel;

  /// Short English name shown in the UI.
  final String label;

  final SkyPalette palette;

  /// Parses a stored theme name; unknown values fall back to [twilight].
  static SkyTheme fromName(String? name) {
    for (final theme in values) {
      if (theme.name == name) return theme;
    }
    return twilight;
  }
}

/// Colours of one sky theme, shared by the scenery, the board and the panels.
class SkyPalette {
  const SkyPalette({
    required this.skyTop,
    required this.skyMid,
    required this.skyBottom,
    required this.nebulaA,
    required this.nebulaB,
    required this.horizon,
    required this.thread,
    required this.threadCore,
    required this.star,
    required this.accent,
    required this.panel,
    required this.panelBorder,
    required this.text,
    required this.muted,
    required this.danger,
  });

  final Color skyTop;
  final Color skyMid;
  final Color skyBottom;
  final Color nebulaA;
  final Color nebulaB;
  final Color horizon;

  /// The drawn line (glowing thread) and visited stars.
  final Color thread;

  /// The bright inner core of the thread.
  final Color threadCore;

  /// Unvisited stars and background stars.
  final Color star;
  final Color accent;
  final Color panel;
  final Color panelBorder;
  final Color text;
  final Color muted;
  final Color danger;

  /// Earned star colour in star ratings.
  Color get gold => const Color(0xFFFFD55C);
}
