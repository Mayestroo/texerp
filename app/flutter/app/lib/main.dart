import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:texerp/core/l10n/locale_cubit.dart';
import 'package:texerp/core/network/api_client.dart';
import 'package:texerp/core/network/connectivity_cubit.dart';
import 'package:texerp/core/network/network_info.dart';
import 'package:texerp/core/network/token_provider.dart';
import 'package:texerp/core/notifications/fcm_service.dart';
import 'package:texerp/core/router/app_router.dart';
import 'package:texerp/core/storage/secure_storage.dart';
import 'package:texerp/core/sync/auto_sync_manager.dart';
import 'package:texerp/core/sync/conflict_resolver.dart';
import 'package:texerp/core/sync/offline_queue.dart';
import 'package:texerp/core/sync/sync_manager.dart';
import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/features/auth/data/auth_repository.dart';
import 'package:texerp/features/auth/presentation/auth_bloc.dart';
import 'package:texerp/features/notifications/data/notifications_repository.dart';
import 'package:texerp/features/profile/data/profile_repository.dart';
import 'package:texerp/features/profile/presentation/profile_bloc.dart';
import 'package:texerp/features/production/data/production_repository.dart';
import 'package:texerp/features/payroll/data/payroll_repository.dart';
import 'package:texerp/features/reports/data/reports_repository.dart';
import 'package:texerp/features/settings/data/settings_repository.dart';
import 'package:texerp/features/warehouse/data/warehouse_repository.dart';
import 'package:texerp/generated/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final secureStorage = SecureStorage();
  final tokenProvider = TokenProvider();
  final localeCubit = LocaleCubit();

  final apiClient = ApiClient(
    baseUrl: 'http://192.168.1.10:3000/api/v1',
    secureStorage: secureStorage,
    tokenProvider: tokenProvider,
    localeCubit: localeCubit,
  );

  final fcmService = FcmService(apiClient: apiClient);
  await fcmService.initialize();

  final networkInfo = NetworkInfo(Connectivity());
  final connectivityCubit = ConnectivityCubit(networkInfo);

  final offlineQueue = OfflineQueue();
  final conflictResolver = ConflictResolver();
  final syncManager = SyncManager(
    apiClient: apiClient,
    offlineQueue: offlineQueue,
    conflictResolver: conflictResolver,
  );
  final autoSyncManager = AutoSyncManager(
    networkInfo: networkInfo,
    syncManager: syncManager,
  );
  autoSyncManager.start();

  final authRepository = AuthRepository(
    apiClient: apiClient,
    secureStorage: secureStorage,
  );

  final authBloc = AuthBloc(
    authRepository: authRepository,
    secureStorage: secureStorage,
    tokenProvider: tokenProvider,
    fcmService: fcmService,
  );

  apiClient.onSessionExpired = () => authBloc.add(const AuthSessionExpired());
  apiClient.onAccessTokenRefreshed = (token) {
    authBloc.add(AuthAccessTokenRefreshed(accessToken: token));
  };

  final profileRepository = ProfileRepository(apiClient: apiClient);
  final productionRepository = ProductionRepository(apiClient: apiClient);
  final payrollRepository = PayrollRepository(apiClient: apiClient);
  final notificationsRepository = NotificationsRepository(apiClient: apiClient);
  final reportsRepository = ReportsRepository(apiClient: apiClient);
  final settingsRepository = SettingsRepository(apiClient: apiClient);
  final warehouseRepository = WarehouseRepository(apiClient: apiClient);

  final profileBloc = ProfileBloc(
    profileRepository: profileRepository,
    authRepository: authRepository,
    onLogout: () => authBloc.add(const AuthLogoutRequested()),
  );

  final appRouter = AppRouter(
    authBloc: authBloc,
    fcmService: fcmService,
  );

  runApp(
    TexERPApp(
      authBloc: authBloc,
      profileBloc: profileBloc,
      localeCubit: localeCubit,
      appRouter: appRouter,
      authRepository: authRepository,
      profileRepository: profileRepository,
      productionRepository: productionRepository,
      payrollRepository: payrollRepository,
      reportsRepository: reportsRepository,
      settingsRepository: settingsRepository,
      warehouseRepository: warehouseRepository,
      notificationsRepository: notificationsRepository,
      secureStorage: secureStorage,
      fcmService: fcmService,
      connectivityCubit: connectivityCubit,
      syncManager: syncManager,
      autoSyncManager: autoSyncManager,
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
    required this.payrollRepository,
    required this.reportsRepository,
    required this.settingsRepository,
    required this.warehouseRepository,
    required this.notificationsRepository,
    required this.secureStorage,
    required this.fcmService,
    required this.connectivityCubit,
    required this.syncManager,
    required this.autoSyncManager,
    super.key,
  });

  final AuthBloc authBloc;
  final ProfileBloc profileBloc;
  final LocaleCubit localeCubit;
  final AppRouter appRouter;
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final ProductionRepository productionRepository;
  final PayrollRepository payrollRepository;
  final ReportsRepository reportsRepository;
  final SettingsRepository settingsRepository;
  final WarehouseRepository warehouseRepository;
  final NotificationsRepository notificationsRepository;
  final SecureStorage secureStorage;
  final FcmService fcmService;
  final ConnectivityCubit connectivityCubit;
  final SyncManager syncManager;
  final AutoSyncManager autoSyncManager;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: profileRepository),
        RepositoryProvider.value(value: productionRepository),
        RepositoryProvider.value(value: payrollRepository),
        RepositoryProvider.value(value: reportsRepository),
        RepositoryProvider.value(value: settingsRepository),
        RepositoryProvider.value(value: warehouseRepository),
        RepositoryProvider.value(value: notificationsRepository),
        RepositoryProvider.value(value: secureStorage),
        RepositoryProvider.value(value: fcmService),
        RepositoryProvider.value(value: syncManager),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: authBloc),
          BlocProvider.value(value: profileBloc),
          BlocProvider.value(value: localeCubit),
          BlocProvider.value(value: connectivityCubit),
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
