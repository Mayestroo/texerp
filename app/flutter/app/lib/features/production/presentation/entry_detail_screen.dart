import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/features/production/data/production_models.dart';

class EntryDetailScreen extends StatelessWidget {
  const EntryDetailScreen({
    super.key,
    required this.entryId,
    this.entry,
  });

  final String entryId;
  final ProductionEntry? entry;

  String _formatDate(DateTime dateTime) {
    return DateFormat('dd.MM.yyyy, HH:mm').format(dateTime);
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

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    final item = entry;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          'Yozuv tafsilotlari',
          style: TextStyle(color: AppColors.labelPrimary),
        ),
      ),
      child: SafeArea(
        child: item == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.doc_text_search,
                        size: 56,
                        color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ID: $entryId',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.labelDark : AppColors.labelLight,
                          inherit: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ushbu yozuv haqida to\'liq ma\'lumotlar mavjud.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                          inherit: true,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : AppColors.cardLight,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withOpacity(isDark ? 0.2 : 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getStatusColor(item.status).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: _getStatusColor(item.status).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(item.status),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _getStatusText(item.status),
                                    style: TextStyle(
                                      color: _getStatusColor(item.status),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      inherit: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              item.recordDate,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                inherit: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item.operationNameSnapshot,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.labelDark : AppColors.labelLight,
                            inherit: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Yaratilgan vaqti: ${_formatDate(item.submittedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                            inherit: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Metrics Grid
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardDark : AppColors.cardLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kiritilgan hajm',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                  inherit: true,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${item.quantitySubmitted.toInt()} dona',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                  inherit: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardDark : AppColors.cardLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dona narxi',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                  inherit: true,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${NumberFormat.decimalPattern().format(item.unitPriceSnapshot)} UZS',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  inherit: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Total Calculated Value Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jami hisoblangan daromad',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                                inherit: true,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${NumberFormat.decimalPattern().format(item.quantitySubmitted * item.unitPriceSnapshot)} UZS',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.success,
                            inherit: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Worker Note or Rejection Reason
                  if (item.workerNote != null && item.workerNote!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : AppColors.cardLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(CupertinoIcons.text_bubble, size: 16, color: primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                'Ishchi izohi',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                  inherit: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.workerNote!,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                              inherit: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (item.status == 'REJECTED' && item.rejectionReason != null && item.rejectionReason!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 16, color: AppColors.error),
                              const SizedBox(width: 8),
                              Text(
                                'Rad etish sababi',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                  inherit: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.rejectionReason!,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.error,
                              inherit: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
