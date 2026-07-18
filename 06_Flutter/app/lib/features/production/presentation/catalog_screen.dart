import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/core/widgets/app_toast.dart';
import 'package:texerp/features/production/data/production_models.dart';
import 'package:texerp/features/production/presentation/catalog_bloc.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String _selectedStatus = 'ACTIVE';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadOperations();
  }

  void _loadOperations() {
    context.read<CatalogBloc>().add(CatalogLoadRequested(
          status: _selectedStatus,
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
        ));
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

  void _showAddOrEditSheet({Operation? operation}) {
    final nameController = TextEditingController(text: operation?.name);
    final codeController = TextEditingController(text: operation?.code);
    final priceController = TextEditingController(
      text: operation != null ? operation.unitPrice.toInt().toString() : '',
    );
    String unit = operation?.unit ?? 'PIECE';

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
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
                            operation == null ? 'Yangi operatsiya' : 'Operatsiyani tahrirlash',
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
                    // Operation Name
                    Text(
                      'Operatsiya nomi',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                        fontWeight: FontWeight.w500,
                        inherit: false,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: nameController,
                      placeholder: 'Masalan: Yeng ulash',
                    ),
                    const SizedBox(height: 16),
                    // Operation Code
                    Text(
                      'Operatsiya kodi (ixtiyoriy)',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                        fontWeight: FontWeight.w500,
                        inherit: false,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: codeController,
                      placeholder: 'Masalan: OP102',
                    ),
                    const SizedBox(height: 16),
                    // Unit Segment Picker
                    if (operation == null) ...[
                      Text(
                        'O\'lchov birligi',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                          fontWeight: FontWeight.w500,
                          inherit: false,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoSlidingSegmentedControl<String>(
                          groupValue: unit,
                          children: const {
                            'PIECE': Text('dona'),
                            'METER': Text('metr'),
                            'PAIR': Text('juft'),
                          },
                          onValueChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                unit = val;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Unit Price
                    Text(
                      'Bir dona uchun narxi (UZS)',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                        fontWeight: FontWeight.w500,
                        inherit: false,
                      ),
                    ),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      placeholder: 'Masalan: 1200',
                    ),
                    const Spacer(),
                    // Submit button
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        final name = nameController.text.trim();
                        final code = codeController.text.trim();
                        final price = double.tryParse(priceController.text);

                        if (name.isEmpty) {
                          AppToast.show(context, message: 'Operatsiya nomini kiriting', type: ToastType.error);
                          return;
                        }
                        if (price == null || price <= 0) {
                          AppToast.show(context, message: 'To\'g\'ri narx kiriting', type: ToastType.error);
                          return;
                        }

                        Navigator.of(context).pop();

                        if (operation == null) {
                          this.context.read<CatalogBloc>().add(
                                CatalogCreateRequested(
                                  name: name,
                                  code: code.isNotEmpty ? code : null,
                                  unit: unit,
                                  unitPrice: price,
                                ),
                              );
                        } else {
                          this.context.read<CatalogBloc>().add(
                                CatalogUpdateRequested(
                                  id: operation.id,
                                  name: name,
                                  code: code.isNotEmpty ? code : null,
                                  unitPrice: price,
                                ),
                              );
                        }
                      },
                      child: Container(
                        height: 52,
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          operation == null ? 'Qo\'shish' : 'Saqlash',
                          style: const TextStyle(
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

  void _toggleOperationStatus(Operation operation) {
    context.read<CatalogBloc>().add(
          CatalogToggleStatusRequested(
            id: operation.id,
            currentActive: operation.isActive,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return BlocConsumer<CatalogBloc, CatalogState>(
      listener: (context, state) {
        if (state.actionSuccess) {
          AppToast.show(context, message: 'Muvaffaqiyatli bajarildi!', type: ToastType.success);
        } else if (state.actionError != null) {
          AppToast.show(context, message: state.actionError!, type: ToastType.error);
        }
      },
      builder: (context, state) {
        final isBusy = state.isLoading && state.operations.isEmpty;

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                _loadOperations();
              },
            ),
            // Header actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoSearchTextField(
                        placeholder: 'Operatsiyalarni qidirish...',
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                          _loadOperations();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _showAddOrEditSheet(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.add,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Segment switch
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<String>(
                    groupValue: _selectedStatus,
                    children: const {
                      'ACTIVE': Text('Faol'),
                      'INACTIVE': Text('Faolsiz'),
                    },
                    onValueChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedStatus = val;
                        });
                        _loadOperations();
                      }
                    },
                  ),
                ),
              ),
            ),
            if (isBusy)
              const SliverFillRemaining(
                child: Center(
                  child: CupertinoActivityIndicator(),
                ),
              )
            else if (state.error != null && state.operations.isEmpty)
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
                          onPressed: _loadOperations,
                          child: const Text('Qayta yuklash'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (state.operations.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.square_grid_2x2,
                          size: 64,
                          color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'Katalog bo\'sh' : 'Operatsiyalar topilmadi',
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
                          _searchQuery.isEmpty
                              ? 'Katalogda hali birorta ham ish turi yaratilmagan.'
                              : 'Qidiruv shartlariga mos keladigan operatsiya topilmadi.',
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
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final operation = state.operations[index];
                      final isCurrentBusy = state.actionInProgressId == operation.id;

                      return Opacity(
                        opacity: isCurrentBusy ? 0.6 : 1.0,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardDark : AppColors.cardLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0x11FFFFFF) : const Color(0x11000000),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _showAddOrEditSheet(operation: operation),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        operation.name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                          inherit: false,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          if (operation.code != null) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                operation.code!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                                  inherit: false,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Text(
                                            '${NumberFormat.decimalPattern().format(operation.unitPrice)} UZS / ${_formatUnit(operation.unit)}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                              inherit: false,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Toggle Active/Inactive Button
                              if (isCurrentBusy)
                                const CupertinoActivityIndicator()
                              else
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _toggleOperationStatus(operation),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: operation.isActive
                                          ? AppColors.error.withOpacity(0.08)
                                          : AppColors.success.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: operation.isActive
                                            ? AppColors.error.withOpacity(0.2)
                                            : AppColors.success.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Text(
                                      operation.isActive ? 'Nofaollash' : 'Faollash',
                                      style: TextStyle(
                                        color: operation.isActive ? AppColors.error : AppColors.success,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: state.operations.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
