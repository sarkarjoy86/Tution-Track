import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/student_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/accent_color_presets.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

/// Settings screen with dynamic appearance controls, theme modes, color presets, and app info
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final studentProvider = context.watch<StudentProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = authProvider.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Profile Card ──────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: themeProvider.currentGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: themeProvider.currentPrimary.withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (user?.name ?? 'T').substring(0, 1).toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Tutor',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.85),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusFull),
                            ),
                            child: Text(
                              user?.authProvider == 'google'
                                  ? '🔗 Google Account'
                                  : '✉️ Email Account',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ─── Appearance: Theme Mode & Accent Color ─
              Text(
                'Appearance',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                  ),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Theme Mode Label
                    Row(
                      children: [
                        Icon(
                          Icons.palette_outlined,
                          size: 18,
                          color: themeProvider.currentPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Theme Mode',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 3-Way Mode Segmented Selector
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: isDark
                              ? AppTheme.darkBorder
                              : AppTheme.borderLight,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          _ThemeModeOption(
                            label: 'Light',
                            icon: Icons.light_mode_rounded,
                            isSelected:
                                themeProvider.themeMode == ThemeMode.light,
                            activeColor: themeProvider.currentPrimary,
                            isDark: isDark,
                            onTap: () =>
                                themeProvider.setThemeMode(ThemeMode.light),
                          ),
                          _ThemeModeOption(
                            label: 'Dark',
                            icon: Icons.dark_mode_rounded,
                            isSelected:
                                themeProvider.themeMode == ThemeMode.dark,
                            activeColor: themeProvider.currentPrimary,
                            isDark: isDark,
                            onTap: () =>
                                themeProvider.setThemeMode(ThemeMode.dark),
                          ),
                          _ThemeModeOption(
                            label: 'System',
                            icon: Icons.brightness_auto_rounded,
                            isSelected:
                                themeProvider.themeMode == ThemeMode.system,
                            activeColor: themeProvider.currentPrimary,
                            isDark: isDark,
                            onTap: () =>
                                themeProvider.setThemeMode(ThemeMode.system),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    Divider(
                      height: 1,
                      color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                    ),
                    const SizedBox(height: 16),

                    // Accent Presets Label
                    Row(
                      children: [
                        Icon(
                          Icons.color_lens_outlined,
                          size: 18,
                          color: themeProvider.currentPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Primary Accent Color',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          themeProvider.currentPreset.name,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: themeProvider.currentPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Horizontal Swatches Row
                    SizedBox(
                      height: 54,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: AccentColorPreset.allPresets.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final preset = AccentColorPreset.allPresets[index];
                          final isSelected =
                              themeProvider.currentPreset.id == preset.id;
                          return _ColorSwatch(
                            preset: preset,
                            isSelected: isSelected,
                            onTap: () =>
                                themeProvider.setAccentPreset(preset.id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ─── Statistics ────────────────────────────
              Text(
                'Overview',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.people_alt_rounded,
                      label: 'Active',
                      value: '${studentProvider.activeCount}',
                      color: themeProvider.currentPrimary,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.archive_rounded,
                      label: 'Archived',
                      value: '${studentProvider.archivedStudents.length}',
                      color: AppTheme.textMuted,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.groups_rounded,
                      label: 'Total',
                      value: '${studentProvider.students.length}',
                      color: AppTheme.accentTeal,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),

              // ─── Archived Students ─────────────────────
              if (studentProvider.archivedStudents.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Archived Students',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color:
                        isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ...studentProvider.archivedStudents.map(
                  (student) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color:
                            isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.textPrimary,
                                ),
                              ),
                              if (student.subject.isNotEmpty)
                                Text(
                                  student.subject,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await studentProvider.restoreStudent(student.id);
                          },
                          child: Text(
                            'Restore',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: themeProvider.currentPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_forever_rounded,
                            size: 20,
                            color: AppTheme.errorRose,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Permanently?'),
                                content: Text(
                                  'This will permanently delete ${student.name} and cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: isDark
                                            ? AppTheme.darkTextMuted
                                            : AppTheme.textMuted,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      studentProvider
                                          .deleteStudent(student.id);
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.errorRose,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ─── About Card ───────────────────────────
              Text(
                'About',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                  ),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: Column(
                  children: [
                    _AboutRow(
                      label: 'App',
                      value: AppConstants.appName,
                      isDark: isDark,
                    ),
                    Divider(
                      height: 20,
                      color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                    ),
                    _AboutRow(
                      label: 'Version',
                      value: AppConstants.appVersion,
                      isDark: isDark,
                    ),
                    Divider(
                      height: 20,
                      color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                    ),
                    _AboutRow(
                      label: 'Developer',
                      value: AppConstants.appDeveloper,
                      isDark: isDark,
                      accentColor: themeProvider.currentPrimary,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ─── Logout Button ─────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Logout?'),
                        content: const Text(
                          'Are you sure you want to sign out?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: isDark
                                    ? AppTheme.darkTextMuted
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await authProvider.logout();
                              if (context.mounted) {
                                Navigator.of(context)
                                    .pushNamedAndRemoveUntil(
                                  Routes.login,
                                  (route) => false,
                                );
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.errorRose,
                            ),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRose,
                    side: const BorderSide(color: AppTheme.errorRose),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ─── Footer Attribution ────────────────────
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: themeProvider.currentPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Developed by ${AppConstants.appDeveloper}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white70
                            : AppTheme.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dynamic Theme Mode Segment Option
class _ThemeModeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final bool isDark;
  final VoidCallback onTap;

  const _ThemeModeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? activeColor.withOpacity(0.25) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: isSelected && !isDark
                ? Border.all(color: activeColor.withOpacity(0.3), width: 1)
                : (isSelected && isDark
                    ? Border.all(color: activeColor.withOpacity(0.5), width: 1)
                    : null),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.white60 : AppTheme.textMuted),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? activeColor
                      : (isDark ? Colors.white70 : AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular Color Swatch with Gradient and Checkmark
class _ColorSwatch extends StatelessWidget {
  final AccentColorPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: preset.name,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? preset.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
          padding: const EdgeInsets.all(3),
          child: Container(
            decoration: BoxDecoration(
              gradient: preset.gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: preset.primary.withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: isSelected
                ? const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 24,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color? accentColor;

  const _AboutRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark ? Colors.white60 : AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: accentColor ??
                (isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}
