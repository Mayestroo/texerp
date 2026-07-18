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
              height: MediaQuery.of(context).size.height * 0.75,
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
                            'Yangi xodim qo\'shish',
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
                    // Name
                    Text(
                      'Ism-sharif (F.I.SH)',
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
                        inherit: false,
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
                        inherit: false,
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
                        inherit: false,
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
                        inherit: false,
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
                    const Spacer(),
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
            );
          },
        );
      },
    );
  }

  void _showEditOrAssignSheet(UserProfile user) {
    final nameController = TextEditingController(text: user.fullName);
    String? selectedDeptId = user.department?.id;

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
              height: MediaQuery.of(context).size.height * 0.6,
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
                child: StatefulBuilder(
                  builder: (context, setModalState) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Xodimni tahrirlash',
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
                        Text(
                          'Ism-sharif (F.I.SH)',
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
                          placeholder: 'F.I.SH',
                        ),
                        const SizedBox(height: 20),
                        if (user.role == 'WORKER') ...[
                          Text(
                            'Bo\'lim biriktirish',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.labelDark : AppColors.labelLight,
                              inherit: false,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (state.isAssistanceLoading)
                            const Center(child: CupertinoActivityIndicator())
                          else if (!deptsAvailable)
                            Text(
                              'Bo\'limlar topilmadi. Avval bo\'lim qo\'shish lozim.',
                              style: TextStyle(fontSize: 13, color: AppColors.error, inherit: false),
                            )
                          else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Sex / Bo\'lim:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                    inherit: false,
                                  ),
                                ),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: Text(
                                    selectedDeptId == null
                                        ? 'Tanlang'
                                        : selectedDept?.name ?? 'Noma\'lum',
                                  ),
                                  onPressed: () {
                                    showCupertinoModalPopup<void>(
                                      context: context,
                                      builder: (context) {
                                        return Container(
                                          height: 250,
                                          color: CupertinoColors.systemBackground.resolveFrom(context),
                                          child: CupertinoPicker(
                                            itemExtent: 32,
                                            onSelectedItemChanged: (index) {
                                              setModalState(() {
                                                selectedDeptId = state.departments[index].id;
                                              });
                                            },
                                            children: state.departments.map((d) => Center(child: Text(d.name))).toList(),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                            if (selectedDept != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(CupertinoIcons.person_fill, size: 14,
                                    color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Prorab: ${selectedDept.foremanName ?? "Biriktirilmagan"}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                      inherit: false,
                                    ),
                                  ),
                                ],
                              ),
                              if (selectedDept.foremanName == null)
                                Text(
                                  'Bu bo\'limga prorab biriktirilmagan. Avval bo\'limni tahrirlang.',
                                  style: TextStyle(fontSize: 12, color: AppColors.error, inherit: false),
                                ),
                            ],
                          ],
                        ],
                        const Spacer(),
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
                              borderRadius: BorderRadius.circular(14),
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
            // Header search & add button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoSearchTextField(
                        placeholder: 'Ism, kod yoki telefon...',
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                          _loadUsers();
                        },
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
            // Segment switch for Roles
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<String>(
                    groupValue: _selectedRole,
                    children: const {
                      'WORKER': Text('Ishchilar'),
                      'FOREMAN': Text('Prorablar'),
                    },
                    onValueChanged: (val) {
                      setState(() {
                        _selectedRole = val;
                      });
                      _loadUsers();
                    },
                  ),
                ),
              ),
            ),
            // Segment switch for Status
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<String>(
                    groupValue: _selectedStatus,
                    children: const {
                      'ACTIVE': Text('Faollar'),
                      'DEACTIVATED': Text('Faolsizlar'),
                    },
                    onValueChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedStatus = val;
                        });
                        _loadUsers();
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
            else if (state.error != null && state.users.isEmpty)
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
                          onPressed: _loadUsers,
                          child: const Text('Qayta yuklash'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (state.users.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
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
                            inherit: false,
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
                      final user = state.users[index];
                      final isCurrentBusy = state.actionInProgressId == user.id;
                      final userActive = user.status == 'ACTIVE';

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
                                  onTap: () => _showEditOrAssignSheet(user),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            user.fullName,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                              inherit: false,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _formatRole(user.role),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: primaryColor,
                                                inherit: false,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              user.workerCode,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                                inherit: false,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            user.phone,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                              inherit: false,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (user.role == 'WORKER' && (user.foreman != null || user.department != null)) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Prorab: ${user.foreman?.fullName ?? "Biriktirilmagan"} | Bo\'lim: ${user.department?.name ?? "Biriktirilmagan"}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                                            fontStyle: FontStyle.italic,
                                            inherit: false,
                                          ),
                                        ),
                                      ],
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
                                  onPressed: () => _toggleUserStatus(user),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: userActive
                                          ? AppColors.error.withOpacity(0.08)
                                          : AppColors.success.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: userActive
                                            ? AppColors.error.withOpacity(0.2)
                                            : AppColors.success.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Text(
                                      userActive ? 'Faolsizlash' : 'Faollash',
                                      style: TextStyle(
                                        color: userActive ? AppColors.error : AppColors.success,
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
