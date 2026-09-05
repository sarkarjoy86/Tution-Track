import 'package:flutter/material.dart';

/// Defines an accent color preset with harmonious gradients and dark/light variants
class AccentColorPreset {
  final String id;
  final String name;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final LinearGradient gradient;

  const AccentColorPreset({
    required this.id,
    required this.name,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.gradient,
  });

  /// All curated, high-contrast accent presets
  static const List<AccentColorPreset> allPresets = [
    // 1. Electric Blue (Default)
    AccentColorPreset(
      id: 'electricBlue',
      name: 'Electric Blue',
      primary: Color(0xFF2563EB),
      primaryDark: Color(0xFF1D4ED8),
      primaryLight: Color(0xFF60A5FA),
      gradient: LinearGradient(
        colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),

    // 2. Royal Indigo / Purple
    AccentColorPreset(
      id: 'royalIndigo',
      name: 'Royal Indigo',
      primary: Color(0xFF4F46E5),
      primaryDark: Color(0xFF3730A3),
      primaryLight: Color(0xFF818CF8),
      gradient: LinearGradient(
        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),

    // 3. Teal Emerald
    AccentColorPreset(
      id: 'tealEmerald',
      name: 'Teal Emerald',
      primary: Color(0xFF059669),
      primaryDark: Color(0xFF047857),
      primaryLight: Color(0xFF34D399),
      gradient: LinearGradient(
        colors: [Color(0xFF047857), Color(0xFF10B981)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),

    // 4. Crimson Red
    AccentColorPreset(
      id: 'crimsonRed',
      name: 'Crimson Red',
      primary: Color(0xFFDC2626),
      primaryDark: Color(0xFFB91C1C),
      primaryLight: Color(0xFFF87171),
      gradient: LinearGradient(
        colors: [Color(0xFFB91C1C), Color(0xFFEF4444)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),

    // 5. Vibrant Sunset / Orange
    AccentColorPreset(
      id: 'vibrantSunset',
      name: 'Vibrant Sunset',
      primary: Color(0xFFEA580C),
      primaryDark: Color(0xFFC2410C),
      primaryLight: Color(0xFFFB923C),
      gradient: LinearGradient(
        colors: [Color(0xFFC2410C), Color(0xFFF97316)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),

    // 6. Deep Rose / Pink
    AccentColorPreset(
      id: 'deepRose',
      name: 'Deep Rose',
      primary: Color(0xFFE11D48),
      primaryDark: Color(0xFFBE123C),
      primaryLight: Color(0xFFFB7185),
      gradient: LinearGradient(
        colors: [Color(0xFFBE123C), Color(0xFFF43F5E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  static AccentColorPreset get defaultPreset => allPresets.first;

  static AccentColorPreset findById(String id) {
    return allPresets.firstWhere(
      (p) => p.id == id,
      orElse: () => defaultPreset,
    );
  }
}
