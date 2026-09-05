import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tution_track/providers/theme_provider.dart';
import 'package:tution_track/utils/accent_color_presets.dart';
import 'package:tution_track/utils/theme.dart';
import 'package:tution_track/utils/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccentColorPreset Tests', () {
    test('Contains exactly 6 curated high-contrast presets', () {
      expect(AccentColorPreset.allPresets.length, 6);
      final ids = AccentColorPreset.allPresets.map((p) => p.id).toList();
      expect(ids, containsAll([
        'royalIndigo',
        'electricBlue',
        'tealEmerald',
        'crimsonRed',
        'vibrantSunset',
        'deepRose',
      ]));
    });

    test('findById returns matching preset or fallback', () {
      final blue = AccentColorPreset.findById('electricBlue');
      expect(blue.id, 'electricBlue');
      expect(blue.primary, const Color(0xFF2563EB));

      final fallback = AccentColorPreset.findById('non_existent_preset');
      expect(fallback.id, 'electricBlue');
    });

    test('All presets provide two-tone gradients', () {
      for (final preset in AccentColorPreset.allPresets) {
        expect(preset.gradient.colors.length, greaterThanOrEqualTo(2));
      }
    });
  });

  group('ThemeProvider State & Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initializes with default preset and system theme mode', () async {
      final provider = ThemeProvider();
      expect(provider.themeMode, ThemeMode.system);
      expect(provider.currentPreset.id, 'electricBlue');
      expect(provider.currentPrimary, const Color(0xFF2563EB));
    });

    test('setThemeMode updates themeMode and notifies listeners', () async {
      final provider = ThemeProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      await provider.setThemeMode(ThemeMode.dark);
      expect(provider.themeMode, ThemeMode.dark);
      expect(notified, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tution_theme_mode'), 'dark');
    });

    test('setAccentPreset updates accent preset and themes', () async {
      final provider = ThemeProvider();

      var notified = false;
      provider.addListener(() => notified = true);

      await provider.setAccentPreset('tealEmerald');
      expect(provider.currentPreset.id, 'tealEmerald');
      expect(provider.currentPrimary, const Color(0xFF059669));
      expect(notified, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tution_accent_preset'), 'tealEmerald');
    });
  });

  group('Dark Theme Architecture Tests', () {
    testWidgets('Dark theme uses high-contrast OLED slate background and card surfaces', (tester) async {
      final preset = AccentColorPreset.defaultPreset;
      final darkTheme = AppTheme.generateDarkTheme(preset);

      await tester.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: Scaffold(
            body: Container(),
          ),
        ),
      );

      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.scaffoldBackgroundColor, const Color(0xFF0F172A));
      expect(darkTheme.cardTheme.color, const Color(0xFF1E293B));
      expect(darkTheme.colorScheme.primary, preset.primaryLight);
    });

    test('Constants confirm app version 1.5.2 and Sic Mundus developer', () {
      expect(AppConstants.appVersion, '1.5.2');
      expect(AppConstants.appDeveloper, 'Sic Mundus');
    });
  });
}

