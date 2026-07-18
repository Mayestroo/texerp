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
  @override
  void initState() {
    super.initState();
    context.read<DepartmentsBloc>().add(const DepartmentsLoadRequested());
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
                                  'Yangi bo\'lim qo\'shish',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppColors.labelDark
                                        : AppColors.labelLight,
                                    inherit: false,
                                  ),
                                ),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: const Text('Bekor qilish'),
                                  onPressed: () =>
                                      Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bo\'lim nomi',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.labelSecondary
                                  : AppColors.secondaryLabelLight,
                              fontWeight: FontWeight.w500,
                              inherit: false,
                            ),
                          ),
                          const SizedBox(height: 6),
                          CupertinoTextField(
                            controller: nameController,
                            placeholder: 'Masalan: Tikuv sexi',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Bo\'lim kodi',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.labelSecondary
                                  : AppColors.secondaryLabelLight,
                              fontWeight: FontWeight.w500,
                              inherit: false,
                            ),
                          ),
                          const SizedBox(height: 6),
                          CupertinoTextField(
                            controller: codeController,
                            placeholder: 'Masalan: SEW-01',
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Mas\'ul prorab',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.labelSecondary
                                  : AppColors.secondaryLabelLight,
                              fontWeight: FontWeight.w500,
                              inherit: false,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1C1C1E)
                                          : CupertinoColors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0x33FFFFFF)
                                            : const Color(0x22000000),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            selectedForemanId == null
                                                ? 'Prorabni tanlang'
                                                : state.foremen
                                                    .firstWhere(
                                                      (f) =>
                                                          f.id ==
                                                          selectedForemanId,
                                                      orElse: () =>
                                                          UserProfile(
                                                              id: '',
                                                              fullName:
                                                                  'Noma\'lum',
                                                              phone: '',
                                                              workerCode: '',
                                                              role: '',
                                                              status: ''),
                                                    )
                                                    .fullName,
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: selectedForemanId == null
                                                  ? (isDark
                                                      ? AppColors
                                                          .labelTertiary
                                                      : AppColors
                                                          .secondaryLabelLight)
                                                  : (isDark
                                                      ? AppColors.labelDark
                                                      : AppColors.labelLight),
                                              inherit: false,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Icon(
                                          CupertinoIcons.chevron_down,
                                          size: 18,
                                          color: isDark
                                              ? AppColors.labelTertiary
                                              : AppColors.secondaryLabelLight,
                                        ),
                                      ],
                                    ),
                                  ),
                                  onPressed: () {
                                    if (state.foremen.isEmpty) {
                                      AppToast.show(context,
                                          message:
                                              'Avval prorab yarating',
                                          type: ToastType.error);
                                      return;
                                    }
                                    showCupertinoModalPopup<void>(
                                      context: context,
                                      builder: (context) {
                                        return Container(
                                          height: 250,
                                          color: CupertinoColors
                                              .systemBackground
                                              .resolveFrom(context),
                                          child: CupertinoPicker(
                                            itemExtent: 32,
                                            onSelectedItemChanged: (index) {
                                              setModalState(() {
                                                selectedForemanId =
                                                    state.foremen[index].id;
                                              });
                                            },
                                            children: state.foremen
                                                .map((f) => Center(
                                                    child: Text(f.fullName)))
                                                .toList(),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              final name = nameController.text.trim();
                              final code = codeController.text.trim();
                              if (name.isEmpty) {
                                AppToast.show(context,
                                    message: 'Bo\'lim nomini kiriting',
                                    type: ToastType.error);
                                return;
                              }
                              if (code.isEmpty) {
                                AppToast.show(context,
                                    message: 'Bo\'lim kodini kiriting',
                                    type: ToastType.error);
                                return;
                              }
                              if (selectedForemanId == null) {
                                AppToast.show(context,
                                    message: 'Prorabni tanlang',
                                    type: ToastType.error);
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
                                borderRadius: BorderRadius.circular(14),
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
                                  'Bo\'limni tahrirlash',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppColors.labelDark
                                        : AppColors.labelLight,
                                    inherit: false,
                                  ),
                                ),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: const Text('Bekor qilish'),
                                  onPressed: () =>
                                      Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bo\'lim nomi',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.labelSecondary
                                  : AppColors.secondaryLabelLight,
                              fontWeight: FontWeight.w500,
                              inherit: false,
                            ),
                          ),
                          const SizedBox(height: 6),
                          CupertinoTextField(
                            controller: nameController,
                            placeholder: 'Bo\'lim nomi',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Bo\'lim kodi',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.labelSecondary
                                  : AppColors.secondaryLabelLight,
                              fontWeight: FontWeight.w500,
                              inherit: false,
                            ),
                          ),
                          const SizedBox(height: 6),
                          CupertinoTextField(
                            controller: codeController,
                            placeholder: 'Bo\'lim kodi',
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Mas\'ul prorab',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.labelSecondary
                                  : AppColors.secondaryLabelLight,
                              fontWeight: FontWeight.w500,
                              inherit: false,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1C1C1E)
                                          : CupertinoColors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0x33FFFFFF)
                                            : const Color(0x22000000),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            selectedForemanId == null
                                                ? 'Prorabni tanlang'
                                                : state.foremen
                                                    .firstWhere(
                                                      (f) =>
                                                          f.id ==
                                                          selectedForemanId,
                                                      orElse: () =>
                                                          UserProfile(
                                                              id: '',
                                                              fullName:
                                                                  'Noma\'lum',
                                                              phone: '',
                                                              workerCode: '',
                                                              role: '',
                                                              status: ''),
                                                    )
                                                    .fullName,
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: selectedForemanId == null
                                                  ? (isDark
                                                      ? AppColors
                                                          .labelTertiary
                                                      : AppColors
                                                          .secondaryLabelLight)
                                                  : (isDark
                                                      ? AppColors.labelDark
                                                      : AppColors.labelLight),
                                              inherit: false,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Icon(
                                          CupertinoIcons.chevron_down,
                                          size: 18,
                                          color: isDark
                                              ? AppColors.labelTertiary
                                              : AppColors.secondaryLabelLight,
                                        ),
                                      ],
                                    ),
                                  ),
                                  onPressed: () {
                                    if (state.foremen.isEmpty) {
                                      AppToast.show(context,
                                          message:
                                              'Avval prorab yarating',
                                          type: ToastType.error);
                                      return;
                                    }
                                    showCupertinoModalPopup<void>(
                                      context: context,
                                      builder: (context) {
                                        return Container(
                                          height: 250,
                                          color: CupertinoColors
                                              .systemBackground
                                              .resolveFrom(context),
                                          child: CupertinoPicker(
                                            itemExtent: 32,
                                            onSelectedItemChanged: (index) {
                                              setModalState(() {
                                                selectedForemanId =
                                                    state.foremen[index].id;
                                              });
                                            },
                                            children: state.foremen
                                                .map((f) => Center(
                                                    child: Text(f.fullName)))
                                                .toList(),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              final name = nameController.text.trim();
                              final code = codeController.text.trim();
                              if (name.isEmpty) {
                                AppToast.show(context,
                                    message: 'Bo\'lim nomini kiriting',
                                    type: ToastType.error);
                                return;
                              }
                              if (code.isEmpty) {
                                AppToast.show(context,
                                    message: 'Bo\'lim kodini kiriting',
                                    type: ToastType.error);
                                return;
                              }
                              if (selectedForemanId == null) {
                                AppToast.show(context,
                                    message: 'Prorabni tanlang',
                                    type: ToastType.error);
                                return;
                              }
                              Navigator.of(context).pop();
                              this.context.read<DepartmentsBloc>().add(
                                    DepartmentsUpdateRequested(
                                      id: dept.id,
                                      name:
                                          name != dept.name ? name : null,
                                      code: code != (dept.code ?? '')
                                          ? code
                                          : null,
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
                context
                    .read<DepartmentsBloc>()
                    .add(const DepartmentsLoadRequested());
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
                          inherit: false,
                        ),
                      ),
                    ),
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
                            color: isDark
                                ? AppColors.labelDark
                                : AppColors.labelLight,
                            inherit: false,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.labelSecondary
                                : AppColors.secondaryLabelLight,
                            inherit: false,
                          ),
                        ),
                        const SizedBox(height: 16),
                        CupertinoButton(
                          color: AppColors.primary,
                          onPressed: () => context
                              .read<DepartmentsBloc>()
                              .add(const DepartmentsLoadRequested()),
                          child: const Text('Qayta yuklash'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (state.departments.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.square_list,
                          size: 64,
                          color: isDark
                              ? AppColors.labelTertiary
                              : AppColors.secondaryLabelLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Bo\'limlar ro\'yxati bo\'sh',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.labelDark
                                : AppColors.labelLight,
                            inherit: false,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hozircha birorta ham bo\'lim qo\'shilmagan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.labelSecondary
                                : AppColors.secondaryLabelLight,
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
                padding: const EdgeInsets.only(
                    left: 16, right: 16, bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final dept = state.departments[index];
                      final isCurrentBusy =
                          state.actionInProgressId == dept.id;

                      return Opacity(
                        opacity: isCurrentBusy ? 0.6 : 1.0,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.cardDark
                                : AppColors.cardLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0x11FFFFFF)
                                  : const Color(0x11000000),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _showEditSheet(dept),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            dept.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? AppColors.labelDark
                                                  : AppColors.labelLight,
                                              inherit: false,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (dept.isActive == false)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.error
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Faolsiz',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.error,
                                                  inherit: false,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          if (dept.code != null) ...[
                                            Container(
                                              padding: const EdgeInsets
                                                      .symmetric(
                                                  horizontal: 6,
                                                  vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0x1AFFFFFF)
                                                    : const Color(0x0A000000),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                dept.code!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? AppColors
                                                          .labelSecondary
                                                      : AppColors
                                                          .secondaryLabelLight,
                                                  inherit: false,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          if (dept.foremanName != null) ...[
                                            Icon(
                                              CupertinoIcons.person_fill,
                                              size: 12,
                                              color: isDark
                                                  ? AppColors.labelTertiary
                                                  : AppColors
                                                      .secondaryLabelLight,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                dept.foremanName!,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isDark
                                                      ? AppColors
                                                          .labelSecondary
                                                      : AppColors
                                                          .secondaryLabelLight,
                                                  inherit: false,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (dept.workerCount != null &&
                                          dept.workerCount! > 0) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          '${dept.workerCount} nafar ishchi',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.success,
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
                              if (isCurrentBusy)
                                const CupertinoActivityIndicator()
                              else
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _toggleStatus(dept),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: (dept.isActive ?? true)
                                          ? AppColors.error.withOpacity(0.08)
                                          : AppColors.success
                                              .withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: (dept.isActive ?? true)
                                            ? AppColors.error.withOpacity(0.2)
                                            : AppColors.success
                                                .withOpacity(0.2),
                                      ),
                                    ),
                                    child: Text(
                                      (dept.isActive ?? true)
                                          ? 'Faolsizlash'
                                          : 'Faollash',
                                      style: TextStyle(
                                        color: (dept.isActive ?? true)
                                            ? AppColors.error
                                            : AppColors.success,
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
