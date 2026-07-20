import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
                    return Container(
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
}
