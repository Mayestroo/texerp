import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/core/widgets/app_toast.dart';
import 'package:texerp/features/payroll/presentation/payroll_bloc.dart';

class PayrollPeriodListScreen extends StatefulWidget {
  const PayrollPeriodListScreen({super.key});

  @override
  State<PayrollPeriodListScreen> createState() =>
      _PayrollPeriodListScreenState();
}

class _PayrollPeriodListScreenState extends State<PayrollPeriodListScreen> {
  String _selectedStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadPeriods();
  }

  void _loadPeriods() {
    context.read<PayrollBloc>().add(
          PayrollPeriodsLoadRequested(status: _selectedStatus),
        );
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

  String _formatMoney(int amount) {
    return NumberFormat('#,###').format(amount);
  }

  void _showCreatePeriodSheet() {
    final nameController = TextEditingController();
    final startDateController = TextEditingController();
    final endDateController = TextEditingController();

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
        final primaryColor = CupertinoTheme.of(context).primaryColor;

        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFC7C7CC),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Yangi davr yaratish',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.labelDark : AppColors.labelLight,
                          inherit: false,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.xmark,
                            size: 16,
                            color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Period Name Input
                        Text(
                          'Davr nomi',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                            fontWeight: FontWeight.bold,
                            inherit: false,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardDark : AppColors.cardLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
                            ),
                          ),
                          child: CupertinoTextField(
                            controller: nameController,
                            placeholder: 'Masalan: Iyul 2026',
                            placeholderStyle: TextStyle(
                              color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                              fontSize: 14,
                            ),
                            style: TextStyle(
                              color: isDark ? AppColors.labelDark : AppColors.labelLight,
                              fontSize: 14,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Start Date Input
                        Text(
                          'Boshlanish sanasi',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                            fontWeight: FontWeight.bold,
                            inherit: false,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardDark : AppColors.cardLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
                            ),
                          ),
                          child: CupertinoTextField(
                            controller: startDateController,
                            placeholder: 'Format: YYYY-MM-DD',
                            placeholderStyle: TextStyle(
                              color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                              fontSize: 14,
                            ),
                            style: TextStyle(
                              color: isDark ? AppColors.labelDark : AppColors.labelLight,
                              fontSize: 14,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(),
                            prefix: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Icon(
                                CupertinoIcons.calendar,
                                size: 18,
                                color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // End Date Input
                        Text(
                          'Tugash sanasi',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                            fontWeight: FontWeight.bold,
                            inherit: false,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardDark : AppColors.cardLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
                            ),
                          ),
                          child: CupertinoTextField(
                            controller: endDateController,
                            placeholder: 'Format: YYYY-MM-DD',
                            placeholderStyle: TextStyle(
                              color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                              fontSize: 14,
                            ),
                            style: TextStyle(
                              color: isDark ? AppColors.labelDark : AppColors.labelLight,
                              fontSize: 14,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(),
                            prefix: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Icon(
                                CupertinoIcons.calendar,
                                size: 18,
                                color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            if (nameController.text.isEmpty ||
                                startDateController.text.isEmpty ||
                                endDateController.text.isEmpty) {
                              AppToast.show(context, message: 'Barcha maydonlarni to\'ldiring', type: ToastType.error);
                              return;
                            }
                            context.read<PayrollBloc>().add(
                                  PayrollPeriodCreateRequested(
                                    name: nameController.text.trim(),
                                    startDate: startDateController.text.trim(),
                                    endDate: endDateController.text.trim(),
                                  ),
                                );
                            Navigator.of(ctx).pop();
                          },
                          child: Container(
                            height: 50,
                            width: double.infinity,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor, primaryColor.withOpacity(0.8)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Yangi davr yaratish',
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCalculateConfirm(String id) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Hisob-kitobni boshlash'),
        content: const Text(
            'Barcha ma\'qullangan yozuvlar asosida hisob-kitob amalga oshiriladi. Davom etasizmi?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Bekor qilish'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Hisoblash'),
            onPressed: () {
              Navigator.of(ctx).pop();
              context
                  .read<PayrollBloc>()
                  .add(PayrollPeriodCalculateRequested(id: id));
            },
          ),
        ],
      ),
    );
  }

  void _showFinalizeConfirm(String id) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Yakunlash'),
        content: const Text(
            'Davr yakunlangandan so\'ng o\'zgartirish kiritib bo\'lmaydi. Ishchilar o\'z maoshini ko\'rishlari mumkin bo\'ladi. Davom etasizmi?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Bekor qilish'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Yakunlash'),
            onPressed: () {
              Navigator.of(ctx).pop();
              context
                  .read<PayrollBloc>()
                  .add(PayrollPeriodFinalizeRequested(id: id));
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.labelDark : AppColors.labelLight;
    final secondaryColor =
        isDark ? AppColors.secondaryLabelDark : AppColors.secondaryLabelLight;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return BlocConsumer<PayrollBloc, PayrollState>(
      listener: (context, state) {
        if (state.actionSuccess) {
          AppToast.show(context,
              message: 'Amal muvaffaqiyatli bajarildi');
          context.read<PayrollBloc>().add(
                PayrollPeriodsLoadRequested(status: _selectedStatus),
              );
        }
        if (state.error != null) {
          AppToast.show(context, message: state.error!);
        }
      },
      builder: (context, state) {
        if (state.isLoading && state.periods.isEmpty) {
          return const Center(
            child: CupertinoActivityIndicator(),
          );
        }

        if (state.periods.isEmpty) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  context.read<PayrollBloc>().add(PayrollPeriodsLoadRequested(status: _selectedStatus));
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
                          CupertinoIcons.calendar_badge_minus,
                          size: 64,
                          color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Hisob-kitob davrlari yo\'q',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.labelDark : AppColors.labelLight,
                            inherit: false,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tizimda hozircha hech qanday oylik hisob-kitob davri yaratilmagan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                            inherit: false,
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

        return Stack(
          children: [
            CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: () async {
                    context.read<PayrollBloc>().add(PayrollPeriodsLoadRequested(status: _selectedStatus));
                  },
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final period = state.periods[index];
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
                            padding: const EdgeInsets.all(16),
                            pressedOpacity: 0.8,
                            onPressed: () => context.push('/payroll/periods/${period.id}'),
                            child: Row(
                              children: [
                                // Calendar icon badge
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    CupertinoIcons.calendar_today,
                                    color: primaryColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Period details
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
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${period.startDate} ~ ${period.endDate}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: secondaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _StatusBadge(
                                            status: period.status,
                                            label: _statusLabel(period.status),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isDark ? const Color(0x11FFFFFF) : const Color(0x11000000),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  CupertinoIcons.person_2,
                                                  size: 11,
                                                  color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${period.workerCount} ishchi',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Action / Final amount
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (period.status == 'DRAFT')
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () => _showCalculateConfirm(period.id),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: primaryColor.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: primaryColor.withOpacity(0.15)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(CupertinoIcons.play_fill, size: 12, color: primaryColor),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Hisoblash',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: primaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (period.status == 'CALCULATED')
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () => _showFinalizeConfirm(period.id),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppColors.success.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: AppColors.success.withOpacity(0.15)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(CupertinoIcons.checkmark_seal_fill, size: 12, color: AppColors.success),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Yakunlash',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.success,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (period.status == 'FINALIZED')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.success.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.success.withOpacity(0.15)),
                                        ),
                                        child: Text(
                                          '${_formatMoney(period.totalFinal)} UZS',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: state.periods.length,
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              right: 20,
              bottom: 20,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _showCreatePeriodSheet,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.8)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(CupertinoIcons.add, color: CupertinoColors.white, size: 24),
                ),
              ),
            ),
          ],
        );
      },
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
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
