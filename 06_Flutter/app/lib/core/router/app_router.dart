import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:texerp/features/auth/data/auth_repository.dart';
import 'package:texerp/features/auth/presentation/auth_bloc.dart';
import 'package:texerp/features/auth/presentation/login_screen.dart';
import 'package:texerp/features/profile/data/profile_repository.dart';
import 'package:texerp/features/profile/presentation/change_pin_screen.dart';
import 'package:texerp/features/profile/presentation/profile_bloc.dart';
import 'package:texerp/features/profile/presentation/profile_screen.dart';
import 'package:texerp/features/shared/role_based_shell.dart';

/// Application router with role-based redirects.
class AppRouter {
  AppRouter({required AuthBloc authBloc}) : _authBloc = authBloc;

  final AuthBloc _authBloc;

  GoRouter get router => GoRouter(
        refreshListenable: _AuthRefreshStream(_authBloc.stream),
        redirect: (context, state) {
          final authState = _authBloc.state;
          final isAuthenticated = authState is AuthAuthenticated;
          final isLoggingIn = state.matchedLocation == '/login';

          if (!isAuthenticated && !isLoggingIn) {
            return '/login';
          }
          if (isAuthenticated && isLoggingIn) {
            return _homeForRole(authState.user.role);
          }
          return null;
        },
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/worker/home',
            builder: (context, state) => const WorkerHomeScreen(),
          ),
          GoRoute(
            path: '/foreman-home',
            builder: (context, state) => const ForemanHomeScreen(),
          ),
          GoRoute(
            path: '/accountant-home',
            builder: (context, state) => const AccountantHomeScreen(),
          ),
          GoRoute(
            path: '/director-home',
            builder: (context, state) => const DirectorHomeScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => BlocProvider(
              create: (_) => ProfileBloc(
                profileRepository: context.read<ProfileRepository>(),
                authRepository: context.read<AuthRepository>(),
                onLogout: () => _authBloc.add(const AuthLogoutRequested()),
              ),
              child: const ProfileScreen(),
            ),
          ),
          GoRoute(
            path: '/profile/change-pin',
            builder: (context, state) => const ChangePinScreen(),
          ),
        ],
      );

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

/// Listenable wrapper that notifies GoRouter when the auth stream emits.
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
