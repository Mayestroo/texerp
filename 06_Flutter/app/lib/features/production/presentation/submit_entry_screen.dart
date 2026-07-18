import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/core/widgets/app_toast.dart';
import 'package:texerp/features/production/data/production_models.dart';
import 'package:texerp/features/production/presentation/production_bloc.dart';

class SubmitEntryScreen extends StatefulWidget {
  const SubmitEntryScreen({super.key});

  @override
  State<SubmitEntryScreen> createState() => _SubmitEntryScreenState();
}

class _SubmitEntryScreenState extends State<SubmitEntryScreen> {
  final _quantityController = TextEditingController(text: '1');
  final _noteController = TextEditingController();
  final _focusNode = FocusNode();

  Operation? _selectedOperation;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    context.read<ProductionBloc>().add(const ProductionLoadOperationsRequested());
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onDateSegmentChanged(int? index) {
    if (index == null) return;
    setState(() {
      if (index == 0) {
        _selectedDate = DateTime.now();
      } else if (index == 1) {
        _selectedDate = DateTime.now().subtract(const Duration(days: 1));
      } else {
        _showDatePicker();
      }
    });
  }

  void _showDatePicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: const Text('Bekor qilish'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    CupertinoButton(
                      child: const Text('Tanlash'),
                      onPressed: () => Navigator.of(context).pop(),
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

  void _showOperationsPicker(List<Operation> operations) {
    String searchQuery = '';
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredOps = operations.where((op) {
              return op.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  (op.code?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);
            }).toList();

            final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Operatsiyani tanlang',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.labelDark : AppColors.labelLight,
                              inherit: false,
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: const Text('Yopish', style: TextStyle(fontWeight: FontWeight.w600)),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: CupertinoSearchTextField(
                        placeholder: 'Qidirish...',
                        onChanged: (val) {
                          setModalState(() {
                            searchQuery = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // List
                    Expanded(
                      child: filteredOps.isEmpty
                          ? Center(
                              child: Text(
                                'Operatsiyalar topilmadi',
                                style: TextStyle(
                                  color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                                  inherit: false,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredOps.length,
                              itemBuilder: (context, index) {
                                final op = filteredOps[index];
                                final isSelected = _selectedOperation?.id == op.id;
                                return Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    title: Text(
                                      op.name,
                                      style: TextStyle(
                                        color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${op.code ?? "Kodlarsiz"} • ${op.unitPrice.toInt()} UZS / ${op.unit}',
                                      style: TextStyle(
                                        color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? Icon(CupertinoIcons.check_mark, color: AppColors.primary)
                                        : null,
                                    onTap: () {
                                      setState(() {
                                        _selectedOperation = op;
                                      });
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                );
                              },
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

  void _submit() {
    if (_selectedOperation == null) {
      AppToast.show(context, message: 'Iltimos, operatsiyani tanlang', type: ToastType.error);
      return;
    }

    final qtyStr = _quantityController.text;
    final qty = double.tryParse(qtyStr);
    if (qty == null || qty <= 0) {
      AppToast.show(context, message: 'Hajmni to\'g\'ri kiriting', type: ToastType.error);
      return;
    }

    final recordDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    context.read<ProductionBloc>().add(ProductionSubmitRequested(
          operationId: _selectedOperation!.id,
          quantity: qty,
          recordDate: recordDate,
          workerNote: _noteController.text,
        ));
  }

  void _adjustQuantity(int delta) {
    final currentVal = int.tryParse(_quantityController.text) ?? 1;
    final newVal = currentVal + delta;
    if (newVal >= 1) {
      setState(() {
        _quantityController.text = newVal.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    // Date segments UI helper
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final isToday = DateFormat('yyyyMMdd').format(_selectedDate) == DateFormat('yyyyMMdd').format(now);
    final isYesterday = DateFormat('yyyyMMdd').format(_selectedDate) == DateFormat('yyyyMMdd').format(yesterday);
    int selectedSegmentIndex = 2;
    if (isToday) {
      selectedSegmentIndex = 0;
    } else if (isYesterday) {
      selectedSegmentIndex = 1;
    }

    return BlocConsumer<ProductionBloc, ProductionState>(
      listener: (context, state) {
        if (state.submitStatus == ProductionSubmitStatus.success) {
          AppToast.show(context, message: 'Ish muvaffaqiyatli kiritildi!', type: ToastType.success);
          setState(() {
            _selectedOperation = null;
            _quantityController.text = '1';
            _noteController.clear();
            _selectedDate = DateTime.now();
          });
        } else if (state.submitStatus == ProductionSubmitStatus.failure) {
          AppToast.show(context, message: state.submitError ?? 'Xatolik yuz berdi', type: ToastType.error);
        }
      },
      builder: (context, state) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              children: [
                const SizedBox(height: 16),
                // Operation selector card
                GestureDetector(
                  onTap: () {
                    if (state.operationsLoading) return;
                    _showOperationsPicker(state.operations);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : AppColors.cardLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0x11FFFFFF) : const Color(0x11000000),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.circle_grid_3x3_fill,
                          color: AppColors.primary,
                          size: 26,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Operatsiya turi',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                                  fontWeight: FontWeight.w500,
                                  inherit: false,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedOperation?.name ?? 'Operatsiyani tanlash',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _selectedOperation != null
                                      ? (isDark ? AppColors.labelDark : AppColors.labelLight)
                                      : (isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight),
                                  fontWeight: _selectedOperation != null ? FontWeight.w600 : FontWeight.w400,
                                  inherit: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          CupertinoIcons.chevron_forward,
                          color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Quantity card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : AppColors.cardLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0x11FFFFFF) : const Color(0x11000000),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bajarilgan hajm (${_selectedOperation?.unit ?? "dona"})',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
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
                            onPressed: () => _adjustQuantity(-1),
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
                                controller: _quantityController,
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
                            onPressed: () => _adjustQuantity(1),
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
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Date Picker Toggle Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : AppColors.cardLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0x11FFFFFF) : const Color(0x11000000),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sana',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                          fontWeight: FontWeight.w500,
                          inherit: false,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoSlidingSegmentedControl<int>(
                          groupValue: selectedSegmentIndex,
                          children: {
                            0: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Bugun', style: TextStyle(fontSize: 14)),
                            ),
                            1: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Kecha', style: TextStyle(fontSize: 14)),
                            ),
                            2: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                selectedSegmentIndex == 2
                                    ? DateFormat('dd.MM.yyyy').format(_selectedDate)
                                    : 'Boshqa...',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          },
                          onValueChanged: _onDateSegmentChanged,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Note Field Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : AppColors.cardLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0x11FFFFFF) : const Color(0x11000000),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Izoh (ixtiyoriy)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                          fontWeight: FontWeight.w500,
                          inherit: false,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: _noteController,
                        focusNode: _focusNode,
                        maxLines: 3,
                        placeholder: 'Boshliq uchun eslatmalar, izohlar...',
                        style: TextStyle(
                          color: isDark ? AppColors.labelDark : AppColors.labelLight,
                          fontSize: 15,
                        ),
                        decoration: const BoxDecoration(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Submit button
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: state.submitStatus == ProductionSubmitStatus.loading ? null : _submit,
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: state.submitStatus == ProductionSubmitStatus.loading
                        ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                        : const Text(
                            'Ishni kiritish',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }
}
