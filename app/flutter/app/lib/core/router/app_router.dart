import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:texerp/features/auth/data/auth_repository.dart';
import 'package:texerp/features/auth/presentation/auth_bloc.dart';
import 'package:texerp/features/auth/presentation/login_screen.dart';
import 'package:texerp/features/auth/presentation/splash_screen.dart';
import 'package:texerp/features/profile/data/profile_repository.dart';
import 'package:texerp/features/profile/presentation/change_pin_screen.dart';
import 'package:texerp/features/profile/presentation/profile_bloc.dart';
import 'package:texerp/features/profile/presentation/profile_screen.dart';
import 'package:texerp/core/common/placeholder_screen.dart';
import 'package:texerp/core/common/role_based_shell.dart';
import 'package:texerp/core/notifications/fcm_service.dart';
import 'package:texerp/features/auth/presentation/lock_screen.dart';
import 'package:texerp/features/notifications/data/notifications_repository.dart';
import 'package:texerp/features/notifications/presentation/notifications_bloc.dart';
import 'package:texerp/features/notifications/presentation/notifications_screen.dart';
import 'package:texerp/features/payroll/data/payroll_repository.dart';
import 'package:texerp/features/payroll/presentation/payroll_bloc.dart';
import 'package:texerp/features/payroll/presentation/payroll_period_detail_screen.dart';
import 'package:texerp/features/production/data/production_repository.dart';
import 'package:texerp/features/production/data/production_models.dart';
import 'package:texerp/features/production/presentation/entry_detail_screen.dart';
import 'package:texerp/features/production/presentation/foreman_queue_bloc.dart';
import 'package:texerp/features/production/presentation/foreman_queue_screen.dart';
import 'package:texerp/features/reports/data/reports_repository.dart';
import 'package:texerp/features/reports/presentation/reports_bloc.dart';
import 'package:texerp/features/reports/presentation/reports_screen.dart';
import 'package:texerp/features/settings/data/settings_repository.dart';
import 'package:texerp/features/settings/presentation/settings_bloc.dart';
import 'package:texerp/features/settings/presentation/settings_screen.dart';
import 'package:texerp/features/warehouse/data/warehouse_repository.dart';
import 'package:texerp/features/warehouse/data/warehouse_models.dart' as warehouse;
import 'package:texerp/features/warehouse/presentation/warehouse_bloc.dart';
import 'package:texerp/features/warehouse/presentation/materials_list_screen.dart';
import 'package:texerp/features/warehouse/presentation/material_detail_screen.dart';

class _FadePage extends CustomTransitionPage<void> {
  _FadePage({required super.child, super.key})
      : super(
          transitionDuration: const Duration(milliseconds: 250),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            );
          },
        );
}

class AppRouter {
  AppRouter({
    required AuthBloc authBloc,
    required FcmService fcmService,
  })  : _authBloc = authBloc,
        _fcmService = fcmService {
    // Subscribe to deep links from FCM (foreground taps)
    _deepLinkSubscription = _fcmService.deepLinkStream.listen((link) {
      _router.go(link);
    });
  }

  final AuthBloc _authBloc;
  final FcmService _fcmService;
  StreamSubscription<String>? _deepLinkSubscription;

