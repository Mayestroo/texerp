import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/features/production/presentation/production_bloc.dart';

class EntryHistoryScreen extends StatefulWidget {
  const EntryHistoryScreen({super.key});

  @override
  State<EntryHistoryScreen> createState() => _EntryHistoryScreenState();
}

class _EntryHistoryScreenState extends State<EntryHistoryScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ProductionBloc>().add(const ProductionLoadHistoryRequested());
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

  Widget _buildStatusBadge(String status, bool isDark) {
    final color = _getStatusColor(status);
    final text = _getStatusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          inherit: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ProductionBloc, ProductionState>(
      builder: (context, state) {
        if (state.historyLoading && state.history.isEmpty) {
          return const Center(
            child: CupertinoActivityIndicator(),
          );
        }

        if (state.historyError != null && state.history.isEmpty) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  context.read<ProductionBloc>().add(const ProductionLoadHistoryRequested(refresh: true));
                },
              ),
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_triangle_fill,
                          color: AppColors.error,
                          size: 44,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tarixni yuklashda xatolik',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.labelDark : AppColors.labelLight,
                            inherit: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.historyError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                            inherit: true,
                          ),
                        ),
                        const SizedBox(height: 20),
                        CupertinoButton(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () {
                            context.read<ProductionBloc>().add(const ProductionLoadHistoryRequested(refresh: true));
                          },
                          child: const Text('Qaytadan urinish'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        if (state.history.isEmpty) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  context.read<ProductionBloc>().add(const ProductionLoadHistoryRequested(refresh: true));
                },
              ),
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.square_list,
                          size: 64,
                          color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Hali hech qanday ish kiritilmagan',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.labelDark : AppColors.labelLight,
                            inherit: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Kiritish sahifasidan birinchi ishingizni yozib qoldiring.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                            inherit: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                context.read<ProductionBloc>().add(const ProductionLoadHistoryRequested(refresh: true));
              },
            ),
            SliverPadding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = state.history[index];
                    final earning = entry.quantitySubmitted * entry.unitPriceSnapshot;
                    final initials = entry.operationNameSnapshot
                        .split(' ')
                        .map((e) => e.isNotEmpty ? e[0] : '')
                        .take(2)
                        .join()
                        .toUpperCase();
                    final primaryColor = CupertinoTheme.of(context).primaryColor;

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
                              // Initials avatar
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  initials.isNotEmpty ? initials : "?",
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
                              _buildStatusBadge(entry.status, isDark),
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
                                      'Taxminiy daromad',
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
                          if (entry.workerNote != null && entry.workerNote!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  CupertinoIcons.text_bubble,
                                  size: 13,
                                  color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                ),
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
                                  Icon(
                                    CupertinoIcons.info_circle,
                                    size: 14,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Rad etilish sababi: ${entry.rejectionReason}',
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
                  childCount: state.history.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
