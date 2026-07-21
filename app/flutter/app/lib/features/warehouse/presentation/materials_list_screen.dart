import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/core/widgets/app_toast.dart';
import 'package:texerp/features/warehouse/presentation/warehouse_bloc.dart';

class MaterialsListScreen extends StatefulWidget {
  const MaterialsListScreen({super.key});

  @override
  State<MaterialsListScreen> createState() => _MaterialsListScreenState();
}

class _MaterialsListScreenState extends State<MaterialsListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadMaterials() {
    context.read<WarehouseBloc>().add(
          WarehouseMaterialsLoadRequested(search: _searchQuery),
        );
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim();
    });
    _loadMaterials();
  }

  String _formatBalance(double balance) {
    return NumberFormat.decimalPattern().format(balance);
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
        if (state.materialsLoading && state.materials.isEmpty) {
          return const Center(
            child: CupertinoActivityIndicator(),
          );
        }

        if (state.materialsError != null && state.materials.isEmpty) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async => _loadMaterials(),
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
                          'Materiallarni yuklashda xatolik',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.labelDark
                                : AppColors.labelLight,
                            inherit: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.materialsError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.labelSecondary
                                : AppColors.secondaryLabelLight,
                            inherit: true,
                          ),
                        ),
                        const SizedBox(height: 20),
                        CupertinoButton(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          onPressed: _loadMaterials,
                          child: const Text('Qayta urinish'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        if (state.materials.isEmpty) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async => _loadMaterials(),
              ),
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.cube_box,
                          size: 64,
                          color: isDark
                              ? AppColors.labelTertiary
                              : AppColors.secondaryLabelLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Materiallar yo\'q',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.labelDark
                                : AppColors.labelLight,
                            inherit: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Omborda hozircha hech qanday material mavjud emas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.labelSecondary
                                : AppColors.secondaryLabelLight,
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
              onRefresh: () async => _loadMaterials(),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 100,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CupertinoTextField(
                          controller: _searchController,
                          placeholder: 'Qidirish...',
                          placeholderStyle: TextStyle(
                            color: isDark
                                ? AppColors.labelTertiary
                                : AppColors.secondaryLabelLight,
                            fontSize: 14,
                            inherit: true,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          clearButtonMode: OverlayVisibilityMode.editing,
                          onChanged: _onSearchChanged,
                          prefix: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Icon(
                              CupertinoIcons.search,
                              size: 18,
                              color: isDark
                                  ? AppColors.labelSecondary
                                  : AppColors.secondaryLabelLight,
                            ),
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2C2C2E)
                                : const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0x1AFFFFFF)
                                  : const Color(0x0F000000),
                            ),
                          ),
                          style: TextStyle(
                            color: isDark
                                ? AppColors.labelDark
                                : AppColors.labelLight,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }
                    final material = state.materials[index - 1];
                    final initials = material.name
                        .split(' ')
                        .map((e) => e.isNotEmpty ? e[0] : '')
                        .take(2)
                        .join()
                        .toUpperCase();

                    return GestureDetector(
                      onTap: () => context.push(
                        '/warehouse/materials/${material.id}',
                        extra: material,
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
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
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials.isNotEmpty ? initials : '?',
                                style: TextStyle(
                                  fontSize: 13,
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
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? AppColors.labelDark
                                          : AppColors.labelLight,
                                      inherit: true,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
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
                                      if (material.category != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF2C2C2E)
                                                : const Color(0xFFF2F2F7),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            material.category!,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? AppColors.labelSecondary
                                                  : AppColors
                                                      .secondaryLabelLight,
                                              inherit: true,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${_formatBalance(material.balance)} ${material.unit}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: material.isLowStock
                                        ? AppColors.warningDark
                                        : AppColors.success,
                                    inherit: true,
                                  ),
                                ),
                                if (material.isLowStock)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Kam qoldi',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.warningDark,
                                        inherit: true,
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
                  childCount: state.materials.length + 1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
