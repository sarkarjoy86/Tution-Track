import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/accent_color_presets.dart';
import '../utils/theme.dart';

/// Central state management for dynamic app theming and dark mode
class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'tution_theme_mode';
  static const String _accentPresetKey = 'tution_accent_preset';

  ThemeMode _themeMode = ThemeMode.system;
  AccentColorPreset _currentPreset = AccentColorPreset.defaultPreset;
  bool _isInitialized = false;

  ThemeProvider() {
    _loadPreferences();
  }

  ThemeMode get themeMode => _themeMode;
  AccentColorPreset get currentPreset => _currentPreset;
  Color get currentPrimary => _currentPreset.primary;
  Color get currentPrimaryLight => _currentPreset.primaryLight;
  Color get currentPrimaryDark => _currentPreset.primaryDark;
  LinearGradient get currentGradient => _currentPreset.gradient;
  bool get isInitialized => _isInitialized;

  /// Dynamic ThemeData generated from current accent preset
  ThemeData get lightTheme => AppTheme.generateLightTheme(_currentPreset);
  ThemeData get darkTheme => AppTheme.generateDarkTheme(_currentPreset);

  /// Load persisted user settings from SharedPreferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedModeStr = prefs.getString(_themeModeKey);
      if (savedModeStr != null) {
        switch (savedModeStr) {
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          case 'system':
          default:
            _themeMode = ThemeMode.system;
            break;
        }
      }

      final savedPresetId = prefs.getString(_accentPresetKey);
      if (savedPresetId != null) {
        _currentPreset = AccentColorPreset.findById(savedPresetId);
      }
    } catch (_) {}
    _isInitialized = true;
    notifyListeners();
  }

  /// Change theme mode (system, light, dark) and persist to storage
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      String modeStr = 'system';
      if (mode == ThemeMode.light) modeStr = 'light';
      if (mode == ThemeMode.dark) modeStr = 'dark';
      await prefs.setString(_themeModeKey, modeStr);
    } catch (_) {}
  }

  /// Change accent color preset and persist to storage
  Future<void> setAccentPreset(String presetId) async {
    if (_currentPreset.id == presetId) return;
    _currentPreset = AccentColorPreset.findById(presetId);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accentPresetKey, presetId);
    } catch (_) {}
  }
}

