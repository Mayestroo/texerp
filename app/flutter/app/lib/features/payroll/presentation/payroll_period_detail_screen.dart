import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/core/widgets/app_toast.dart';
import 'package:texerp/features/payroll/data/payroll_models.dart';
import 'package:texerp/features/payroll/presentation/payroll_bloc.dart';

class PayrollPeriodDetailScreen extends StatefulWidget {
  const PayrollPeriodDetailScreen({super.key, required this.periodId});

  final String periodId;

  @override
  State<PayrollPeriodDetailScreen> createState() =>
      _PayrollPeriodDetailScreenState();
}

class _PayrollPeriodDetailScreenState
    extends State<PayrollPeriodDetailScreen> {
  @override
  void initState() {
    super.initState();
    context
        .read<PayrollBloc>()
        .add(PayrollPeriodDetailRequested(id: widget.periodId));
  }

  String _formatMoney(int amount) {
    return NumberFormat('#,###').format(amount);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'DRAFT':
        return 'Loyiha';
      case 'CALCULATING':
        return 'Hisoblanmoqda';
      case 'CALCULATED':
        return 'Hisoblangan';
      case 'FINALIZED':
        return 'Yakunlangan';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.labelDark : AppColors.labelLight;
    final secondaryColor =
        isDark ? AppColors.secondaryLabelDark : AppColors.secondaryLabelLight;

    return BlocConsumer<PayrollBloc, PayrollState>(
      listener: (context, state) {
        if (state.error != null) {
          AppToast.show(context, message: state.error!);
        }
      },
      builder: (context, state) {
        final detail = state.periodDetail;
        if (state.isLoading && detail == null) {
          return const Center(child: CupertinoActivityIndicator());
        }
        if (detail == null) {
          return const Center(child: Text('Davr topilmadi'));
        }

        final period = detail.period;

        final primaryColor = CupertinoTheme.of(context).primaryColor;
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text(period.name),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            period.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          _StatusBadge(
                            status: period.status,
                            label: _statusLabel(period.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.calendar,
                            size: 13,
                            color: secondaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${period.startDate} ~ ${period.endDate}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: secondaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: CupertinoIcons.person_3,
                              label: 'Ishchilar',
                              value: '${period.workerCount} ta',
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatCard(
                              icon: CupertinoIcons.money_dollar,
                              label: 'Yalpi maosh',
                              value: '${_formatMoney(period.totalGross)}',
                              color: CupertinoColors.systemOrange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatCard(
                              icon: CupertinoIcons.checkmark_seal,
                              label: 'Yakuniy',
                              value: '${_formatMoney(period.totalFinal)}',
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Ishchi hisob-kitoblari',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                if (detail.calculations.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Hisob-kitob ma\'lumotlari mavjud emas',
                        style: TextStyle(color: secondaryColor),
                      ),
                    ),
                  )
                else
                  ...detail.calculations.map((calc) =>
                      _CalculationCard(calc: calc, periodId: widget.periodId)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.labelDark : AppColors.labelLight,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? AppColors.secondaryLabelDark
                : AppColors.secondaryLabelLight,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'DRAFT':
        color = CupertinoColors.systemGrey;
      case 'CALCULATING':
        color = CupertinoColors.systemOrange;
      case 'CALCULATED':
        color = CupertinoColors.systemBlue;
      case 'FINALIZED':
        color = CupertinoColors.systemGreen;
      default:
        color = CupertinoColors.systemGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _CalculationCard extends StatelessWidget {
  const _CalculationCard({
    required this.calc,
    required this.periodId,
  });

  final PayrollCalculation calc;
  final String periodId;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final initials = calc.workerFullName
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();

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
      child: CupertinoButton(
        padding: const EdgeInsets.all(14),
        pressedOpacity: 0.8,
        onPressed: () {
          Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => BlocProvider.value(
                value: context.read<PayrollBloc>(),
                child: _WorkerCalculationScreen(
                  periodId: periodId,
                  workerId: calc.workerId,
                ),
              ),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials.isNotEmpty ? initials : '?',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    calc.workerFullName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.labelDark : AppColors.labelLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _InfoChip(
                        label: '${calc.totalPieces} dona',
                        isHighlighted: false,
                      ),
                      if (calc.hasAdjustments) ...[
                        const SizedBox(width: 6),
                        _InfoChip(
                          label: 'Tuzatma bor',
                          isHighlighted: true,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${NumberFormat.decimalPattern().format(calc.finalPay)} UZS',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.isHighlighted,
  });

  final String label;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isHighlighted
            ? primaryColor.withOpacity(0.08)
            : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted
              ? primaryColor.withOpacity(0.15)
              : (isDark ? const Color(0x11FFFFFF) : const Color(0x11000000)),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isHighlighted
              ? primaryColor
              : (isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight),
        ),
      ),
    );
  }
}

class _WorkerCalculationScreen extends StatefulWidget {
  const _WorkerCalculationScreen({
    required this.periodId,
    required this.workerId,
  });

  final String periodId;
  final String workerId;

  @override
  State<_WorkerCalculationScreen> createState() =>
      _WorkerCalculationScreenState();
}

class _WorkerCalculationScreenState extends State<_WorkerCalculationScreen> {
  @override
  void initState() {
    super.initState();
    context.read<PayrollBloc>().add(
          PayrollWorkerCalculationRequested(
            periodId: widget.periodId,
            workerId: widget.workerId,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.labelDark : AppColors.labelLight;
    final secondaryColor =
        isDark ? AppColors.secondaryLabelDark : AppColors.secondaryLabelLight;

    return BlocBuilder<PayrollBloc, PayrollState>(
      builder: (context, state) {
        if (state.workerCalculation == null && state.isLoading) {
          return const CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(middle: Text('Yuklanmoqda')),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        final calc = state.workerCalculation;
        if (calc == null) {
          return const CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(middle: Text('Xatolik')),
            child: Center(child: Text('Ma\'lumot topilmadi')),
          );
        }

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text(calc.workerFullName),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Operatsiyalar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                ...calc.operationsBreakdown.map((op) => Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 8),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  op.operationName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${op.quantity} dona × ${NumberFormat.decimalPattern().format(op.unitPrice)} UZS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: secondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${NumberFormat.decimalPattern().format(op.earnings)} UZS',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 20),
                if (calc.adjustments.isNotEmpty) ...[
                  Text(
                    'Tuzatmalar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...calc.adjustments.map((adj) {
                    final isBonus = adj.type == 'BONUS';
                    final badgeColor = isBonus ? AppColors.success : AppColors.error;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 8),
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: badgeColor.withOpacity(0.15)),
                                  ),
                                  child: Text(
                                    isBonus ? 'Bonus' : 'Chegirma',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: badgeColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  adj.reason,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: secondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${isBonus ? '+' : '-'}${NumberFormat.decimalPattern().format(adj.amount)} UZS',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],
                Text(
                  'Umumiy maosh balansi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
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
                    children: [
                      _SummaryRow(
                        label: 'Yalpi daromad',
                        value: calc.grossEarnings,
                        color: textColor,
                      ),
                      _SummaryRow(
                        label: 'Bonuslar',
                        value: calc.totalBonuses,
                        color: AppColors.success,
                      ),
                      _SummaryRow(
                        label: 'Chegirmalar',
                        value: calc.totalDeductions,
                        color: AppColors.error,
                      ),
                      _SummaryRow(
                        label: 'Avanslar',
                        value: calc.totalAdvances,
                        color: CupertinoColors.systemOrange,
                      ),
                      if (calc.advanceCarryforward > 0)
                        _SummaryRow(
                          label: 'Oldingi davrdan qarz',
                          value: calc.advanceCarryforward,
                          color: AppColors.error,
                        ),
                      const SizedBox(height: 8),
                      Container(
                        height: 1,
                        color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
                      ),
                      const SizedBox(height: 8),
                      _SummaryRow(
                        label: 'Yakuniy to\'lov',
                        value: calc.finalPay,
                        color: AppColors.success,
                        bold: true,
                      ),
                    ],
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  final String label;
  final int value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: bold ? color : color.withOpacity(0.85),
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: bold ? 15 : 13,
            ),
          ),
          Text(
            '${NumberFormat.decimalPattern().format(value)} UZS',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.bold,
              color: color,
              fontSize: bold ? 16 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.labelDark : AppColors.labelLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
            ),
          ),
        ],
      ),
    );
  }
}
