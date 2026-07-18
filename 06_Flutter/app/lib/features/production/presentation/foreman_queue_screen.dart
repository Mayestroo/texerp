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
              height: MediaQuery.of(context).size.height * 0.55,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tahrirlash va Tasdiqlash',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.labelDark : AppColors.labelLight,
                              inherit: false,
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: const Text('Bekor qilish'),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Quantity adjustments
                    Text(
                      'Tahrirlangan hajm (dona)',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                        fontWeight: FontWeight.w500,
                        inherit: false,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => adjustQty(-1),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0x11FFFFFF) : const Color(0x05000000),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.minus, size: 20),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => adjustQty(1),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0x11FFFFFF) : const Color(0x05000000),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(CupertinoIcons.plus, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Comment field
                    Text(
                      'Tahrirlash izohi (ixtiyoriy)',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                        fontWeight: FontWeight.w500,
                        inherit: false,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: commentController,
                      placeholder: 'Nima sababdan o\'zgartirildi...',
                      maxLines: 2,
                    ),
                    const Spacer(),
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
                        // Dispatch correct event
                        this.context.read<ForemanQueueBloc>().add(
                              ForemanQueueCorrectRequested(
                                id: entry.id,
                                correctedQuantity: qty,
                                comment: commentController.text.trim(),
                              ),
                            );
                      },
                      child: Container(
                        height: 52,
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Tahrirlab tasdiqlash',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
          return Center(
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
                      inherit: false,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                      inherit: false,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CupertinoButton(
                    color: AppColors.primary,
                    onPressed: () {
                      context.read<ForemanQueueBloc>().add(const ForemanQueueLoadRequested());
                    },
                    child: const Text('Qayta yuklash'),
                  ),
                ],
              ),
            ),
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
                            inherit: false,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sizning jamoangizdagi barcha ishchilarning ishlari ko\'rib chiqilgan.',
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

                    return Opacity(
                      opacity: isBusy ? 0.6 : 1.0,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDark : AppColors.cardLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0x11FFFFFF) : const Color(0x11000000),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.black.withOpacity(0.02),
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
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      entry.worker?.fullName.substring(0, 1).toUpperCase() ?? 'I',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        inherit: false,
                                      ),
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
                                          inherit: false,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        entry.worker?.workerCode ?? '',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                                          inherit: false,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _formatDate(entry.submittedAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                                    inherit: false,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(color: isDark ? const Color(0x11FFFFFF) : const Color(0x11000000), height: 1),
                            const SizedBox(height: 12),
                            // Operation Details
                            Text(
                              entry.operationNameSnapshot,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                inherit: false,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Hajmi: ${entry.quantitySubmitted.toInt()} dona',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                    inherit: false,
                                  ),
                                ),
                                Text(
                                  '${NumberFormat.decimalPattern().format(totalCost)} UZS',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                    inherit: false,
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
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                width: double.infinity,
                                child: Text(
                                  'Ishchi izohi: ${entry.workerNote}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                    fontStyle: FontStyle.italic,
                                    inherit: false,
                                  ),
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
                                  // Reject Button (Red)
                                  Expanded(
                                    child: CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _showRejectDialog(entry.id),
                                      child: Container(
                                        height: 40,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.error.withOpacity(0.2)),
                                        ),
                                        child: Text(
                                          'Rad etish',
                                          style: TextStyle(
                                            color: AppColors.error,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Edit Button (Blue)
                                  Expanded(
                                    child: CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _showCorrectBottomSheet(entry),
                                      child: Container(
                                        height: 40,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: AppColors.info.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.info.withOpacity(0.2)),
                                        ),
                                        child: Text(
                                          'Tahrirlash',
                                          style: TextStyle(
                                            color: AppColors.info,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Approve Button (Green)
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
                                          color: AppColors.success.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.success.withOpacity(0.2)),
                                        ),
                                        child: Text(
                                          'Tasdiqlash',
                                          style: TextStyle(
                                            color: AppColors.success,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
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
