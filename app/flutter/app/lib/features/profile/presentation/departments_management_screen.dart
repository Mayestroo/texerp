import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/core/widgets/app_toast.dart';
import 'package:texerp/features/auth/data/auth_models.dart';
import 'package:texerp/features/profile/presentation/departments_bloc.dart';

class DepartmentsManagementScreen extends StatefulWidget {
  const DepartmentsManagementScreen({super.key});

  @override
  State<DepartmentsManagementScreen> createState() =>
      _DepartmentsManagementScreenState();
}

class _DepartmentsManagementScreenState
    extends State<DepartmentsManagementScreen> {
  bool _includeInactive = false;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  void _loadDepartments() {
    context
        .read<DepartmentsBloc>()
        .add(DepartmentsLoadRequested(includeInactive: _includeInactive));
  }

  void _showAddSheet() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    String? selectedForemanId;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

        return BlocProvider<DepartmentsBloc>.value(
          value: this.context.read<DepartmentsBloc>(),
          child: BlocBuilder<DepartmentsBloc, DepartmentsState>(
            builder: (context, state) {
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
                                    'Yangi bo\'lim qo\'shish',
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
                            
                            // Name Input
                            Text(
                              'Bo\'lim nomi',
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
                              placeholder: 'Masalan: Tikuv sexi',
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

                            // Code Input
                            Text(
                              'Bo\'lim kodi',
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
                              placeholder: 'Masalan: SEW-01',
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

                            // Foreman selection
                            Text(
                              'Mas\'ul prorab',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                  fontWeight: FontWeight.w600,
                                  inherit: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (state.foremen.isEmpty)
                                Text(
                                  'Prorablar topilmadi. Avval prorab qo\'shish lozim.',
                                  style: TextStyle(fontSize: 13, color: AppColors.error, inherit: true),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: state.foremen.map((foreman) {
                                    final isSelected = selectedForemanId == foreman.id;
                                    return GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          selectedForemanId = foreman.id;
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
                                              foreman.fullName,
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

                            const SizedBox(height: 24),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                final name = nameController.text.trim();
                                final code = codeController.text.trim();
                                if (name.isEmpty) {
                                  AppToast.show(context, message: 'Bo\'lim nomini kiriting', type: ToastType.error);
                                    return;
                                }
                                if (code.isEmpty) {
                                  AppToast.show(context, message: 'Bo\'lim kodini kiriting', type: ToastType.error);
                                    return;
                                }
                                if (selectedForemanId == null) {
                                  AppToast.show(context, message: 'Prorabni tanlang', type: ToastType.error);
                                    return;
                                }
                                Navigator.of(context).pop();
                                this.context.read<DepartmentsBloc>().add(
                                      DepartmentsCreateRequested(
                                        name: name,
                                        code: code,
                                        foremanId: selectedForemanId!,
                                      ),
                                    );
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
                                child: const Text(
                                  'Bo\'limni yaratish',
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
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showEditSheet(Department dept) {
    final nameController = TextEditingController(text: dept.name);
    final codeController = TextEditingController(text: dept.code ?? '');
    String? selectedForemanId;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

        return BlocProvider<DepartmentsBloc>.value(
          value: this.context.read<DepartmentsBloc>(),
          child: BlocBuilder<DepartmentsBloc, DepartmentsState>(
            builder: (context, state) {
              // Resolve foreman ID from name on first build
              if (selectedForemanId == null && dept.foremanName != null) {
                final match = state.foremen.where(
                    (f) => f.fullName == dept.foremanName);
                if (match.isNotEmpty) {
                  selectedForemanId = match.first.id;
                }
              }

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
                                    'Bo\'limni tahrirlash',
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
                            
                            // Name Input
                            Text(
                              'Bo\'lim nomi',
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
                              placeholder: 'Bo\'lim nomi',
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

                            // Code Input
                            Text(
                              'Bo\'lim kodi',
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
                              placeholder: 'Bo\'lim kodi',
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

                            // Foreman selection
                            Text(
                              'Mas\'ul prorab',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                fontWeight: FontWeight.w600,
                                inherit: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (state.foremen.isEmpty)
                              Text(
                                'Prorablar topilmadi. Avval prorab qo\'shish lozim.',
                                style: TextStyle(fontSize: 13, color: AppColors.error, inherit: true),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: state.foremen.map((foreman) {
                                  final isSelected = selectedForemanId == foreman.id;
                                  return GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        selectedForemanId = foreman.id;
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
                                            foreman.fullName,
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

                            const SizedBox(height: 24),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                final name = nameController.text.trim();
                                final code = codeController.text.trim();
                                if (name.isEmpty) {
                                  AppToast.show(context, message: 'Bo\'lim nomini kiriting', type: ToastType.error);
                                    return;
                                }
                                if (code.isEmpty) {
                                  AppToast.show(context, message: 'Bo\'lim kodini kiriting', type: ToastType.error);
                                    return;
                                }
                                if (selectedForemanId == null) {
                                  AppToast.show(context, message: 'Prorabni tanlang', type: ToastType.error);
                                    return;
                                }
                                Navigator.of(context).pop();
                                this.context.read<DepartmentsBloc>().add(
                                      DepartmentsUpdateRequested(
                                        id: dept.id,
                                        name: name != dept.name ? name : null,
                                        code: code != (dept.code ?? '') ? code : null,
                                        foremanId: selectedForemanId,
                                      ),
                                    );
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
                                child: const Text(
                                  'Saqlash',
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
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _toggleStatus(Department dept) {
    final currentActive = dept.isActive ?? true;
    context.read<DepartmentsBloc>().add(
          DepartmentsToggleStatusRequested(
            id: dept.id,
            currentActive: currentActive,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return BlocConsumer<DepartmentsBloc, DepartmentsState>(
      listener: (context, state) {
        if (state.actionSuccess) {
          AppToast.show(context,
              message: 'Muvaffaqiyatli bajarildi!', type: ToastType.success);
          _loadDepartments();
        } else if (state.actionError != null) {
          AppToast.show(context,
              message: state.actionError!, type: ToastType.error);
        }
      },
      builder: (context, state) {
        final isBusy = state.isLoading && state.departments.isEmpty;

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                _loadDepartments();
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Barcha bo\'limlar',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.labelDark
                              : AppColors.labelLight,
                          inherit: true,
                        ),
                      ),
                    ),
                    // Status Filter Button
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        showCupertinoModalPopup<void>(
                          context: context,
                          builder: (BuildContext context) {
                            return CupertinoActionSheet(
                              title: const Text('Holat bo\'yicha saralash'),
                              actions: [
                                CupertinoActionSheetAction(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    setState(() {
                                      _includeInactive = false;
                                    });
                                    _loadDepartments();
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(CupertinoIcons.checkmark_circle_fill, color: AppColors.success, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Faollar',
                                        style: TextStyle(
                                          fontWeight: !_includeInactive ? FontWeight.bold : FontWeight.normal,
                                          color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                CupertinoActionSheetAction(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    setState(() {
                                      _includeInactive = true;
                                    });
                                    _loadDepartments();
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(CupertinoIcons.eye_slash_fill, color: AppColors.labelTertiary, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Hammasi (Faol/Nofaol)',
                                        style: TextStyle(
                                          fontWeight: _includeInactive ? FontWeight.bold : FontWeight.normal,
                                          color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              cancelButton: CupertinoActionSheetAction(
                                onPressed: () => Navigator.pop(context),
                                isDefaultAction: true,
                                child: const Text('Bekor qilish'),
                              ),
                            );
                          },
                        );
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _includeInactive
                              ? AppColors.primary.withOpacity(0.1)
                              : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _includeInactive ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                          color: _includeInactive ? AppColors.primary : (isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight),
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _showAddSheet(),
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
            if (isBusy)
              const SliverFillRemaining(
                child: Center(child: CupertinoActivityIndicator()),
              )
            else if (state.error != null && state.departments.isEmpty)
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
                            onPressed: _loadDepartments,
                            child: const Text('Qayta yuklash'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else if (state.departments.isEmpty)
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
                            CupertinoIcons.square_list,
                            size: 64,
                            color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Bo\'limlar ro\'yxati bo\'sh',
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
                            'Hozircha birorta ham bo\'lim qo\'shilmagan.',
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
                      final dept = state.departments[index];
                      final isCurrentBusy = state.actionInProgressId == dept.id;
                      final initials = dept.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
                      final isDeptActive = dept.isActive ?? true;

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
                                    onTap: () => _showEditSheet(dept),
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
                                      onTap: () => _showEditSheet(dept),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  dept.name,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                                    inherit: true,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (!isDeptActive)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.error.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    'Faolsiz',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.error,
                                                      inherit: true,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(CupertinoIcons.number, size: 12, color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight),
                                              const SizedBox(width: 4),
                                              Text(
                                                dept.code ?? 'Kodsiz',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                                  inherit: true,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Icon(CupertinoIcons.person_crop_circle, size: 12, color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  dept.foremanName ?? 'Mas\'ul biriktirilmagan',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                                    inherit: true,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
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
                                      onPressed: () => _toggleStatus(dept),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isDeptActive
                                              ? AppColors.error.withOpacity(0.08)
                                              : AppColors.success.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isDeptActive
                                                ? AppColors.error.withOpacity(0.15)
                                                : AppColors.success.withOpacity(0.15),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isDeptActive ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                                              size: 13,
                                              color: isDeptActive ? AppColors.error : AppColors.success,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isDeptActive ? 'Faolsizlash' : 'Faollash',
                                              style: TextStyle(
                                                color: isDeptActive ? AppColors.error : AppColors.success,
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
                              
                              // Workers Count Badge Strip
                              if (dept.workerCount != null && dept.workerCount! > 0) ...[
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
                                      const Icon(CupertinoIcons.person_3, size: 14, color: AppColors.success),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${dept.workerCount} nafar xodim',
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
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: state.departments.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
