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
          return Center(
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
                    onPressed: () {
                      context.read<TeamBloc>().add(const TeamLoadRequested());
                    },
                    child: const Text('Qayta yuklash'),
                  ),
                ],
              ),
            ),
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
                padding: const EdgeInsets.all(16.0),
                child: CupertinoSearchTextField(
                  placeholder: 'Jamoa a\'zolarini qidirish...',
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
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
                            inherit: false,
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
                      final worker = filteredWorkers[index];
                      final isActive = worker.status == 'ACTIVE';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDark : AppColors.cardLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0x11FFFFFF) : const Color(0x11000000),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.black.withOpacity(0.02),
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
                                  child: Center(
                                    child: Text(
                                      worker.fullName.substring(0, 1).toUpperCase(),
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        inherit: false,
                                      ),
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
                                      inherit: false,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          worker.workerCode,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? AppColors.labelSecondary : AppColors.secondaryLabelLight,
                                            inherit: false,
                                          ),
                                        ),
                                      ),
                                      if (worker.department != null) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          worker.department!.name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppColors.labelTertiary : AppColors.secondaryLabelLight,
                                            inherit: false,
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
