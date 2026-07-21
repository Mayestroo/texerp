import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/features/payroll/presentation/payroll_bloc.dart';

class WorkerPayrollScreen extends StatefulWidget {
  const WorkerPayrollScreen({super.key});

  @override
  State<WorkerPayrollScreen> createState() => _WorkerPayrollScreenState();
}

class _WorkerPayrollScreenState extends State<WorkerPayrollScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PayrollBloc>().add(const PayrollMyPayrollRequested());
  }

  String _formatMoney(int amount) {
    return NumberFormat('#,###').format(amount);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'FINALIZED':
        return 'Yakunlangan';
      default:
        return status;
    }
  }

  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.labelDark : AppColors.labelLight;
    final secondaryColor = isDark ? AppColors.secondaryLabelDark : AppColors.secondaryLabelLight;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return BlocBuilder<PayrollBloc, PayrollState>(
      builder: (context, state) {
        if (state.isLoading && state.myPayroll.isEmpty) {
          return const Center(child: CupertinoActivityIndicator());
        }

        if (state.myPayroll.isEmpty) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  context.read<PayrollBloc>().add(const PayrollMyPayrollRequested());
                },
              ),
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.doc_text,
                        size: 56,
                        color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Hali yakunlangan maosh davri yo\'q',
                        style: TextStyle(
                          color: secondaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          inherit: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Yangi maosh davrlari hisoblanganda shu yerda ko\'rinadi.',
                        style: TextStyle(
                          color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                          fontSize: 13,
                          inherit: true,
                        ),
                      ),
                    ],
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
                context.read<PayrollBloc>().add(const PayrollMyPayrollRequested());
              },
            ),
            SliverPadding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final period = state.myPayroll[index];
                    return GestureDetector(
                      onTap: () {
                        _showPeriodDetailBottomSheet(context, period);
                      },
                      child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Left Icon
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                CupertinoIcons.calendar_today,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Middle Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    period.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                      inherit: true,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${period.startDate} ~ ${period.endDate}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: secondaryColor,
                                      inherit: true,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.success.withOpacity(0.15)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(CupertinoIcons.checkmark_seal_fill, size: 12, color: AppColors.success),
                                        const SizedBox(width: 4),
                                        Text(
                                          _statusLabel(period.status),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.success,
                                            inherit: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Right Money
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.success.withOpacity(0.15)),
                              ),
                              child: Text(
                                '${_formatMoney(period.totalFinal)} UZS',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                  inherit: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ),
                    );
                  },
                  childCount: state.myPayroll.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPeriodDetailBottomSheet(BuildContext context, dynamic period) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.48,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFC7C7CC),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      period.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.labelDark : AppColors.labelLight,
                        inherit: true,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        _statusLabel(period.status),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                          inherit: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Sana oralig\'i: ${period.startDate} - ${period.endDate}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                    inherit: true,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : AppColors.cardLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hisoblangan maosh summasi:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.labelDark : AppColors.labelLight,
                          inherit: true,
                        ),
                      ),
                      Text(
                        '${_formatMoney(period.totalFinal)} UZS',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success,
                          inherit: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/worker/payroll/${period.id}');
                  },
                  child: Container(
                    height: 50,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Batafsil ko\'rish',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
