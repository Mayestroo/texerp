import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/core/widgets/app_toast.dart';
import 'package:texerp/features/warehouse/presentation/warehouse_bloc.dart';

class IssuanceBottomSheet extends StatefulWidget {
  const IssuanceBottomSheet({super.key});

  @override
  State<IssuanceBottomSheet> createState() => _IssuanceBottomSheetState();
}

class _IssuanceBottomSheetState extends State<IssuanceBottomSheet> {
  final _quantityController = TextEditingController(text: '1');
  final _destinationController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _quantityController.dispose();
    _destinationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _adjustQuantity(double delta) {
    final current = double.tryParse(_quantityController.text) ?? 0;
    final next = current + delta;
    if (next >= 0) {
      setState(() {
        _quantityController.text = _formatQuantity(next);
      });
    }
  }

  String _formatQuantity(double value) {
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  void _showDatePicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                color: CupertinoColors.secondarySystemBackground.resolveFrom(ctx),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: const Text('Bekor qilish'),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                    CupertinoButton(
                      child: const Text('Tanlash'),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _selectedDate,
                  maximumDate: DateTime.now(),
                  minimumDate: DateTime.now().subtract(const Duration(days: 30)),
                  onDateTimeChanged: (DateTime newDate) {
                    setState(() {
                      _selectedDate = newDate;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final bloc = context.read<WarehouseBloc>();
    final materialId = bloc.state.selectedMaterial?.id;
    if (materialId == null || materialId.isEmpty) {
      AppToast.show(context,
          message: 'Material tanlanmagan', type: ToastType.error);
      return;
    }

    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      AppToast.show(context,
          message: 'Hajmni to\'g\'ri kiriting', type: ToastType.error);
      return;
    }

    bloc.add(WarehouseIssuanceRequested(
      materialId: materialId,
      quantity: quantity,
      movementDate: _selectedDate,
      destination: _destinationController.text.isEmpty
          ? null
          : _destinationController.text.trim(),
      note: _noteController.text.isEmpty ? null : _noteController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return BlocConsumer<WarehouseBloc, WarehouseState>(
      listener: (context, state) {
        if (state.actionSuccess) {
          Navigator.of(context).pop();
        }
        if (state.actionError != null) {
          AppToast.show(context,
              message: state.actionError!, type: ToastType.error);
        }
      },
      builder: (context, state) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1C1C1E)
                : CupertinoColors.systemBackground.resolveFrom(context),
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
                      color: isDark
                          ? const Color(0xFF3A3A3C)
                          : const Color(0xFFC7C7CC),
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
                        'Berish',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.labelDark
                              : AppColors.labelLight,
                          inherit: true,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2C2C2E)
                                : const Color(0xFFE5E5EA),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.xmark,
                            size: 16,
                            color: isDark
                                ? AppColors.labelSecondary
                                : AppColors.secondaryLabelLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      // Quantity
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Hajm',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.labelSecondary
                                : AppColors.secondaryLabelLight,
                            inherit: true,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.cardDark
                              : AppColors.cardLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? const Color(0x1AFFFFFF)
                                : const Color(0x0F000000),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _adjustQuantity(-1),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF2C2C2E)
                                      : const Color(0xFFF2F2F7),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0x11FFFFFF)
                                        : const Color(0x11000000),
                                  ),
                                ),
                                child: Icon(
                                  CupertinoIcons.minus,
                                  size: 20,
                                  color: isDark
                                      ? AppColors.labelDark
                                      : AppColors.labelLight,
                                ),
                              ),
                            ),
                            Expanded(
                              child: CupertinoTextField(
                                controller: _quantityController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.labelDark
                                      : AppColors.labelLight,
                                ),
                                decoration: const BoxDecoration(),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _adjustQuantity(1),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF2C2C2E)
                                      : const Color(0xFFF2F2F7),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0x11FFFFFF)
                                        : const Color(0x11000000),
                                  ),
                                ),
                                child: Icon(
                                  CupertinoIcons.plus,
                                  size: 20,
                                  color: isDark
                                      ? AppColors.labelDark
                                      : AppColors.labelLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Movement date
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Sana',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.labelSecondary
                                : AppColors.secondaryLabelLight,
                            inherit: true,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _showDatePicker,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.cardDark
                                : AppColors.cardLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0x1AFFFFFF)
                                  : const Color(0x0F000000),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.calendar,
                                size: 18,
                                color: isDark
                                    ? AppColors.labelSecondary
                                    : AppColors.secondaryLabelLight,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                DateFormat('dd.MM.yyyy').format(_selectedDate),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isDark
                                      ? AppColors.labelDark
                                      : AppColors.labelLight,
                                  inherit: true,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                CupertinoIcons.chevron_down,
                                size: 14,
                                color: isDark
                                    ? AppColors.labelSecondary
                                    : AppColors.secondaryLabelLight,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Destination
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Yo\'nalish (ixtiyoriy)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.labelSecondary
                                : AppColors.secondaryLabelLight,
                            inherit: true,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.cardDark
                              : AppColors.cardLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? const Color(0x1AFFFFFF)
                                : const Color(0x0F000000),
                          ),
                        ),
                        child: CupertinoTextField(
                          controller: _destinationController,
                          placeholder: 'Qayerga berilmoqda',
                          placeholderStyle: TextStyle(
                            color: isDark
                                ? AppColors.labelTertiary
                                : AppColors.secondaryLabelLight,
                            fontSize: 14,
                          ),
                          style: TextStyle(
                            color: isDark
                                ? AppColors.labelDark
                                : AppColors.labelLight,
                            fontSize: 15,
                          ),
                          decoration: const BoxDecoration(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Note
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Izoh (ixtiyoriy)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.labelSecondary
                                : AppColors.secondaryLabelLight,
                            inherit: true,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.cardDark
                              : AppColors.cardLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? const Color(0x1AFFFFFF)
                                : const Color(0x0F000000),
                          ),
                        ),
                        child: CupertinoTextField(
                          controller: _noteController,
                          placeholder: 'Izoh qoldiring',
                          placeholderStyle: TextStyle(
                            color: isDark
                                ? AppColors.labelTertiary
                                : AppColors.secondaryLabelLight,
                            fontSize: 14,
                          ),
                          style: TextStyle(
                            color: isDark
                                ? AppColors.labelDark
                                : AppColors.labelLight,
                            fontSize: 15,
                          ),
                          maxLines: 3,
                          decoration: const BoxDecoration(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit button
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: state.actionLoading ? null : _submit,
                        child: Container(
                          height: 54,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.error,
                                AppColors.error.withOpacity(0.85),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.error.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: state.actionLoading
                              ? const CupertinoActivityIndicator(
                                  color: CupertinoColors.white)
                              : const Text(
                                  'Berish',
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
              ],
            ),
          ),
        );
      },
    );
  }
}
