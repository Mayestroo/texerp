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

  Widget _buildPillTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor
                : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : (isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000)),
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected
                  ? CupertinoColors.white
                  : (isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight),
              inherit: true,
            ),
          ),
        ),
      ),
    );
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
                top: false,
                child: StatefulBuilder(
                  builder: (context, setModalState) {
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
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
                                  operation == null ? 'Yangi operatsiya' : 'Operatsiyani tahrirlash',
                                  style: TextStyle(
                                    fontSize: 20,
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
                          
                          // Operation Name
                          Text(
                            'Operatsiya nomi',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                              fontWeight: FontWeight.w600,
                              inherit: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CupertinoTextField(
                            controller: nameController,
                            placeholder: 'Masalan: Yeng ulash',
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            clearButtonMode: OverlayVisibilityMode.editing,
                            prefix: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Icon(
                                CupertinoIcons.square_grid_2x2,
                                size: 18,
                                color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                              ),
                            ),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
                              ),
                            ),
                            style: TextStyle(
                              color: isDark ? AppColors.labelDark : AppColors.labelLight,
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Operation Code
                          Text(
                            'Operatsiya kodi (ixtiyoriy)',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                              fontWeight: FontWeight.w600,
                              inherit: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CupertinoTextField(
                            controller: codeController,
                            placeholder: 'Masalan: OP102',
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            clearButtonMode: OverlayVisibilityMode.editing,
                            prefix: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Icon(
                                CupertinoIcons.number,
                                size: 18,
                                color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                              ),
                            ),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
                              ),
                            ),
                            style: TextStyle(
                              color: isDark ? AppColors.labelDark : AppColors.labelLight,
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Unit Chips Selection (only when adding new operation)
                          if (operation == null) ...[
                            Text(
                              'O\'lchov birligi',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                fontWeight: FontWeight.w600,
                                inherit: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: ['PIECE', 'METER', 'PAIR'].map((u) {
                                final isSelected = unit == u;
                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      unit = u;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7)),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primaryLight
                                            : (isDark ? const Color(0x1AFFFFFF) : const Color(0x1F000000)),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isSelected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                                          size: 16,
                                          color: isSelected
                                              ? CupertinoColors.white
                                              : (isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatUnit(u),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isSelected
                                                ? CupertinoColors.white
                                                : (isDark ? AppColors.labelDark : AppColors.labelLight),
                                            inherit: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          // Unit Price
                          Text(
                            'Bir dona uchun narxi (UZS)',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                              fontWeight: FontWeight.w600,
                              inherit: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CupertinoTextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            placeholder: 'Masalan: 1200',
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            clearButtonMode: OverlayVisibilityMode.editing,
                            prefix: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Icon(
                                CupertinoIcons.money_dollar,
                                size: 18,
                                color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                              ),
                            ),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
                              ),
                            ),
                            style: TextStyle(
                              color: isDark ? AppColors.labelDark : AppColors.labelLight,
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
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
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
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
                    );
                  },
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
          _loadOperations();
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
            // Header actions (Custom Search & Add Button)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        placeholder: 'Operatsiyalarni qidirish...',
                        placeholderStyle: TextStyle(
                          color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                          fontSize: 14,
                          inherit: true,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        clearButtonMode: OverlayVisibilityMode.editing,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                          _loadOperations();
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
            // Custom Segmented Pill Tab Switcher
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Row(
                  children: [
                    _buildPillTab(
                      label: 'Faol',
                      isSelected: _selectedStatus == 'ACTIVE',
                      onTap: () {
                        setState(() {
                          _selectedStatus = 'ACTIVE';
                        });
                        _loadOperations();
                      },
                      isDark: isDark,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(width: 8),
                    _buildPillTab(
                      label: 'Faolsiz',
                      isSelected: _selectedStatus == 'INACTIVE',
                      onTap: () {
                        setState(() {
                          _selectedStatus = 'INACTIVE';
                        });
                        _loadOperations();
                      },
                      isDark: isDark,
                      primaryColor: primaryColor,
                    ),
                  ],
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
                hasScrollBody: false,
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                ),
              )
            else if (state.operations.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
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
                              inherit: true,
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
                              inherit: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final operation = state.operations[index];
                      final isCurrentBusy = state.actionInProgressId == operation.id;
                      final initials = operation.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

                      return Opacity(
                        opacity: isCurrentBusy ? 0.6 : 1.0,
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
                                color: isDark ? const Color(0x0D000000) : const Color(0x08000000),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Initials Avatar
                                  GestureDetector(
                                    onTap: () => _showAddOrEditSheet(operation: operation),
                                    child: Container(
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
                                          inherit: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Details Column
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
                                              inherit: true,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(CupertinoIcons.number, size: 12, color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight),
                                              const SizedBox(width: 4),
                                              Text(
                                                operation.code ?? 'Kodsiz',
                                                style: TextStyle(
                                                  fontSize: 12,
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
                                  ),
                                  const SizedBox(width: 8),

                                  // Status Toggle Button
                                  if (isCurrentBusy)
                                    const CupertinoActivityIndicator()
                                  else
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _toggleOperationStatus(operation),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: operation.isActive
                                              ? AppColors.error.withOpacity(0.08)
                                              : AppColors.success.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: operation.isActive
                                                ? AppColors.error.withOpacity(0.15)
                                                : AppColors.success.withOpacity(0.15),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              operation.isActive ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                                              size: 13,
                                              color: operation.isActive ? AppColors.error : AppColors.success,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              operation.isActive ? 'Faolsizlash' : 'Faollash',
                                              style: TextStyle(
                                                color: operation.isActive ? AppColors.error : AppColors.success,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              // Pricing Badge Strip
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
                                      '${NumberFormat.decimalPattern().format(operation.unitPrice)} UZS / ${_formatUnit(operation.unit)}',
                                      style: const TextStyle(
                                        fontSize: 12,
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
