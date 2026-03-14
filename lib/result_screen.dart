import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.hallNumber,
    required this.buildingName,
    required this.floor,
    required this.side,
    required this.examDate,
    required this.startTime,
    required this.endTime,
    required this.collegeName,
    this.isStaff = false,
  });

  final String hallNumber;
  final String buildingName;
  final String floor;
  final String side;
  final DateTime examDate;
  final DateTime startTime;
  final DateTime endTime;
  final String collegeName;
  final bool isStaff;

  String get _dateLabel => DateFormat('dd/MM/yyyy').format(examDate);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Your Allocation'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 22,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primary.withOpacity(0.9),
                              primary.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 12,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              collegeName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white60,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isStaff ? 'YOUR ROOM ALLOCATION' : 'YOUR EXAM HALL',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white70,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              hallNumber.isNotEmpty ? hallNumber : 'N/A',
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                fontSize: 52,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Details',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _InfoTile(
                            icon: Icons.business,
                            label: 'Building',
                            value: buildingName,
                          ),
                          _InfoTile(
                            icon: Icons.layers,
                            label: 'Floor',
                            value: floor,
                          ),
                          _InfoTile(
                            icon: Icons.navigation,
                            label: 'Side',
                            value: side,
                          ),
                          _InfoTile(
                            icon: Icons.event,
                            label: 'Date',
                            value: _dateLabel,
                            centerValue: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: BorderSide(
                        color: primary.withOpacity(0.7),
                        width: 1.6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Search'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isStaff
                              ? 'Please report to the assigned hall before time.'
                              : 'Please reach the hall 15 minutes before the exam starts.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.centerValue = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool centerValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: (MediaQuery.of(context).size.width - 20 * 2 - 12) / 2,
      constraints: const BoxConstraints(minHeight: 82),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: theme.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  softWrap: true,
                  textAlign: centerValue ? TextAlign.center : TextAlign.left,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
