import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/student_provider.dart';
import '../models/student_model.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/whatsapp_icon.dart';

/// Add or Edit student profile screen with BD localization & academic hierarchy
class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({super.key});

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _studentPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _targetController = TextEditingController(text: '12');
  final _feeController = TextEditingController(text: '0');
  final _newSubjectController = TextEditingController();

  // Academic Dropdowns
  String _selectedGrade = 'Class 10';
  String _selectedSubjectGroup = 'General';
  List<String> _subjects = [];

  // Weekly Schedule: Sat, Sun, Mon, Tue, Wed, Thu, Fri
  final List<String> _allDays = [
    'Sat',
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
  ];
  final Set<String> _selectedDays = {'Sun', 'Tue', 'Thu'};

  // Grade Options
  final List<String> _gradeOptions = [
    'Class 1',
    'Class 2',
    'Class 3',
    'Class 4',
    'Class 5',
    'Class 6',
    'Class 7',
    'Class 8',
    'Class 9',
    'Class 10',
    'Inter 1st Year (HSC 1st)',
    'Inter 2nd Year (HSC 2nd)',
    'Other',
  ];

  // Subject Group Options
  final List<String> _groupOptions = [
    'General',
    'Science',
    'Commerce',
    'Arts / Humanities',
  ];

  bool _isEditing = false;
  StudentModel? _existingStudent;
  String _probableTime = ''; // 24h format e.g. "16:30"
  bool _carryForwardExtraClasses = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is StudentModel && !_isEditing) {
      _isEditing = true;
      _existingStudent = args;
      _nameController.text = args.name;
      _guardianPhoneController.text = args.contactNumber;
      _studentPhoneController.text = args.studentContactNumber;
      _addressController.text = args.address;
      _targetController.text = args.monthlyTargetClasses.toString();
      _feeController.text = args.monthlyFee.toStringAsFixed(0);
      _carryForwardExtraClasses = args.carryForwardExtraClasses;

      // Restore Grade
      if (_gradeOptions.contains(args.grade)) {
        _selectedGrade = args.grade;
      } else if (args.grade.isNotEmpty) {
        _selectedGrade = 'Other';
      }

      // Restore Subject Group
      if (_groupOptions.contains(args.subjectGroup)) {
        _selectedSubjectGroup = args.subjectGroup;
      }

      // Restore Subjects (clean of group name to prevent duplication)
      _subjects = List.from(args.cleanSubjects);
      _subjects.removeWhere((s) =>
          s.trim().toLowerCase() == _selectedSubjectGroup.trim().toLowerCase());

      // Restore Weekly Schedule
      _selectedDays.clear();
      _selectedDays.addAll(args.weeklySchedule);

      // Restore Probable Time
      _probableTime = args.probableTime;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _guardianPhoneController.dispose();
    _studentPhoneController.dispose();
    _addressController.dispose();
    _targetController.dispose();
    _feeController.dispose();
    _newSubjectController.dispose();
    super.dispose();
  }

  List<String> _getPresetSubjects(String group) {
    switch (group.toLowerCase()) {
      case 'science':
        return ['Physics', 'Chemistry', 'Higher Math', 'Biology', 'ICT'];
      case 'commerce':
        return ['Accounting', 'Finance', 'Management', 'Economics', 'ICT'];
      case 'arts / humanities':
        return ['Economics', 'Civics', 'History', 'Logic', 'Geography', 'ICT'];
      default:
        return ['General Math', 'English', 'Bangla', 'General Science', 'ICT'];
    }
  }

  void _addSubject([String? customText]) {
    final text = (customText ?? _newSubjectController.text).trim();
    if (text.isEmpty) return;

    if (text.toLowerCase() == _selectedSubjectGroup.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"$text" is the Main Subject Group selected above. Please choose specific subjects like Physics, Math, etc.',
          ),
          backgroundColor: AppTheme.warningAmber,
          duration: const Duration(seconds: 3),
        ),
      );
      if (customText == null) _newSubjectController.clear();
      return;
    }

    if (!_subjects.any((s) => s.toLowerCase() == text.toLowerCase())) {
      setState(() {
        _subjects.add(text);
        if (customText == null) _newSubjectController.clear();
      });
    }
  }

  void _removeSubject(String subject) {
    setState(() {
      _subjects.remove(subject);
    });
  }

  String _formatTime24to12(String time24) {
    if (time24.isEmpty) return '';
    try {
      final parts = time24.split(':');
      final hour = int.parse(parts[0].trim());
      final minute = int.parse(parts[1].trim());
      final period = hour >= 12 ? 'PM' : 'AM';
      final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final mStr = minute.toString().padLeft(2, '0');
      final hStr = h12.toString().padLeft(2, '0');
      return '$hStr:$mStr $period';
    } catch (_) {
      return time24;
    }
  }

  Future<void> _pickProbableTime() async {
    TimeOfDay initial = const TimeOfDay(hour: 16, minute: 30);
    if (_probableTime.isNotEmpty) {
      try {
        final parts = _probableTime.split(':');
        initial = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      } catch (_) {}
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return child!;
      },
    );

    if (picked != null) {
      final hStr = picked.hour.toString().padLeft(2, '0');
      final mStr = picked.minute.toString().padLeft(2, '0');
      setState(() {
        _probableTime = '$hStr:$mStr';
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final studentProvider = context.read<StudentProvider>();

    final cleanSubjects = _subjects
        .where((s) =>
            s.trim().toLowerCase() != _selectedSubjectGroup.trim().toLowerCase())
        .toList();

    final data = {
      'name': _nameController.text.trim(),
      'grade': _selectedGrade,
      'subjectGroup': _selectedSubjectGroup,
      'subjects': cleanSubjects,
      'subject': cleanSubjects.join(', '),
      'contactNumber': AppFormatters.cleanBdPhone(_guardianPhoneController.text),
      'studentContactNumber': _studentPhoneController.text.trim().isNotEmpty
          ? AppFormatters.cleanBdPhone(_studentPhoneController.text)
          : '',
      'address': _addressController.text.trim(),
      'monthlyTargetClasses': int.tryParse(_targetController.text) ?? 12,
      'monthlyFee': double.tryParse(_feeController.text) ?? 0,
      'weeklySchedule': _selectedDays.toList(),
      'probableTime': _probableTime,
      'carryForwardExtraClasses': _carryForwardExtraClasses,
    };

    bool success;
    if (_existingStudent != null) {
      success = await studentProvider.updateStudent(_existingStudent!.id, data);
    } else {
      success = await studentProvider.addStudent(data);
    }

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _existingStudent != null
                  ? 'Student updated successfully'
                  : 'Student added successfully',
            ),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.pop(context, true);
      } else if (studentProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(studentProvider.errorMessage!),
            backgroundColor: AppTheme.errorRose,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = context.watch<StudentProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
      appBar: AppBar(
        title: Text(_existingStudent != null ? 'Edit Student' : 'Add Student'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: LoadingOverlay(
        isLoading: studentProvider.isLoading,
        message: 'Saving...',
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Personal Info ──────────────────────
                const _SectionHeader(
                  icon: Icons.person_outline_rounded,
                  title: 'Student Information',
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _nameController,
                  label: 'Student Name *',
                  hint: 'e.g., Tahmid Rahman',
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Student name is required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),
                // ─── Academic Hierarchy ─────────────────
                const _SectionHeader(
                  icon: Icons.school_outlined,
                  title: 'Academic Hierarchy',
                ),
                const SizedBox(height: 12),

                // Grade / Class Structured Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedGrade,
                  dropdownColor: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
                  decoration: InputDecoration(
                    labelText: 'Grade / Class *',
                    prefixIcon: Icon(
                      Icons.class_rounded,
                      color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                      size: 20,
                    ),
                  ),
                  items: _gradeOptions
                      .map(
                        (grade) => DropdownMenuItem(
                          value: grade,
                          child: Text(
                            grade,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedGrade = val);
                  },
                ),
                const SizedBox(height: 14),

                // Main Subject Group Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedSubjectGroup,
                  dropdownColor: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
                  decoration: InputDecoration(
                    labelText: 'Main Subject Group *',
                    prefixIcon: Icon(
                      Icons.category_rounded,
                      color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                      size: 20,
                    ),
                  ),
                  items: _groupOptions
                      .map(
                        (group) => DropdownMenuItem(
                          value: group,
                          child: Text(
                            group,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedSubjectGroup = val;
                        // Automatically remove any subject that matches the newly selected group
                        _subjects.removeWhere((s) =>
                            s.trim().toLowerCase() == val.trim().toLowerCase());
                      });
                    }
                  },
                ),
                const SizedBox(height: 18),

                // Specific Subjects Section (Explicitly separated from Group)
                Row(
                  children: [
                    Text(
                      'Specific Subjects Taught',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(e.g. Physics, Higher Math)',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newSubjectController,
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type subject (e.g., Higher Math)',
                          prefixIcon: Icon(
                            Icons.menu_book_rounded,
                            color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                            size: 20,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addSubject(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _addSubject(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),

                // Quick Presets based on selected group
                Builder(
                  builder: (context) {
                    final presets = _getPresetSubjects(_selectedSubjectGroup);
                    final availablePresets = presets
                        .where((p) => !_subjects.any(
                            (s) => s.toLowerCase() == p.toLowerCase()))
                        .toList();

                    if (availablePresets.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 12,
                                color: AppTheme.accentTealDark,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Quick-add for $_selectedSubjectGroup:',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppTheme.darkTextMuted
                                      : AppTheme.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: availablePresets.map((preset) {
                              return ActionChip(
                                avatar: Icon(
                                  Icons.add,
                                  size: 13,
                                  color: primaryColor,
                                ),
                                label: Text(
                                  preset,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                backgroundColor:
                                    primaryColor.withOpacity(isDark ? 0.18 : 0.08),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusFull),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                onPressed: () => _addSubject(preset),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Selected Subject Chips
                if (_subjects.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _subjects
                        .map(
                          (sub) => Chip(
                            label: Text(
                              sub,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: primaryColor,
                              ),
                            ),
                            backgroundColor:
                                primaryColor.withOpacity(isDark ? 0.18 : 0.08),
                            side: BorderSide.none,
                            deleteIcon: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: primaryColor,
                            ),
                            onDeleted: () => _removeSubject(sub),
                          ),
                        )
                        .toList(),
                  ),
                ],

                const SizedBox(height: 24),
                // ─── Weekly Schedule / Probable Days ────
                const _SectionHeader(
                  icon: Icons.calendar_month_outlined,
                  title: 'Weekly Schedule / Probable Days',
                ),
                const SizedBox(height: 10),
                Text(
                  'Select the target days for regular tution sessions:',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allDays.map((day) {
                    final isSelected = _selectedDays.contains(day);
                    return ChoiceChip(
                      label: Text(
                        day,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: primaryColor,
                      backgroundColor:
                          isDark ? AppTheme.darkCard : AppTheme.surfaceLight,
                      side: BorderSide(
                        color: isSelected
                            ? primaryColor
                            : (isDark
                                ? AppTheme.darkBorder
                                : AppTheme.borderLight),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedDays.add(day);
                          } else {
                            _selectedDays.remove(day);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                // ─── Probable Class Time Picker Tile ─────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: _probableTime.isNotEmpty
                          ? primaryColor.withOpacity(0.5)
                          : (isDark ? AppTheme.darkBorder : AppTheme.borderLight),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _probableTime.isNotEmpty
                              ? primaryColor.withOpacity(0.15)
                              : (isDark ? AppTheme.darkSurface : AppTheme.surfaceLight),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.access_time_rounded,
                          color: _probableTime.isNotEmpty
                              ? primaryColor
                              : (isDark ? AppTheme.darkTextMuted : AppTheme.textMuted),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Probable Class Time',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _probableTime.isNotEmpty
                                  ? _formatTime24to12(_probableTime)
                                  : 'Select typical starting time (e.g., 04:30 PM)',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _probableTime.isNotEmpty
                                    ? primaryColor
                                    : (isDark ? AppTheme.darkTextMuted : AppTheme.textMuted),
                                fontWeight: _probableTime.isNotEmpty
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_probableTime.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                          ),
                          onPressed: () => setState(() => _probableTime = ''),
                          tooltip: 'Clear Time',
                        ),
                      OutlinedButton(
                        onPressed: _pickProbableTime,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          side: BorderSide(
                            color: _probableTime.isNotEmpty
                                ? primaryColor
                                : (isDark ? AppTheme.darkBorder : AppTheme.borderLight),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _probableTime.isNotEmpty ? 'Change' : 'Set Time',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                // ─── Bangladeshi Contact Details ────────
                const _SectionHeader(
                  icon: Icons.phone_outlined,
                  title: 'Bangladeshi Contact Details',
                ),
                const SizedBox(height: 12),

                // Guardian Phone (Mandatory with BD 11-digit validation)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _guardianPhoneController,
                        decoration: InputDecoration(
                          labelText: 'Guardian Phone (11 digits) *',
                          hintText: '01XXXXXXXXX',
                          prefixIcon: const Icon(
                            Icons.phone_outlined,
                            color: AppTheme.textMuted,
                            size: 20,
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Guardian phone is required';
                          }
                          if (!AppFormatters.isValidBdPhone(val)) {
                            return 'Enter valid 11-digit BD number (01[3-9]...)';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CallActionButtons(
                      controller: _guardianPhoneController,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Student Phone (Optional with same BD validation)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _studentPhoneController,
                        decoration: InputDecoration(
                          labelText: 'Student Phone (Optional)',
                          hintText: '01XXXXXXXXX',
                          prefixIcon: const Icon(
                            Icons.phone_android_rounded,
                            color: AppTheme.textMuted,
                            size: 20,
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        validator: (val) {
                          if (val != null &&
                              val.trim().isNotEmpty &&
                              !AppFormatters.isValidBdPhone(val)) {
                            return 'Must be valid 11-digit BD number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CallActionButtons(
                      controller: _studentPhoneController,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  controller: _addressController,
                  label: 'Address / Location',
                  hint: 'Student home or tution location',
                  prefixIcon: Icons.location_on_outlined,
                  maxLines: 2,
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 24),
                // ─── Billing in Bangladeshi Taka ─────────
                const _SectionHeader(
                  icon: Icons.receipt_long_outlined,
                  title: 'Classes & Monthly Fee (৳)',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _targetController,
                        label: 'Monthly Classes *',
                        hint: '12',
                        prefixIcon: Icons.calendar_today_rounded,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final num = int.tryParse(value);
                          if (num == null || num < 1 || num > 31) {
                            return '1-31';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: _feeController,
                        label: 'Monthly Fee (৳ BDT)',
                        hint: '0',
                        prefixIcon: Icons.payments_outlined,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleSave(),
                      ),
                    ),
                  ],
                ),

                // Quick presets for monthly target
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    _PresetChip(
                      label: '3×/week (12)',
                      onTap: () => _targetController.text = '12',
                    ),
                    _PresetChip(
                      label: '4×/week (16)',
                      onTap: () => _targetController.text = '16',
                    ),
                    _PresetChip(
                      label: '5×/week (20)',
                      onTap: () => _targetController.text = '20',
                    ),
                    _PresetChip(
                      label: '6×/week (24)',
                      onTap: () => _targetController.text = '24',
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.sync_alt_rounded,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Carry forward extra classes',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Automatically credit bonus classes exceeding monthly quota to next month',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _carryForwardExtraClasses,
                        activeColor: primaryColor,
                        onChanged: (val) {
                          setState(() {
                            _carryForwardExtraClasses = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),
                // Save button
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _handleSave,
                    icon: Icon(
                      _existingStudent != null
                          ? Icons.save_rounded
                          : Icons.add_rounded,
                      size: 20,
                    ),
                    label: Text(
                      _existingStudent != null
                          ? 'Save Changes'
                          : 'Add Student',
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Action buttons to launch phone dialer or WhatsApp directly
class _CallActionButtons extends StatelessWidget {
  final TextEditingController controller;

  const _CallActionButtons({required this.controller});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Call Phone',
          onPressed: () {
            final phone = controller.text.trim();
            if (phone.isNotEmpty) {
              AppFormatters.launchDialer(phone);
            }
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              Icons.phone_rounded,
              size: 16,
              color: primaryColor,
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Send SMS',
          onPressed: () {
            final phone = controller.text.trim();
            if (phone.isNotEmpty) {
              AppFormatters.launchSms(phone);
            }
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(
              Icons.chat_outlined,
              size: 16,
              color: Color(0xFF06B6D4),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Open WhatsApp',
          onPressed: () {
            final phone = controller.text.trim();
            if (phone.isNotEmpty) {
              AppFormatters.launchWhatsApp(phone);
            }
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withOpacity(0.14),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const WhatsAppIcon(
              size: 16,
              color: Color(0xFF25D366),
            ),
          ),
        ),
      ],
    );
  }
}

/// Section header with icon
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Icon(icon, size: 18, color: primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Quick preset chip for monthly target
class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return ActionChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: primaryColor,
        ),
      ),
      onPressed: onTap,
      backgroundColor: primaryColor.withOpacity(isDark ? 0.18 : 0.08),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
