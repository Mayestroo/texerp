import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/core/widgets/app_toast.dart';
import 'package:texerp/features/profile/presentation/team_bloc.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  String _searchQuery = '';
  int _viewModeIndex = 0;
  int _periodIndex = 0;

  @override
  void initState() {
    super.initState();
    context.read<TeamBloc>().add(const TeamLoadRequested());
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    AppToast.show(
      context,
      message: 'Telefon raqami nusxalandi!',
      type: ToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return BlocBuilder<TeamBloc, TeamState>(
      builder: (context, state) {
        if (state.isLoading && state.workers.isEmpty) {
          return const Center(
            child: CupertinoActivityIndicator(),
          );
        }

        if (state.error != null && state.workers.isEmpty) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  context.read<TeamBloc>().add(const TeamLoadRequested());
                },
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
                          'Jamoani yuklashda xatolik',
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
                        const SizedBox(height: 20),
                        CupertinoButton(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () {
                            context.read<TeamBloc>().add(const TeamLoadRequested());
                          },
                          child: const Text('Qayta yuklash'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        final filteredWorkers = state.workers.where((worker) {
          final query = _searchQuery.toLowerCase();
          return worker.fullName.toLowerCase().contains(query) ||
              worker.workerCode.toLowerCase().contains(query) ||
              worker.phone.contains(query);
        }).toList();

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                context.read<TeamBloc>().add(const TeamLoadRequested());
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
                child: Column(
                  children: [
                    // View Mode Toggle (Ro'yxat vs Reyting)
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoSlidingSegmentedControl<int>(
                        groupValue: _viewModeIndex,
                        children: const {
                          0: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Jamoa ro\'yxati', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, inherit: true)),
                          ),
                          1: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Ish unumdorligi reytingi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, inherit: true)),
                          ),
                        },
                        onValueChanged: (val) {
                          if (val != null) setState(() => _viewModeIndex = val);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_viewModeIndex == 1) ...[
                      // Time period selector for ranking
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoSlidingSegmentedControl<int>(
                          groupValue: _periodIndex,
                          children: const {
                            0: Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Text('Bugun', style: TextStyle(fontSize: 12, inherit: true)),
                            ),
                            1: Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Text('Shu hafta', style: TextStyle(fontSize: 12, inherit: true)),
                            ),
                            2: Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Text('Shu oy', style: TextStyle(fontSize: 12, inherit: true)),
                            ),
                          },
                          onValueChanged: (val) {
                            if (val != null) setState(() => _periodIndex = val);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      // Search bar for list mode
                      CupertinoTextField(
                        placeholder: 'Jamoa a\'zolarini qidirish...',
                        placeholderStyle: TextStyle(
                          color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                          fontSize: 14,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        clearButtonMode: OverlayVisibilityMode.editing,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
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
                    ],
                  ],
                ),
              ),
            ),
            if (filteredWorkers.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.person_3_fill,
                          size: 64,
                          color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'Jamoa a\'zolari yo\'q' : 'Natija topilmadi',
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
                              ? 'Sizga biriktirilgan ishchilar ro\'yxati bu yerda paydo bo\'ladi.'
                              : 'Qidiruv shartlariga mos keladigan ishchi topilmadi.',
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
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final worker = filteredWorkers[index];
                      final isActive = worker.status == 'ACTIVE';
                      final initials = worker.fullName
                          .split(' ')
                          .map((e) => e.isNotEmpty ? e[0] : '')
                          .take(2)
                          .join()
                          .toUpperCase();

                      return Container(
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
                              color: CupertinoColors.black.withOpacity(isDark ? 0.2 : 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Avatar with Active status dot
                            Stack(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initials.isNotEmpty ? initials : "?",
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      inherit: true,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: isActive ? AppColors.success : AppColors.error,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark ? AppColors.cardDark : AppColors.cardLight,
                                        width: 2.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            // Info Column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    worker.fullName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.labelDark : AppColors.labelLight,
                                      inherit: true,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isDark ? const Color(0x11FFFFFF) : const Color(0x11000000),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(CupertinoIcons.number, size: 10, color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight),
                                            const SizedBox(width: 2),
                                            Text(
                                              worker.workerCode,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                                inherit: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (worker.department != null) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: primaryColor.withOpacity(0.06),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: primaryColor.withOpacity(0.12),
                                            ),
                                          ),
                                          child: Text(
                                            worker.department!.name,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: primaryColor,
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
                            // Call Action Button
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _copyToClipboard(worker.phone),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CupertinoIcons.phone_fill,
                                  color: primaryColor,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: filteredWorkers.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
