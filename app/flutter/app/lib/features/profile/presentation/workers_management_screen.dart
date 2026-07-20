import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/core/widgets/app_toast.dart';
import 'package:texerp/features/auth/data/auth_models.dart';
import 'package:texerp/features/profile/presentation/workers_bloc.dart';

class WorkersManagementScreen extends StatefulWidget {
  const WorkersManagementScreen({super.key});

  @override
  State<WorkersManagementScreen> createState() => _WorkersManagementScreenState();
}

class _WorkersManagementScreenState extends State<WorkersManagementScreen> {
  String? _selectedRole = 'WORKER'; // Defaults to WORKER
  String _selectedStatus = 'ACTIVE';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
    // Pre-fetch departments and foremen list for assignments
    context.read<WorkersBloc>().add(const WorkersLoadAssistanceDataRequested());
  }

  void _loadUsers() {
    context.read<WorkersBloc>().add(WorkersLoadRequested(
          role: _selectedRole,
          status: _selectedStatus,
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
        ));
  }

  String _formatRole(String role) {
    switch (role) {
      case 'WORKER':
        return 'Ishchi';
      case 'FOREMAN':
        return 'Prorab';
      case 'ACCOUNTANT':
        return 'Buxgalter';
      case 'DIRECTOR':
        return 'Direktor';
      default:
        return role;
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

  void _showAddSheet() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController(text: '+998');
    final codeController = TextEditingController();
    final pinController = TextEditingController();
    String role = 'WORKER';

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Yangi xodim qo\'shish',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                inherit: true,
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
                      // Name
                      Text(
                        'Ism-sharif (F.I.SH)',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                          fontWeight: FontWeight.w500,
                          inherit: true,
                        ),
                      ),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: nameController,
                        placeholder: 'Masalan: Ali Valiyev',
                      ),
                      const SizedBox(height: 12),
                      // Phone
                      Text(
                        'Telefon raqami',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                          fontWeight: FontWeight.w500,
                          inherit: true,
                        ),
                      ),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        placeholder: '+998XXXXXXXXX',
                      ),
                      const SizedBox(height: 12),
                      // Worker Code
                      Text(
                        'Ishchi kodi (Tizimdagi logini)',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                          fontWeight: FontWeight.w500,
                          inherit: true,
                        ),
                      ),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: codeController,
                        placeholder: 'Masalan: ali_valiyev',
                      ),
                      const SizedBox(height: 12),
                      // Initial PIN
                      Text(
                        'Boshlang\'ich PIN kod (4 ta raqam)',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                          fontWeight: FontWeight.w500,
                          inherit: true,
                        ),
                      ),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        placeholder: 'Masalan: 1111',
                        maxLength: 4,
                      ),
                      const SizedBox(height: 12),
                      // Role Segment
                      Text(
                        'Tizimdagi roli',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                          fontWeight: FontWeight.w500,
                          inherit: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoSlidingSegmentedControl<String>(
                          groupValue: role,
                          children: const {
                            'WORKER': Text('Ishchi'),
                            'FOREMAN': Text('Prorab'),
                            'ACCOUNTANT': Text('Buxgalter'),
                          },
                          onValueChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                role = val;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Submit button
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          final fullName = nameController.text.trim();
                          final phone = phoneController.text.trim();
                          final code = codeController.text.trim();
                          final pin = pinController.text.trim();

                          if (fullName.isEmpty) {
                            AppToast.show(context, message: 'Ismni kiriting', type: ToastType.error);
                            return;
                          }
                          if (!RegExp(r'^\+998\d{9}$').hasMatch(phone)) {
                            AppToast.show(context, message: 'Telefon formati xato (+998XXXXXXXXX)', type: ToastType.error);
                            return;
                          }
                          if (code.isEmpty) {
                            AppToast.show(context, message: 'Ishchi kodini kiriting', type: ToastType.error);
                            return;
                          }
                          if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
                            AppToast.show(context, message: 'PIN kod 4 ta raqam bo\'lishi shart', type: ToastType.error);
                            return;
                          }

                          Navigator.of(context).pop();

                          this.context.read<WorkersBloc>().add(
                                WorkersCreateRequested(
                                  fullName: fullName,
                                  phone: phone,
                                  workerCode: code,
                                  role: role,
                                  initialPin: pin,
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
                            'Xodimni yaratish',
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
              ),
            );
          },
        );
      },
    );
  }

  void _showEditOrAssignSheet(UserProfile user) {
    final nameController = TextEditingController(text: user.fullName);
    String? selectedDeptId = user.department?.id;

    // Always refresh departments so newly created ones appear
    context.read<WorkersBloc>().add(const WorkersLoadAssistanceDataRequested());

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

        return BlocProvider<WorkersBloc>.value(
          value: this.context.read<WorkersBloc>(),
          child: BlocBuilder<WorkersBloc, WorkersState>(
            builder: (context, state) {
            final deptsAvailable = state.departments.isNotEmpty;
            final selectedDept = selectedDeptId != null
                ? state.departments.where((d) => d.id == selectedDeptId).firstOrNull
                : null;

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
                    final deptsAvailable = state.departments.isNotEmpty;
                    final selectedDept = selectedDeptId != null
                        ? state.departments.where((d) => d.id == selectedDeptId).firstOrNull
                        : null;

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
                                  user.role == 'WORKER' ? 'Ishchini tahrirlash' : 'Prorabni tahrirlash',
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
                            'F.I.SH',
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
                            placeholder: 'Ism-sharif',
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            clearButtonMode: OverlayVisibilityMode.editing,
                            prefix: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Icon(
                                CupertinoIcons.person,
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
                          
                          // Role-specific assignment
                          if (user.role == 'WORKER') ...[
                            const SizedBox(height: 20),
                            Text(
                              'Bo\'lim biriktirish',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                inherit: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (state.isAssistanceLoading)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(child: CupertinoActivityIndicator()),
                              )
                            else if (!deptsAvailable)
                              Text(
                                'Bo\'limlar topilmadi. Avval bo\'lim qo\'shish lozim.',
                                style: TextStyle(fontSize: 13, color: AppColors.error, inherit: true),
                              )
                            else ...[
                              // Inline select chips
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: state.departments.map((dept) {
                                  final isSelected = selectedDeptId == dept.id;
                                  return GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        selectedDeptId = dept.id;
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
                                            dept.name,
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
                              
                              // Foreman Info Card
                              if (selectedDept != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF8F9FA),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? const Color(0x11FFFFFF) : const Color(0x11000000),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          CupertinoIcons.person_crop_circle_fill,
                                          size: 20,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Mas\'ul Prorab:',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                                fontWeight: FontWeight.w600,
                                                inherit: true,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              selectedDept.foremanName ?? "Biriktirilmagan",
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                                inherit: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selectedDept.foremanName == null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: AppColors.error, size: 14),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Bu bo\'limda faol prorab mavjud emas!',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.error,
                                            fontWeight: FontWeight.w500,
                                            inherit: true,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ],
                          ],
                          
                          const SizedBox(height: 24),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                AppToast.show(context, message: 'Ismni to\'ldiring', type: ToastType.error);
                                return;
                              }
                              if (user.role == 'WORKER' && selectedDeptId == null) {
                                AppToast.show(context, message: 'Bo\'limni tanlang', type: ToastType.error);
                                return;
                              }

                              Navigator.of(context).pop();

                              if (name != user.fullName) {
                                this.context.read<WorkersBloc>().add(
                                      WorkersUpdateRequested(id: user.id, fullName: name),
                                    );
                              }

                              if (user.role == 'WORKER' && selectedDeptId != null) {
                                  if (selectedDeptId != user.department?.id) {
                                    this.context.read<WorkersBloc>().add(
                                          WorkersAssignForemanRequested(
                                            workerId: user.id,
                                            foremanId: '',
                                            departmentId: selectedDeptId!,
                                          ),
                                        );
                                  }
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

  void _toggleUserStatus(UserProfile user) {
    context.read<WorkersBloc>().add(
          WorkersToggleStatusRequested(
            id: user.id,
            currentActive: user.status == 'ACTIVE',
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return BlocConsumer<WorkersBloc, WorkersState>(
      listener: (context, state) {
        if (state.actionSuccess) {
          AppToast.show(context, message: 'Muvaffaqiyatli bajarildi!', type: ToastType.success);
          _loadUsers();
        } else if (state.actionError != null) {
          AppToast.show(context, message: state.actionError!, type: ToastType.error);
        }
      },
      builder: (context, state) {
        final isBusy = state.isLoading && state.users.isEmpty;

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                _loadUsers();
              },
            ),
            // Header search, filter & add button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        placeholder: 'Ism, kod yoki telefon...',
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
                          _loadUsers();
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
                                      _selectedStatus = 'ACTIVE';
                                    });
                                    _loadUsers();
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(CupertinoIcons.checkmark_circle_fill, color: AppColors.success, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Faollar',
                                        style: TextStyle(
                                          fontWeight: _selectedStatus == 'ACTIVE' ? FontWeight.bold : FontWeight.normal,
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
                                      _selectedStatus = 'DEACTIVATED';
                                    });
                                    _loadUsers();
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(CupertinoIcons.clear_circled_solid, color: AppColors.error, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Faolsizlar',
                                        style: TextStyle(
                                          fontWeight: _selectedStatus == 'DEACTIVATED' ? FontWeight.bold : FontWeight.normal,
                                          color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              cancelButton: CupertinoActionSheetAction(
                                isDefaultAction: true,
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Yopish'),
                              ),
                            );
                          },
                        );
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _selectedStatus == 'DEACTIVATED'
                              ? AppColors.error.withOpacity(0.1)
                              : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.slider_horizontal_3,
                          color: _selectedStatus == 'DEACTIVATED'
                              ? AppColors.error
                              : (isDark ? AppColors.labelDark : AppColors.labelLight),
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Add Button
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
            // Segment switch for Roles
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Row(
                  children: [
                    _buildPillTab(
                      label: 'Ishchilar',
                      isSelected: _selectedRole == 'WORKER',
                      onTap: () {
                        setState(() {
                          _selectedRole = 'WORKER';
                        });
                        _loadUsers();
                      },
                      isDark: isDark,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(width: 8),
                    _buildPillTab(
                      label: 'Prorablar',
                      isSelected: _selectedRole == 'FOREMAN',
                      onTap: () {
                        setState(() {
                          _selectedRole = 'FOREMAN';
                        });
                        _loadUsers();
                      },
                      isDark: isDark,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(width: 8),
                    _buildPillTab(
                      label: 'Buxgalterlar',
                      isSelected: _selectedRole == 'ACCOUNTANT',
                      onTap: () {
                        setState(() {
                          _selectedRole = 'ACCOUNTANT';
                        });
                        _loadUsers();
                      },
                      isDark: isDark,
                      primaryColor: primaryColor,
                    ),
                  ],
                ),
              ),
            ),
            // Active Filter Chip when Deactivated status is selected
            if (_selectedStatus == 'DEACTIVATED')
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.error.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.clear_circled_solid, size: 14, color: AppColors.error),
                            const SizedBox(width: 6),
                            const Text(
                              'Faolsizlar filtri faol',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedStatus = 'ACTIVE';
                                });
                                _loadUsers();
                              },
                              child: Icon(
                                CupertinoIcons.clear,
                                size: 12,
                                color: AppColors.error.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
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
            else if (state.error != null && state.users.isEmpty)
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
                            onPressed: _loadUsers,
                            child: const Text('Qayta yuklash'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else if (state.users.isEmpty)
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
                            CupertinoIcons.person_2,
                            size: 64,
                            color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty ? 'Xodimlar ro\'yxati bo\'sh' : 'Xodimlar topilmadi',
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
                                ? 'Hozircha birorta ham xodim qo\'shilmagan.'
                                : 'Qidiruv shartlariga mos xodim topilmadi.',
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
                      final user = state.users[index];
                      final isCurrentBusy = state.actionInProgressId == user.id;
                      final userActive = user.status == 'ACTIVE';

                      final initials = user.fullName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

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
                                    onTap: () => _showEditOrAssignSheet(user),
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
                                  
                                  // User Details Column
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _showEditOrAssignSheet(user),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  user.fullName,
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
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: primaryColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  _formatRole(user.role),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: primaryColor,
                                                    inherit: true,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(CupertinoIcons.barcode, size: 12, color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight),
                                              const SizedBox(width: 4),
                                              Text(
                                                user.workerCode,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                                  inherit: true,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Icon(CupertinoIcons.phone, size: 12, color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  user.phone,
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
                                      onPressed: () => _toggleUserStatus(user),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: userActive
                                              ? AppColors.error.withOpacity(0.08)
                                              : AppColors.success.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: userActive
                                                ? AppColors.error.withOpacity(0.15)
                                                : AppColors.success.withOpacity(0.15),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              userActive ? CupertinoIcons.person_crop_circle_badge_xmark : CupertinoIcons.person_crop_circle_badge_checkmark,
                                              size: 13,
                                              color: userActive ? AppColors.error : AppColors.success,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              userActive ? 'Faolsizlash' : 'Faollash',
                                              style: TextStyle(
                                                color: userActive ? AppColors.error : AppColors.success,
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
                              
                              // Department & Foreman bottom metadata strip
                              if (user.role == 'WORKER' && (user.foreman != null || user.department != null)) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(CupertinoIcons.briefcase, size: 12, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        user.department?.name ?? 'Bo\'limsiz',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                          inherit: true,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        width: 1,
                                        height: 12,
                                        color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFC7C7CC),
                                      ),
                                      const SizedBox(width: 12),
                                      const Icon(CupertinoIcons.person_crop_circle, size: 12, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          user.foreman?.fullName ?? 'Prorabsiz',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                            inherit: true,
                                          ),
                                          overflow: TextOverflow.ellipsis,
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
                    childCount: state.users.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
