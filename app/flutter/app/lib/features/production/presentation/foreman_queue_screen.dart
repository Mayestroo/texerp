import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/core/widgets/app_toast.dart';
import 'package:texerp/features/production/data/production_models.dart';
import 'package:texerp/features/production/presentation/foreman_queue_bloc.dart';

class ForemanQueueScreen extends StatefulWidget {
  const ForemanQueueScreen({super.key});

  @override
  State<ForemanQueueScreen> createState() => _ForemanQueueScreenState();
}

class _ForemanQueueScreenState extends State<ForemanQueueScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ForemanQueueBloc>().add(const ForemanQueueLoadRequested());
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

  void _showRejectDialog(String entryId) {
    final reasonController = TextEditingController();
    showCupertinoDialog<void>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('Ishni rad etish'),
          content: Column(
            children: [
              const SizedBox(height: 8),
              const Text('Iltimos, rad etish sababini yozib qoldiring:'),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: reasonController,
                placeholder: 'Sabab (masalan: Sifatsiz tikilgan)',
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Bekor qilish'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  AppToast.show(context, message: 'Rad etish sababini kiritish majburiy', type: ToastType.error);
                  return;
                }
                Navigator.of(context).pop();
                context.read<ForemanQueueBloc>().add(ForemanQueueRejectRequested(
                      id: entryId,
                      reason: reason,
                    ));
              },
              child: const Text('Rad etish'),
            ),
          ],
        );
      },
    );
  }

  void _showCorrectBottomSheet(ProductionEntry entry) {
    final quantityController = TextEditingController(text: entry.quantitySubmitted.toInt().toString());
    final commentController = TextEditingController();

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
        final primaryColor = CupertinoTheme.of(context).primaryColor;

        return StatefulBuilder(
          builder: (context, setModalState) {
            void adjustQty(int delta) {
              final val = int.tryParse(quantityController.text) ?? 1;
              final newVal = val + delta;
              if (newVal >= 1) {
                setModalState(() {
                  quantityController.text = newVal.toString();
                });
              }
            }

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
                            'Tahrirlash va Tasdiqlash',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.labelDark : AppColors.labelLight,
                              inherit: true,
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
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Quantity Label
                            Text(
                              'Tahrirlangan hajm (dona)',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                fontWeight: FontWeight.bold,
                                inherit: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Quantity adjustments row
                            Container(
                              padding: const EdgeInsets.all(12),
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
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => adjustQty(-1),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(CupertinoIcons.minus, size: 18, color: isDark ? AppColors.labelDark : AppColors.labelLight),
                                    ),
                                  ),
                                  Expanded(
                                    child: CupertinoTextField(
                                      controller: quantityController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                      ),
                                      decoration: const BoxDecoration(),
                                    ),
                                  ),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => adjustQty(1),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(CupertinoIcons.plus, size: 18, color: isDark ? AppColors.labelDark : AppColors.labelLight),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Comment field Label
                            Text(
                              'Tahrirlash izohi (ixtiyoriy)',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                fontWeight: FontWeight.bold,
                                inherit: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
                                ),
                              ),
                              child: CupertinoTextField(
                                controller: commentController,
                                placeholder: 'Nima sababdan o\'zgartirildi...',
                                placeholderStyle: TextStyle(
                                  color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                                  fontSize: 14,
                                ),
                                style: TextStyle(
                                  color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                  fontSize: 14,
                                ),
                                maxLines: 3,
                                decoration: const BoxDecoration(),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Submit button
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                final qty = double.tryParse(quantityController.text);
                                if (qty == null || qty <= 0) {
                                  AppToast.show(context, message: 'Hajmni to\'g\'ri kiriting', type: ToastType.error);
                                  return;
                                }
                                Navigator.of(context).pop();
                                this.context.read<ForemanQueueBloc>().add(
                                      ForemanQueueCorrectRequested(
                                        id: entry.id,
                                        correctedQuantity: qty,
                                        comment: commentController.text.trim(),
                                      ),
                                    );
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
                                  'Tahrirlab tasdiqlash',
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return BlocConsumer<ForemanQueueBloc, ForemanQueueState>(
      listener: (context, state) {
        if (state.actionSuccess) {
          AppToast.show(context, message: 'Ish muvaffaqiyatli ko\'rib chiqildi!', type: ToastType.success);
          context.read<ForemanQueueBloc>().add(const ForemanQueueLoadRequested());
        } else if (state.actionError != null) {
          AppToast.show(context, message: state.actionError!, type: ToastType.error);
        }
      },
      builder: (context, state) {
        if (state.isLoading && state.pendingEntries.isEmpty) {
          return const Center(
            child: CupertinoActivityIndicator(),
          );
        }

        if (state.error != null && state.pendingEntries.isEmpty) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  context.read<ForemanQueueBloc>().add(const ForemanQueueLoadRequested());
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
                          'Yuklashda xatolik',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.labelDark : AppColors.labelLight,
                            inherit: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.error!,
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
                            context.read<ForemanQueueBloc>().add(const ForemanQueueLoadRequested());
                          },
                          child: const Text('Qayta yuklash'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        if (state.pendingEntries.isEmpty) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  context.read<ForemanQueueBloc>().add(const ForemanQueueLoadRequested());
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
                          CupertinoIcons.checkmark_seal,
                          size: 64,
                          color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tasdiqlanmagan ishlar yo\'q',
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
                          'Sizning jamoangizdagi barcha ishchilarning ishlari ko\'rib chiqilgan.',
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
                context.read<ForemanQueueBloc>().add(const ForemanQueueLoadRequested());
              },
            ),
            SliverPadding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = state.pendingEntries[index];
                    final isBusy = state.actionInProgressId == entry.id;
                    final totalCost = entry.quantitySubmitted * entry.unitPriceSnapshot;
                    final initials = entry.worker?.fullName
                        .split(' ')
                        .map((e) => e.isNotEmpty ? e[0] : '')
                        .take(2)
                        .join()
                        .toUpperCase() ?? 'I';

                    return Opacity(
                      opacity: isBusy ? 0.6 : 1.0,
                      child: Container(
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
                            // Worker Row
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
                                    initials,
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
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
                                        entry.worker?.fullName ?? 'Noma\'lum ishchi',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                          inherit: true,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(CupertinoIcons.number, size: 10, color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight),
                                          const SizedBox(width: 2),
                                          Text(
                                            entry.worker?.workerCode ?? '',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                              inherit: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
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
                            const SizedBox(height: 12),
                            Divider(color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000), height: 1),
                            const SizedBox(height: 12),
                            
                            // Operation Details Title
                            Text(
                              entry.operationNameSnapshot,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                inherit: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                            
                            // Quantity and Price badges row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Hajmi: ${entry.quantitySubmitted.toInt()} dona',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                      inherit: true,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.success.withOpacity(0.15)),
                                  ),
                                  child: Text(
                                    '${NumberFormat.decimalPattern().format(totalCost)} UZS',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                      inherit: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (entry.workerNote != null && entry.workerNote!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0x0AFFFFFF) : const Color(0x05000000),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                width: double.infinity,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      CupertinoIcons.text_bubble,
                                      size: 14,
                                      color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Ishchi izohi: ${entry.workerNote}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                          fontStyle: FontStyle.italic,
                                          inherit: true,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            // Actions Row
                            if (isBusy)
                              const Align(
                                alignment: Alignment.center,
                                child: CupertinoActivityIndicator(),
                              )
                            else
                              Row(
                                children: [
                                  // Reject Button
                                  Expanded(
                                    child: CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _showRejectDialog(entry.id),
                                      child: Container(
                                        height: 40,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.error.withOpacity(0.15)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(CupertinoIcons.xmark, size: 14, color: AppColors.error),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Rad etish',
                                              style: TextStyle(
                                                color: AppColors.error,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Edit Button
                                  Expanded(
                                    child: CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _showCorrectBottomSheet(entry),
                                      child: Container(
                                        height: 40,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: AppColors.info.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.info.withOpacity(0.15)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(CupertinoIcons.pencil, size: 14, color: AppColors.info),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Tahrirlash',
                                              style: TextStyle(
                                                color: AppColors.info,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Approve Button
                                  Expanded(
                                    child: CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        context.read<ForemanQueueBloc>().add(
                                              ForemanQueueApproveRequested(id: entry.id),
                                            );
                                      },
                                      child: Container(
                                        height: 40,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: AppColors.success.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.success.withOpacity(0.15)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(CupertinoIcons.checkmark, size: 14, color: AppColors.success),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Tasdiqlash',
                                              style: TextStyle(
                                                color: AppColors.success,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
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
                    );
                  },
                  childCount: state.pendingEntries.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