  late final GoRouter _router = GoRouter(
        initialLocation: '/splash',
        refreshListenable: _AuthRefreshStream(_authBloc.stream),
        debugLogDiagnostics: false,
        redirect: (context, state) {
          final authState = _authBloc.state;
          final isAuthenticated = authState is AuthAuthenticated;
          final isUnauthenticated = authState is AuthUnauthenticated;

          final isLoggingIn = state.matchedLocation == '/login';
          final isSplash = state.matchedLocation == '/splash';
          final isLock = state.matchedLocation == '/lock';

          if (authState is AuthInitial || authState is AuthLoading) {
            return isSplash ? null : '/splash';
          }

          if (isUnauthenticated && !isLoggingIn) {
            return '/login';
          }

          if (isAuthenticated) {
            if (authState.isLocked) {
              return '/lock';
            }

            final deepLink = _fcmService.pendingDeepLink;
            if (deepLink != null && deepLink != state.uri.toString()) {
              return deepLink;
            }

            if (isLoggingIn || isSplash || isLock) {
              return _homeForRole(authState.user.role);
            }
          }

          return null;
        },
        routes: [
          GoRoute(
            path: '/splash',
            pageBuilder: (context, state) => _FadePage(
              key: state.pageKey,
              child: const SplashScreen(),
            ),
          ),
          GoRoute(
            path: '/login',
            pageBuilder: (context, state) => _FadePage(
              key: state.pageKey,
              child: const LoginScreen(),
            ),
          ),
          GoRoute(
            path: '/lock',
            pageBuilder: (context, state) => _FadePage(
              key: state.pageKey,
              child: const LockScreen(),
            ),
          ),
          GoRoute(
            path: '/worker/home',
            pageBuilder: (context, state) => _FadePage(
              key: state.pageKey,
              child: const WorkerHomeScreen(),
            ),
          ),
          GoRoute(
            path: '/foreman-home',
            pageBuilder: (context, state) => _FadePage(
              key: state.pageKey,
              child: const ForemanHomeScreen(),
            ),
          ),
          GoRoute(
            path: '/accountant-home',
            pageBuilder: (context, state) => _FadePage(
              key: state.pageKey,
              child: const AccountantHomeScreen(),
            ),
          ),
          GoRoute(
            path: '/director-home',
            pageBuilder: (context, state) => _FadePage(
              key: state.pageKey,
              child: const DirectorHomeScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => _FadePage(
              key: state.pageKey,
              child: BlocProvider(
                create: (_) => ProfileBloc(
                  profileRepository: context.read<ProfileRepository>(),
                  authRepository: context.read<AuthRepository>(),
                  onLogout: () => _authBloc.add(const AuthLogoutRequested()),
                ),
                child: const ProfileScreen(),
              ),
            ),
          ),
          GoRoute(
            path: '/payroll/periods/:id',
            pageBuilder: (context, state) => _FadePage(
              key: state.pageKey,
              child: BlocProvider(
                create: (_) => PayrollBloc(
                  payrollRepository: context.read<PayrollRepository>(),
                ),
                child: PayrollPeriodDetailScreen(
                  periodId: state.pathParameters['id']!,
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/profile/change-pin',
            pageBuilder: (context, state) => _FadePage(
              key: state.pageKey,
              child: const ChangePinScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => _FadePage(
              key: state.pageKey,
              child: BlocProvider(
                create: (_) => SettingsBloc(
                  settingsRepository: context.read<SettingsRepository>(),
                ),
                child: const SettingsScreen(),
              ),
            ),
          ),
          GoRoute(
            path: '/worker/history/:id',
            pageBuilder: (context, state) => _FadePage(
              key: state.pageKey,
              child: EntryDetailScreen(
                entryId: state.pathParameters['id']!,
                entry: state.extra as ProductionEntry?,
              ),
            ),
          ),
          GoRoute(
            path: '/warehouse/materials',
            pageBuilder: (context, state) => _FadePage(
              key: state.pageKey,
              child: BlocProvider(
                create: (_) => WarehouseBloc(
                  warehouseRepository: context.read<WarehouseRepository>(),
                ),
                child: const MaterialsListScreen(),
              ),
            ),
          ),
          GoRoute(
            path: '/warehouse/materials/:id',
            pageBuilder: (context, state) => _FadePage(
              key: state.pageKey,
              child: BlocProvider(
                create: (_) => WarehouseBloc(
                  warehouseRepository: context.read<WarehouseRepository>(),
                ),
                child: MaterialDetailScreen(
                  materialId: state.pathParameters['id']!,
                  material: state.extra as warehouse.Material?,
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/worker/payroll/:id',
            pageBuilder: (context, state) => _FadePage(
              key: state.pageKey,
              child: BlocProvider(
                create: (_) => PayrollBloc(
                  payrollRepository: context.read<PayrollRepository>(),
                ),
                child: PayrollPeriodDetailScreen(
                  periodId: state.pathParameters['id']!,
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/foreman/pending',
            pageBuilder: (context, state) => _FadePage(
              key: state.pageKey,
              child: BlocProvider(
                create: (_) => ForemanQueueBloc(
                  productionRepository: context.read<ProductionRepository>(),
                ),
                child: const ForemanQueueScreen(),
              ),
            ),
          ),
          GoRoute(
            path: '/notifications',
            pageBuilder: (context, state) => _FadePage(
              key: state.pageKey,
              child: BlocProvider(
                create: (_) => NotificationsBloc(
                  notificationsRepository: context.read<NotificationsRepository>(),
                ),
                child: const NotificationsScreen(),
              ),
            ),
          ),
          GoRoute(
            path: '/payroll/export/:id',
            pageBuilder: (context, state) => _FadePage(
              key: state.pageKey,
              child: const PlaceholderScreen(title: 'Export Status'),
            ),
          ),
          GoRoute(
            path: '/reports/production',
            pageBuilder: (context, state) => _FadePage(
              key: state.pageKey,
              child: BlocProvider(
                create: (_) => ReportsBloc(
                  reportsRepository: context.read<ReportsRepository>(),
                ),
                child: const ReportsScreen(),
              ),
            ),
          ),
        ],
      );

  GoRouter get router => _router;

  void dispose() {
    _deepLinkSubscription?.cancel();
  }

  String _homeForRole(String role) {
    switch (role) {
      case 'WORKER':
        return '/worker/home';
      case 'FOREMAN':
        return '/foreman-home';
      case 'ACCOUNTANT':
        return '/accountant-home';
      case 'DIRECTOR':
        return '/director-home';
      default:
        return '/worker/home';
    }
  }
}

class _AuthRefreshStream extends ChangeNotifier {
  _AuthRefreshStream(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
