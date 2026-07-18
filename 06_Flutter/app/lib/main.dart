import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:texerp/core/l10n/locale_cubit.dart';
import 'package:texerp/core/network/api_client.dart';
import 'package:texerp/core/network/token_provider.dart';
import 'package:texerp/core/router/app_router.dart';
import 'package:texerp/core/storage/secure_storage.dart';
import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/features/auth/data/auth_repository.dart';
import 'package:texerp/features/auth/presentation/auth_bloc.dart';
import 'package:texerp/features/profile/data/profile_repository.dart';
import 'package:texerp/features/profile/presentation/profile_bloc.dart';
import 'package:texerp/features/production/data/production_repository.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final secureStorage = SecureStorage();
  final tokenProvider = TokenProvider();
  final localeCubit = LocaleCubit();

  final apiClient = ApiClient(
    baseUrl: 'http://192.168.43.103:3000/api/v1',
    secureStorage: secureStorage,
    tokenProvider: tokenProvider,
    localeCubit: localeCubit,
  );

  final authRepository = AuthRepository(
    apiClient: apiClient,
    secureStorage: secureStorage,
  );

  final authBloc = AuthBloc(
    authRepository: authRepository,
    secureStorage: secureStorage,
    tokenProvider: tokenProvider,
  );

  apiClient.onSessionExpired = () => authBloc.add(const AuthSessionExpired());
  apiClient.onAccessTokenRefreshed = (token) {
    authBloc.add(AuthAccessTokenRefreshed(accessToken: token));
  };

  final profileRepository = ProfileRepository(apiClient: apiClient);
  final productionRepository = ProductionRepository(apiClient: apiClient);

  final profileBloc = ProfileBloc(
    profileRepository: profileRepository,
    authRepository: authRepository,
    onLogout: () => authBloc.add(const AuthLogoutRequested()),
  );

  final appRouter = AppRouter(authBloc: authBloc);

  runApp(
    TexERPApp(
      authBloc: authBloc,
      profileBloc: profileBloc,
      localeCubit: localeCubit,
      appRouter: appRouter,
      authRepository: authRepository,
      profileRepository: profileRepository,
      productionRepository: productionRepository,
      secureStorage: secureStorage,
    ),
  );
}

class TexERPApp extends StatelessWidget {
  const TexERPApp({
    required this.authBloc,
    required this.profileBloc,
    required this.localeCubit,
    required this.appRouter,
    required this.authRepository,
    required this.profileRepository,
    required this.productionRepository,
    required this.secureStorage,
    super.key,
  });

  final AuthBloc authBloc;
  final ProfileBloc profileBloc;
  final LocaleCubit localeCubit;
  final AppRouter appRouter;
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final ProductionRepository productionRepository;
  final SecureStorage secureStorage;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: profileRepository),
        RepositoryProvider.value(value: productionRepository),
        RepositoryProvider.value(value: secureStorage),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: authBloc),
          BlocProvider.value(value: profileBloc),
          BlocProvider.value(value: localeCubit),
        ],
        child: BlocBuilder<LocaleCubit, Locale>(
          builder: (context, locale) {
            final brightness = PlatformDispatcher.instance.platformBrightness;
            final isDark = brightness == Brightness.dark;

            return CupertinoApp.router(
              title: 'TexERP',
              debugShowCheckedModeBanner: false,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('uz'),
                Locale('ru'),
              ],
              locale: locale,
              theme:
                  isDark ? AppTheme.cupertinoDark : AppTheme.cupertinoLight,
              routerConfig: appRouter.router,
            );
          },
        ),
      ),
    );
  }
}
