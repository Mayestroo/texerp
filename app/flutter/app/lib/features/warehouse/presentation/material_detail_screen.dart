import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/core/widgets/app_toast.dart';
import 'package:texerp/features/warehouse/data/warehouse_models.dart' as warehouse;
import 'package:texerp/features/warehouse/presentation/warehouse_bloc.dart';
import 'package:texerp/features/warehouse/presentation/receipt_bottom_sheet.dart';
import 'package:texerp/features/warehouse/presentation/issuance_bottom_sheet.dart';

class MaterialDetailScreen extends StatefulWidget {
  const MaterialDetailScreen({
    required this.materialId,
    this.material,
    super.key,
  });

  final String materialId;
  final warehouse.Material? material;

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<WarehouseBloc>().add(
          WarehouseMaterialDetailRequested(
            materialId: widget.materialId,
            material: widget.material,
          ),
        );
  }

  String _formatBalance(double balance) {
    return NumberFormat.decimalPattern().format(balance);
  }

  String _formatMovementDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String _movementTypeLabel(String type) {
    switch (type) {
      case 'RECEIPT':
        return 'Qabul';
      case 'ISSUANCE':
        return 'Berish';
      case 'CORRECTION_POSITIVE':
        return 'Tuzatish (+)';
      case 'CORRECTION_NEGATIVE':
        return 'Tuzatish (-)';
      default:
        return type;
    }
  }

  Color _movementTypeColor(String type) {
    switch (type) {
      case 'RECEIPT':
      case 'CORRECTION_POSITIVE':
        return AppColors.success;
      case 'ISSUANCE':
      case 'CORRECTION_NEGATIVE':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  IconData _movementTypeIcon(String type) {
    switch (type) {
      case 'RECEIPT':
      case 'CORRECTION_POSITIVE':
        return CupertinoIcons.arrow_down_circle_fill;
      case 'ISSUANCE':
      case 'CORRECTION_NEGATIVE':
        return CupertinoIcons.arrow_up_circle_fill;
      default:
        return CupertinoIcons.circle;
    }
  }

  void _showReceiptSheet() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => const ReceiptBottomSheet(),
    );
  }

  void _showIssuanceSheet() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => const IssuanceBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return BlocConsumer<WarehouseBloc, WarehouseState>(
      listener: (context, state) {
        if (state.actionSuccess) {
          AppToast.show(context, message: 'Amal muvaffaqiyatli bajarildi');
          context.read<WarehouseBloc>().add(const WarehouseResetAction());
        }
        if (state.actionError != null) {
          AppToast.show(context,
              message: state.actionError!, type: ToastType.error);
        }
      },
      builder: (context, state) {
        final material = widget.material ??
            state.selectedMaterial ??
            state.materials
                .where((m) => m.id == widget.materialId)
                .firstOrNull;

        if (material == null) {
          return const Center(
            child: CupertinoActivityIndicator(),
          );
        }

        final balance = state.balance?.balance ?? material.balance;
        final unit = state.balance?.unit.isNotEmpty == true
            ? state.balance!.unit
            : material.unit;
        final initials = material.name
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase();

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                context.read<WarehouseBloc>().add(
                      WarehouseMaterialDetailRequested(
                        materialId: widget.materialId,
                        material: material,
                      ),
                    );
              },
            ),
            SliverPadding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 40,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Material info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          isDark ? AppColors.cardDark : AppColors.cardLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? const Color(0x1AFFFFFF)
                            : const Color(0x0F000000),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black
                              .withOpacity(isDark ? 0.2 : 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials.isNotEmpty ? initials : '?',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              inherit: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                material.name,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.labelDark
                                      : AppColors.labelLight,
                                  inherit: true,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.number,
                                    size: 11,
                                    color: isDark
                                        ? AppColors.labelSecondary
                                        : AppColors.secondaryLabelLight,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    material.code,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.labelSecondary
                                          : AppColors.secondaryLabelLight,
                                      inherit: true,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF2C2C2E)
                                          : const Color(0xFFF2F2F7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      material.category ?? 'Kategoriyasiz',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.labelSecondary
                                            : AppColors.secondaryLabelLight,
                                        inherit: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            primaryColor.withOpacity(0.15),
                                      ),
                                    ),
                                    child: Text(
                                      material.unit,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                        inherit: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Balance card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: material.isLowStock
                            ? [AppColors.warning, AppColors.warningDark]
                            : [AppColors.success, const Color(0xFF00A885)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: (material.isLowStock
                                  ? AppColors.warning
                                  : AppColors.success)
                              .withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
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
                              'Joriy qoldiq',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.white.withOpacity(0.9),
                                inherit: true,
                              ),
                            ),
                            if (state.detailLoading)
                              const CupertinoActivityIndicator(
                                color: CupertinoColors.white,
                              )
                            else
                              Icon(
                                CupertinoIcons.cube_box_fill,
                                color: CupertinoColors.white.withOpacity(0.9),
                                size: 22,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _formatBalance(balance),
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: CupertinoColors.white,
                            inherit: true,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          unit,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.white.withOpacity(0.85),
                            inherit: true,
                          ),
                        ),
                        if (material.isLowStock) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: CupertinoColors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.exclamationmark_triangle_fill,
                                  color: CupertinoColors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Kam qoldiq: ${material.minQuantity != null ? _formatBalance(material.minQuantity!) : ''} ${material.unit}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: CupertinoColors.white,
                                    inherit: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: state.actionLoading
                              ? null
                              : _showReceiptSheet,
                          child: Container(
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.success.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  CupertinoIcons.arrow_down_circle_fill,
                                  color: AppColors.success,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Qabul qilish',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                    inherit: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: state.actionLoading
                              ? null
                              : _showIssuanceSheet,
                          child: Container(
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.error.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  CupertinoIcons.arrow_up_circle_fill,
                                  color: AppColors.error,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Berish',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error,
                                    inherit: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Recent movements header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'So\'nggi harakatlar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.labelDark
                              : AppColors.labelLight,
                          inherit: true,
                        ),
                      ),
                      if (state.detailLoading)
                        const CupertinoActivityIndicator(radius: 8)
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (state.detailError != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            CupertinoIcons.info_circle,
                            color: AppColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              state.detailError!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.error,
                                inherit: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (state.movements.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.arrow_right_arrow_left_circle,
                            size: 48,
                            color: isDark
                                ? AppColors.labelTertiary
                                : AppColors.secondaryLabelLight,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Harakatlar yo\'q',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.labelDark
                                  : AppColors.labelLight,
                              inherit: true,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...state.movements.map((movement) {
                      final color = _movementTypeColor(movement.type);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
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
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                _movementTypeIcon(movement.type),
                                color: color,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _movementTypeLabel(movement.type),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? AppColors.labelDark
                                              : AppColors.labelLight,
                                          inherit: true,
                                        ),
                                      ),
                                      if (movement.isFlagged) ...[
                                        const SizedBox(width: 8),
                                        Icon(
                                          CupertinoIcons
                                              .exclamationmark_triangle_fill,
                                          size: 12,
                                          color: AppColors.warningDark,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatMovementDate(movement.movementDate),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.labelSecondary
                                          : AppColors.secondaryLabelLight,
                                      inherit: true,
                                    ),
                                  ),
                                  if (movement.supplierName != null &&
                                      movement.supplierName!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Yetkazib beruvchi: ${movement.supplierName}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? AppColors.labelSecondary
                                              : AppColors.secondaryLabelLight,
                                          inherit: true,
                                        ),
                                      ),
                                    ),
                                  if (movement.destination != null &&
                                      movement.destination!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Yo\'nalish: ${movement.destination}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? AppColors.labelSecondary
                                              : AppColors.secondaryLabelLight,
                                          inherit: true,
                                        ),
                                      ),
                                    ),
                                  if (movement.note != null &&
                                      movement.note!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        movement.note!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: isDark
                                              ? AppColors.labelSecondary
                                              : AppColors.secondaryLabelLight,
                                          inherit: true,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${movement.type == 'ISSUANCE' || movement.type == 'CORRECTION_NEGATIVE' ? '-' : '+'}${_formatBalance(movement.quantity)}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: color,
                                inherit: true,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}
