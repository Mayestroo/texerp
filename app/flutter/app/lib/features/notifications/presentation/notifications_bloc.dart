import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:texerp/features/notifications/data/notification_models.dart';
import 'package:texerp/features/notifications/data/notifications_repository.dart';

// --- EVENTS ---
abstract class NotificationsEvent {
  const NotificationsEvent();
}

class NotificationsLoadRequested extends NotificationsEvent {
  const NotificationsLoadRequested({this.refresh = false});

  final bool refresh;
}

class NotificationsLoadMoreRequested extends NotificationsEvent {
  const NotificationsLoadMoreRequested();
}

class NotificationsMarkRead extends NotificationsEvent {
  const NotificationsMarkRead({required this.ids});

  final List<String> ids;
}

class NotificationsMarkAllRead extends NotificationsEvent {
  const NotificationsMarkAllRead();
}

// --- STATES ---
abstract class NotificationsState {
  const NotificationsState();
}

class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

class NotificationsLoaded extends NotificationsState {
  const NotificationsLoaded({
    required this.items,
    required this.unreadCount,
    required this.hasMore,
    this.isLoadingMore = false,
    this.error,
  });

  final List<NotificationItem> items;
  final int unreadCount;
  final bool hasMore;
  final bool isLoadingMore;
  final String? error;

  NotificationsLoaded copyWith({
    List<NotificationItem>? items,
    int? unreadCount,
    bool? hasMore,
    bool? isLoadingMore,
    Object? error = const Object(),
  }) {
    return NotificationsLoaded(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error == const Object() ? this.error : (error as String?),
    );
  }
}

class NotificationsError extends NotificationsState {
  const NotificationsError({required this.message});

  final String message;
}

// --- BLOC ---
class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  NotificationsBloc({required NotificationsRepository notificationsRepository})
      : _notificationsRepository = notificationsRepository,
        super(const NotificationsInitial()) {
    on<NotificationsLoadRequested>(_onLoadRequested);
    on<NotificationsLoadMoreRequested>(_onLoadMoreRequested);
    on<NotificationsMarkRead>(_onMarkRead);
    on<NotificationsMarkAllRead>(_onMarkAllRead);
  }

  final NotificationsRepository _notificationsRepository;
  static const int _pageSize = 30;

  Future<void> _onLoadRequested(
    NotificationsLoadRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state is! NotificationsLoaded || event.refresh) {
      emit(const NotificationsLoading());
    }
    try {
      final (items, total, unreadCount) =
          await _notificationsRepository.fetchNotifications(
        page: 1,
        limit: _pageSize,
      );
      emit(NotificationsLoaded(
        items: items,
        unreadCount: unreadCount,
        hasMore: items.length < total,
      ));
    } catch (e) {
      if (state is NotificationsLoaded) {
        final loadedState = state as NotificationsLoaded;
        emit(loadedState.copyWith(error: e.toString()));
      } else {
        emit(NotificationsError(message: e.toString()));
      }
    }
  }

  Future<void> _onLoadMoreRequested(
    NotificationsLoadMoreRequested event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state is! NotificationsLoaded) return;

    final loadedState = state as NotificationsLoaded;
    if (!loadedState.hasMore || loadedState.isLoadingMore) return;

    emit(loadedState.copyWith(isLoadingMore: true, error: null));
    try {
      final page = (loadedState.items.length / _pageSize).ceil() + 1;
      final (items, total, unreadCount) =
          await _notificationsRepository.fetchNotifications(
        page: page,
        limit: _pageSize,
      );
      final allItems = [...loadedState.items, ...items];
      emit(loadedState.copyWith(
        items: allItems,
        unreadCount: unreadCount,
        hasMore: allItems.length < total,
        isLoadingMore: false,
      ));
    } catch (e) {
      emit(loadedState.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onMarkRead(
    NotificationsMarkRead event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state is! NotificationsLoaded) return;

    final loadedState = state as NotificationsLoaded;
    final updatedItems = loadedState.items.map((item) {
      if (event.ids.contains(item.id)) {
        return item.copyWith(isRead: true, readAt: DateTime.now());
      }
      return item;
    }).toList();
    final readCount = loadedState.items
        .where((item) => event.ids.contains(item.id) && !item.isRead)
        .length;
    emit(loadedState.copyWith(
      items: updatedItems,
      unreadCount: loadedState.unreadCount - readCount,
    ));

    try {
      await _notificationsRepository.markRead(ids: event.ids);
    } catch (e) {
      emit(loadedState.copyWith(error: e.toString()));
    }
  }

  Future<void> _onMarkAllRead(
    NotificationsMarkAllRead event,
    Emitter<NotificationsState> emit,
  ) async {
    if (state is! NotificationsLoaded) return;

    final loadedState = state as NotificationsLoaded;
    final updatedItems = loadedState.items
        .map((item) => item.copyWith(isRead: true, readAt: DateTime.now()))
        .toList();
    emit(loadedState.copyWith(
      items: updatedItems,
      unreadCount: 0,
    ));

    try {
      await _notificationsRepository.markRead(markAll: true);
    } catch (e) {
      emit(loadedState.copyWith(error: e.toString()));
    }
  }
}
