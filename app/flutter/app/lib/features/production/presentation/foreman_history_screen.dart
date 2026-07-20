import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/features/production/data/production_repository.dart';
import 'package:texerp/features/production/data/production_models.dart';

class ForemanHistoryScreen extends StatefulWidget {
  const ForemanHistoryScreen({super.key});

  @override
  State<ForemanHistoryScreen> createState() => _ForemanHistoryScreenState();
}

class _ForemanHistoryScreenState extends State<ForemanHistoryScreen> {
  int _selectedSegment = 0;
  bool _isLoading = true;
  String? _error;
  List<ProductionEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final statuses = ['APPROVED', 'REJECTED', 'PENDING'];
      final status = statuses[_selectedSegment];

      final repo = context.read<ProductionRepository>();
      final (entries, _) = await repo.fetchForemanHistory(
        status: status,
        limit: 100,
      );

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return AppColors.success;
      case 'REJECTED':
        return AppColors.error;
      case 'PENDING':
      default:
        return AppColors.warning;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'APPROVED':
        return 'Tasdiqlandi';
      case 'REJECTED':
        return 'Rad etildi';
      case 'PENDING':
      default:
        return 'Kutilmoqda';
    }
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    if (DateFormat('yyyyMMdd').format(dateTime) == DateFormat('yyyyMMdd').format(now)) {
      return 'Bugun, ${DateFormat('HH:mm').format(dateTime)}';
    } else if (DateFormat('yyyyMMdd').format(dateTime) == DateFormat('yyyyMMdd').format(yesterday)) {
      return 'Kecha, ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('dd.MM.yyyy, HH:mm').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return CupertinoPageScaffold(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _selectedSegment,
                  onValueChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedSegment = value);
                    _loadEntries();
                  },
                  children: const {
                    0: Text('Tasdiqlangan'),
                    1: Text('Rad etilgan'),
                    2: Text('Kutilayotgan'),
                  },
                ),
              ),
            ),
            Expanded(
              child: _buildBody(isDark, primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark, Color primaryColor) {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                  color: AppColors.error, size: 44),
              const SizedBox(height: 16),
              CupertinoButton(
                color: primaryColor,
                onPressed: _loadEntries,
                child: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.square_list,
                size: 64,
                color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight),
            const SizedBox(height: 16),
            Text(
              'Hech qanday yozuv yo\'q',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.labelDark : AppColors.labelLight,
                inherit: true,
              ),
            ),
          ],
        ),
      );
    }

    return CupertinoScrollbar(
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: _loadEntries),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = _entries[index];
                  final earning = entry.quantitySubmitted * entry.unitPriceSnapshot;
                  final initials = entry.operationNameSnapshot
                      .split(' ')
                      .map((e) => e.isNotEmpty ? e[0] : '')
                      .take(2)
                      .join()
                      .toUpperCase();
                  final statusColor = _getStatusColor(entry.status);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : AppColors.cardLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withOpacity(isDark ? 0.2 : 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials.isNotEmpty ? initials : '?',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  inherit: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.operationNameSnapshot,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                      inherit: true,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatDate(entry.submittedAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                                      inherit: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: statusColor.withOpacity(0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                _getStatusText(entry.status),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  inherit: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hajmi',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                                      inherit: true,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${entry.quantitySubmitted.toInt()} dona',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                      inherit: true,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Daromad',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                                      inherit: true,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${NumberFormat.decimalPattern().format(earning)} UZS',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                      inherit: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (entry.worker != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(CupertinoIcons.person_solid,
                                  size: 13,
                                  color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight),
                              const SizedBox(width: 6),
                              Text(
                                entry.worker!.fullName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                  fontWeight: FontWeight.w600,
                                  inherit: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (entry.workerNote != null && entry.workerNote!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(CupertinoIcons.text_bubble,
                                  size: 13,
                                  color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  entry.workerNote!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                    fontStyle: FontStyle.italic,
                                    inherit: true,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (entry.status == 'REJECTED' && entry.rejectionReason != null && entry.rejectionReason!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.error.withOpacity(0.15)),
                            ),
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.info_circle, size: 14, color: AppColors.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Sabab: ${entry.rejectionReason}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w600,
                                      inherit: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
                childCount: _entries.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
