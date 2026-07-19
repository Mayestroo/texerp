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

  String _formatUnit(String unit) {
    switch (unit) {
      case 'PIECE':
        return 'dona';
      case 'METER':
        return 'metr';
      case 'PAIR':
        return 'juft';
      default:
        return unit;
    }
  }

  void _showOperationsPicker(List<Operation> operations) {
    String searchQuery = '';
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        final primaryColor = CupertinoTheme.of(context).primaryColor;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredOps = operations.where((op) {
              return op.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  (op.code?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);
            }).toList();

            final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom,
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
                      padding: const EdgeInsets.only(bottom: 12),
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
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CupertinoTextField(
                        placeholder: 'Qidirish...',
                        placeholderStyle: TextStyle(
                          color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                          fontSize: 14,
                          inherit: false,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        clearButtonMode: OverlayVisibilityMode.editing,
                        onChanged: (val) {
                          setModalState(() {
                            searchQuery = val;
                          });
                        },
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Icon(
                            CupertinoIcons.search,
                            size: 18,
                            color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                          ),
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
                          ),
                        ),
                        style: TextStyle(
                          color: isDark ? AppColors.labelDark : AppColors.labelLight,
                          fontSize: 14,
                        ),
                      ),
                    ),
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
                                final initials = op.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedOperation = op;
                                    });
                                    Navigator.of(context).pop();
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.cardDark : AppColors.cardLight,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? primaryColor
                                            : (isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000)),
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Initials Avatar
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: primaryColor.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            initials.isNotEmpty ? initials : "?",
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor,
                                              inherit: false,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                op.name,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                                  inherit: false,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  Icon(CupertinoIcons.number, size: 10, color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    op.code ?? 'Kodsiz',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                                      inherit: false,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.success.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.success.withOpacity(0.15)),
                                          ),
                                          child: Text(
                                            '${op.unitPrice.toInt()} UZS / ${_formatUnit(op.unit)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.success,
                                              inherit: false,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
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
    final primaryColor = CupertinoTheme.of(context).primaryColor;

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
        final initials = _selectedOperation != null
            ? _selectedOperation!.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
            : '';

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 16),
                
                // Section Title
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Operatsiya turi',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                      inherit: false,
                    ),
                  ),
                ),
                
                // Operation selector card
                GestureDetector(
                  onTap: () {
                    if (state.operationsLoading) return;
                    _showOperationsPicker(state.operations);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : AppColors.cardLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedOperation != null
                            ? primaryColor.withOpacity(0.3)
                            : (isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000)),
                        width: _selectedOperation != null ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? const Color(0x0D000000) : const Color(0x05000000),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _selectedOperation == null
                        ? Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CupertinoIcons.circle_grid_3x3,
                                  color: primaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ish turini tanlang',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                        inherit: false,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Ro\'yxatdan birini tanlang...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
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
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Initials Avatar
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initials.isNotEmpty ? initials : "?",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                        inherit: false,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Details Column
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedOperation!.name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                            inherit: false,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(CupertinoIcons.number, size: 12, color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight),
                                            const SizedBox(width: 4),
                                            Text(
                                              _selectedOperation!.code ?? 'Kodsiz',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                                inherit: false,
                                              ),
                                            ),
                                          ],
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
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.success.withOpacity(0.15)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(CupertinoIcons.money_dollar_circle, size: 14, color: AppColors.success),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${NumberFormat.decimalPattern().format(_selectedOperation!.unitPrice)} UZS / ${_formatUnit(_selectedOperation!.unit)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.success,
                                        inherit: false,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Section Title
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Bajarilgan hajm',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                      inherit: false,
                    ),
                  ),
                ),
                
                // Quantity card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : AppColors.cardLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
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
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0x11FFFFFF) : const Color(0x11000000),
                            ),
                          ),
                          child: Icon(
                            CupertinoIcons.minus,
                            size: 20,
                            color: isDark ? AppColors.labelDark : AppColors.labelLight,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            CupertinoTextField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.labelDark : AppColors.labelLight,
                              ),
                              decoration: const BoxDecoration(),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedOperation != null ? _formatUnit(_selectedOperation!.unit) : 'dona',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                inherit: false,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _adjustQuantity(1),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0x11FFFFFF) : const Color(0x11000000),
                            ),
                          ),
                          child: Icon(
                            CupertinoIcons.plus,
                            size: 20,
                            color: isDark ? AppColors.labelDark : AppColors.labelLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Section Title
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Sana',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                      inherit: false,
                    ),
                  ),
                ),
                
                // Date Picker Toggle Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : AppColors.cardLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<int>(
                      groupValue: selectedSegmentIndex,
                      children: {
                        0: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text('Bugun', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                        1: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text('Kecha', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                        2: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            selectedSegmentIndex == 2
                                ? DateFormat('dd.MM.yyyy').format(_selectedDate)
                                : 'Boshqa...',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      },
                      onValueChanged: _onDateSegmentChanged,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Section Title
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Izoh',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                      inherit: false,
                    ),
                  ),
                ),
                
                // Note Field Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : AppColors.cardLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          CupertinoIcons.text_bubble,
                          size: 18,
                          color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoTextField(
                          controller: _noteController,
                          focusNode: _focusNode,
                          maxLines: 3,
                          placeholder: 'Boshliq uchun eslatmalar, izohlar...',
                          placeholderStyle: TextStyle(
                            color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                            fontSize: 14,
                          ),
                          style: TextStyle(
                            color: isDark ? AppColors.labelDark : AppColors.labelLight,
                            fontSize: 14,
                          ),
                          decoration: const BoxDecoration(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

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
