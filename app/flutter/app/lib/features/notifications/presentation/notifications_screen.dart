import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/core/widgets/app_toast.dart';
import 'package:texerp/features/notifications/data/notification_models.dart';
import 'package:texerp/features/notifications/presentation/notifications_bloc.dart';
import 'package:texerp/generated/app_localizations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    context
        .read<NotificationsBloc>()
        .add(const NotificationsLoadRequested());
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    final yesterday = now.subtract(const Duration(days: 1));

    if (difference.inMinutes < 60) {
      if (difference.inMinutes < 1) {
        return 'Hozirgina';
      }
      return '${difference.inMinutes} daqiqa oldin';
    } else if (DateFormat('yyyyMMdd').format(dateTime) ==
        DateFormat('yyyyMMdd').format(now)) {
      return 'Bugun, ${DateFormat('HH:mm').format(dateTime)}';
    } else if (DateFormat('yyyyMMdd').format(dateTime) ==
        DateFormat('yyyyMMdd').format(yesterday)) {
      return 'Kecha, ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('dd.MM.yyyy, HH:mm').format(dateTime);
    }
  }

  Future<void> _onRefresh() async {
    context
        .read<NotificationsBloc>()
        .add(const NotificationsLoadRequested(refresh: true));
  }

  void _onNotificationTap(NotificationItem item) {
    if (!item.isRead) {
      context
          .read<NotificationsBloc>()
          .add(NotificationsMarkRead(ids: [item.id]));
    }
  }

  void _onMarkAllRead() {
    context
        .read<NotificationsBloc>()
        .add(const NotificationsMarkAllRead());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: Text(
          l10n.notifications,
          style: const TextStyle(color: AppColors.labelPrimary),
        ),
        trailing: BlocBuilder<NotificationsBloc, NotificationsState>(
          builder: (context, state) {
            final hasUnread = state is NotificationsLoaded &&
                state.unreadCount > 0;
            return CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 36,
              onPressed: hasUnread ? _onMarkAllRead : null,
              child: Text(
                'Hammasini o\'qildi',
                style: TextStyle(
                  fontSize: 15,
                  color: hasUnread ? primaryColor : AppColors.labelTertiary,
                  inherit: true,
                ),
              ),
            );
          },
        ),
      ),
      child: BlocConsumer<NotificationsBloc, NotificationsState>(
        listener: (context, state) {
          if (state is NotificationsLoaded && state.error != null) {
            AppToast.show(context, message: state.error!, type: ToastType.error);
          }
        },
        builder: (context, state) {
          if (state is NotificationsLoading || state is NotificationsInitial) {
            return const Center(
              child: CupertinoActivityIndicator(),
            );
          }

          if (state is NotificationsError) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: _onRefresh,
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
                            'Yuklashda xatolik',
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
                            state.message,
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
                            onPressed: () {
                              context.read<NotificationsBloc>().add(
                                    const NotificationsLoadRequested(),
                                  );
                            },
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          if (state is! NotificationsLoaded) {
            return const SizedBox.shrink();
          }

          final items = state.items;

          if (items.isEmpty) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: _onRefresh,
                ),
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.bell_slash,
                            size: 64,
                            color: isDark
                                ? AppColors.labelTertiary
                                : AppColors.secondaryLabelLight,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Bildirishnomalar yo\'q',
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
                            'Hozircha sizga hech qanday bildirishnoma yo\'q',
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

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  notification.metrics.extentAfter < 200) {
                context
                    .read<NotificationsBloc>()
                    .add(const NotificationsLoadMoreRequested());
              }
              return false;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                CupertinoSliverRefreshControl(
                  onRefresh: _onRefresh,
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 32,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == items.length) {
                          if (state.isLoadingMore) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CupertinoActivityIndicator(),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }

                        final item = items[index];

                        return Dismissible(
                          key: ValueKey(item.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.centerRight,
                            child: const Icon(
                              CupertinoIcons.checkmark,
                              color: CupertinoColors.white,
                            ),
                          ),
                          onDismissed: (_) => _onNotificationTap(item),
                          child: GestureDetector(
                            onTap: () => _onNotificationTap(item),
                            behavior: HitTestBehavior.opaque,
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!item.isRead) ...[
                                    Container(
                                      width: 10,
                                      height: 10,
                                      margin: const EdgeInsets.only(top: 6, right: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.info,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ] else
                                    const SizedBox(width: 22),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: item.isRead
                                                ? FontWeight.w500
                                                : FontWeight.bold,
                                            color: isDark
                                                ? AppColors.labelDark
                                                : AppColors.labelLight,
                                            inherit: true,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.body,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDark
                                                ? AppColors.labelSecondary
                                                : AppColors.secondaryLabelLight,
                                            inherit: true,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _formatTimestamp(item.createdAt),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? AppColors.labelTertiary
                                                : AppColors.secondaryLabelLight,
                                            inherit: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: items.length + 1,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
