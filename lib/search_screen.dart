import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'result_screen.dart';
import 'supabase_client.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    return newValue.copyWith(
      text: upper,
      selection: TextSelection.collapsed(offset: upper.length),
      composing: TextRange.empty,
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialOrgCode});

  final String? initialOrgCode;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _orgCodeController = TextEditingController();
  final TextEditingController _registerController = TextEditingController();

  bool _loading = false;
  bool _isStaff = false;

  @override
  void initState() {
    super.initState();
    _prefillOrgCode();
  }

  @override
  void dispose() {
    _orgCodeController.dispose();
    _registerController.dispose();
    super.dispose();
  }

  Future<void> _prefillOrgCode() async {
    // Use provided initial code when coming from splash; otherwise fall back to prefs.
    final provided = widget.initialOrgCode;
    if (provided != null && provided.isNotEmpty) {
      _orgCodeController.text = provided;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('org_code');
    if (saved != null && saved.isNotEmpty) {
      _orgCodeController.text = saved;
    }
  }

  Future<void> _onSearch() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final orgCode = _orgCodeController.text.trim().toUpperCase();
    final regNo = _registerController.text.trim().toUpperCase();
    await prefs.setString('org_code', orgCode);

    try {
      final allocation = await _fetchAllocation(orgCode, regNo);
      if (allocation == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No allocation found for this ID/College.'),
          ),
        );
        return;
      }

      final now = DateTime.now();
      final examDate = _parseDate(allocation['exam_date']);
      final startTime = _combineDateAndTime(examDate, allocation['start_time']);
      final endTime = _combineDateAndTime(examDate, allocation['end_time']);

      // Only enforce timing details for students
      if (!_isStaff) {
        if (startTime == null || endTime == null || examDate == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to read exam timing details.')),
          );
          return;
        }

        if (now.isBefore(startTime)) {
          final formatted = DateFormat('MMM d, h:mm a').format(startTime);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Allocation will be visible at $formatted.')),
          );
          return;
        }

        if (now.isAfter(endTime)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Allocation viewing period has expired.'),
            ),
          );
          return;
        }
      }

      if (!mounted) return;
      
      // If staff mode, we might not have building, floor, side, start_time, end_time
      // and we shouldn't fail validation if they are missing for staff.
      // However, the current screen expects them. Let's provide defaults if missing.
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            hallNumber: allocation['hall_no']?.toString() ?? 'N/A',
            buildingName: allocation['building']?.toString() ??
                (allocation['college_name']?.toString() ?? 'N/A'),
            floor: allocation['floor']?.toString() ?? '—',
            side: allocation['side']?.toString() ?? '—',
            examDate: examDate ?? DateTime.now(),
            startTime: startTime ?? DateTime.now(),
            endTime: endTime ?? DateTime.now().add(const Duration(hours: 1)),
            collegeName: allocation['college_name']?.toString() ?? '',
            isStaff: _isStaff,
          ),
        ),
      );
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116' || e.message.contains('Row not found')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No allocation found for this ID/College.'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching allocation: ${e.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchAllocation(
    String orgCode,
    String registerNumber,
  ) async {
    print('Querying for ${_isStaff ? 'Staff' : 'Student'}: org_code=$orgCode, register_number=$registerNumber');

    if (_isStaff) {
      // For staff, first get the allocation and organization details
      final allocationResponse = await supabase
          .from('staff_allocations')
          .select('*, organizations!inner(org_code, name)')
          .ilike('organizations.org_code', orgCode)
          .ilike('reg_no', registerNumber)
          .limit(1)
          .maybeSingle();

      if (allocationResponse == null) return null;

      final Map<String, dynamic> flatData = Map<String, dynamic>.from(allocationResponse);
      final orgId = flatData['organization_id'];
      final hallNo = flatData['hall_no'];

      // Then fetch the path details (building, floor, side) from the halls table
      if (orgId != null && hallNo != null) {
        final hallDetails = await supabase
            .from('halls')
            .select('building, floor, side')
            .eq('organization_id', orgId)
            .eq('hall_no', hallNo)
            .maybeSingle();

        if (hallDetails != null) {
          flatData['building'] = hallDetails['building'];
          flatData['floor'] = hallDetails['floor'];
          flatData['side'] = hallDetails['side'];
        }
      }

      final orgData = flatData['organizations'] as Map<String, dynamic>?;
      if (orgData != null) {
        flatData['college_name'] = orgData['name'];
        flatData['org_code'] = orgData['org_code'];
      }
      return flatData;
    } else {
      final response = await supabase
          .from('student_exam_details_view')
          .select()
          .ilike('org_code', orgCode)
          .ilike('register_number', registerNumber)
          .limit(1)
          .maybeSingle();

      return response;
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      if (value is DateTime) return value.toLocal();
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  DateTime? _combineDateAndTime(DateTime? date, dynamic timeValue) {
    if (date == null || timeValue == null) return null;
    final timeString = timeValue.toString();
    final trimmed = timeString
        .split('.')
        .first; // drop fractional seconds if any

    final datePart = DateFormat('yyyy-MM-dd').format(date);

    // Try common formats: HH:mm:ss, HH:mm with space or T separator
    const patterns = [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-ddTHH:mm:ss',
      'yyyy-MM-ddTHH:mm',
    ];

    for (final pattern in patterns) {
      try {
        final separator = pattern.contains('T') ? 'T' : ' ';
        final fmt = DateFormat(pattern);
        final dt = fmt.parse('$datePart$separator$trimmed');
        return dt.toLocal();
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, color: Colors.blue.shade600) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade700, width: 1.6),
      ),
      filled: true,
      fillColor: Colors.blue.shade50.withOpacity(0.25),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Hall Locator')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Stack(
              children: [
                Positioned(
                  top: -60,
                  right: -60,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.blue.shade100.withOpacity(0.45),
                          Colors.blue.shade100.withOpacity(0.1),
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      'Welcome ${_isStaff ? 'Staff' : 'Student'}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enter your details to find your ${_isStaff ? 'hall' : 'exam hall'}.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primary,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 10,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isStaff ? Icons.work : Icons.school,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _RoleToggle(
                            isStaff: _isStaff,
                            onChanged: (val) => setState(() => _isStaff = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      margin: EdgeInsets.zero,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Enter your details',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _orgCodeController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: _inputDecoration(
                                  'Organization Code',
                                  hint: 'e.g., MEC001',
                                  icon: Icons.school_outlined,
                                ),
                                inputFormatters: [UpperCaseTextFormatter()],
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your Organization Code';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _registerController,
                                decoration: _inputDecoration(
                                  'Register Number',
                                  hint: 'e.g., 21CS123',
                                  icon: Icons.badge_outlined,
                                ),
                                textInputAction: TextInputAction.done,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your Register Number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 22),
                              _GradientButton(
                                onPressed: _loading ? null : _onSearch,
                                loading: _loading,
                                isStaff: _isStaff,
                                primary: primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.onPressed,
    required this.loading,
    required this.isStaff,
    required this.primary,
  });

  final VoidCallback? onPressed;
  final bool loading;
  final bool isStaff;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                isStaff ? 'Find My Room' : 'Find My Hall',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}

class _RoleToggle extends StatelessWidget {
  const _RoleToggle({required this.isStaff, required this.onChanged});

  final bool isStaff;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Container(
      width: 240,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutExpo,
            alignment: isStaff ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 120,
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(false),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        color: isStaff ? Colors.grey.shade600 : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      child: const Text('Student'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(true),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        color: isStaff ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      child: const Text('Staff'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
