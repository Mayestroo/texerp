import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:texerp/core/l10n/locale_cubit.dart';
import 'package:texerp/features/auth/data/auth_models.dart';
import 'package:texerp/features/auth/presentation/auth_bloc.dart';
import 'package:texerp/features/profile/presentation/profile_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/core/widgets/segmented_toggle.dart';
import 'package:texerp/core/storage/secure_storage.dart';
import 'package:texerp/core/widgets/app_toast.dart';
import 'package:local_auth/local_auth.dart';
import 'package:texerp/features/auth/data/auth_repository.dart';
import 'package:texerp/core/error/network_exception.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    final userId = context.read<AuthBloc>().state.user?.id;
    if (userId != null) {
      context.read<ProfileBloc>().add(ProfileLoadRequested(userId: userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: Text(l10n.profile, style: const TextStyle(color: AppColors.labelPrimary)),
      ),
      child: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          if (state is ProfileLoading) {
            return const Center(child: CupertinoActivityIndicator());
          }
          if (state is ProfileFailure) {
            return _ErrorView(message: state.error);
          }
          if (state is ProfileLoaded) {
            return _ProfileContent(user: state.user);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;

    return Column(
      children: [
        Expanded(
          child: CupertinoScrollbar(
            child: SingleChildScrollView(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    _AvatarHeader(name: user.fullName),
                    const SizedBox(height: 24),
                    CupertinoListSection.insetGrouped(
                      header: Text(l10n.fullName.toUpperCase(), style: const TextStyle(color: AppColors.labelSecondary)),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        _buildRow(context, 
                          title: l10n.fullName, 
                          additionalInfo: Text(user.fullName, style: textStyle.copyWith(color: AppColors.labelPrimary)),
                        ),
                        _buildRow(context, 
                          title: l10n.phone, 
                          additionalInfo: Text(user.phone, style: textStyle.copyWith(color: AppColors.labelPrimary)),
                        ),
                        _buildRow(context, 
                          title: l10n.workerCode, 
                          additionalInfo: Text(user.workerCode, style: textStyle.copyWith(color: AppColors.labelPrimary)),
                        ),
                        _buildRow(context, 
                          title: l10n.role, 
                          additionalInfo: _RoleBadge(label: _roleLabel(l10n, user.role)),
                        ),
                      ],
                    ),
                    if (user.department != null)
                      CupertinoListSection.insetGrouped(
                        header: const Text('DEPARTMENT', style: TextStyle(color: AppColors.labelSecondary)),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: [
                          _buildRow(context, 
                            title: l10n.department, 
                            additionalInfo: Text(user.department!.name, style: textStyle.copyWith(color: AppColors.labelPrimary)),
                          ),
                          if (user.role == 'WORKER' && user.foreman != null)
                            _buildRow(context, 
                              title: l10n.foreman, 
                              additionalInfo: Text(user.foreman!.fullName, style: textStyle.copyWith(color: AppColors.labelPrimary)),
                            ),
                        ],
                      ),
                    CupertinoListSection.insetGrouped(
                      header: const Text('PREFERENCES', style: TextStyle(color: AppColors.labelSecondary)),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        _LanguageTile(),
                        _buildRow(context, 
                          icon: CupertinoIcons.lock,
                          title: l10n.changePin, 
                          trailing: const CupertinoListTileChevron(),
                          onTap: () => context.push('/profile/change-pin'),
                        ),
                        const _SecuritySettingsSection(),
                      ],
                    ),
                    CupertinoListSection.insetGrouped(
                      header: const Text('ABOUT', style: TextStyle(color: AppColors.labelSecondary)),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      children: [
                        _buildRow(context, 
                          title: l10n.version, 
                          additionalInfo: Text('1.0.0', style: textStyle.copyWith(color: AppColors.labelPrimary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
                onPressed: () => _showLogoutDialog(context),
                child: Text(
                  l10n.logout,
                  style: textStyle.copyWith(
                    color: CupertinoColors.destructiveRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, {
    IconData? icon, 
    required String title, 
    Widget? additionalInfo, 
    Widget? trailing, 
    VoidCallback? onTap,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: CupertinoListTile(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        leadingSize: 24,
        leading: icon != null 
            ? Icon(icon, size: 24, color: CupertinoTheme.of(context).primaryColor)
            : const SizedBox(width: 24, height: 24),
        title: Text(title, style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(color: AppColors.labelSecondary)),
        additionalInfo: additionalInfo,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  String _roleLabel(AppLocalizations l10n, String role) {
    switch (role) {
      case 'WORKER':
        return l10n.worker;
      case 'FOREMAN':
        return l10n.foreman_role;
      case 'ACCOUNTANT':
        return l10n.accountant;
      case 'DIRECTOR':
        return l10n.director;
      default:
        return role;
    }
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.logoutConfirm),
        content: Text(l10n.logoutMessage),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.confirmLogout),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<ProfileBloc>().add(const ProfileLogoutRequested());
    }
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: CupertinoTheme.of(context).primaryColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          color: CupertinoTheme.of(context).primaryColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _AvatarHeader extends StatelessWidget {
  const _AvatarHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';

    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: CupertinoTheme.of(context).primaryColor,
        ),
        child: Center(
        child: Text(
          initial,
          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
            color: CupertinoColors.white,
            fontSize: 36,
            fontWeight: FontWeight.w600,
          ),
        ),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeCubit = context.watch<LocaleCubit>();

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: CupertinoListTile(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        leadingSize: 24,
        leading: Icon(CupertinoIcons.globe, size: 24, color: CupertinoTheme.of(context).primaryColor),
        title: Text(l10n.language, style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(color: AppColors.labelSecondary)),
        trailing: SegmentedToggle<String>(
          groupValue: localeCubit.state.languageCode,
          children: {
            'uz': l10n.languageUz,
            'ru': l10n.languageRu,
          },
          onValueChanged: (value) => localeCubit.setLocale(Locale(value)),
        ),
      ),
    );
  }
}


class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.labelPrimary)),
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            onPressed: () {
              final userId = context.read<AuthBloc>().state.user?.id;
              if (userId != null) {
                context.read<ProfileBloc>().add(ProfileLoadRequested(userId: userId));
              }
            },
            color: CupertinoTheme.of(context).primaryColor,
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

class _SecuritySettingsSection extends StatefulWidget {
  const _SecuritySettingsSection();

  @override
  State<_SecuritySettingsSection> createState() => _SecuritySettingsSectionState();
}

class _SecuritySettingsSectionState extends State<_SecuritySettingsSection> {
  bool _usePinLock = false;
  bool _useBiometric = false;
  bool _isLoading = true;
  bool _isBiometricSupported = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = context.read<SecureStorage>();
    final usePin = await storage.getUsePinLock();
    final useBio = await storage.getUseBiometric();
    
    bool isSupported = false;
    try {
      isSupported = await _localAuth.isDeviceSupported() || await _localAuth.canCheckBiometrics;
    } catch (_) {
      isSupported = false;
    }

    if (mounted) {
      setState(() {
        _usePinLock = usePin;
        _useBiometric = useBio;
        _isBiometricSupported = isSupported;
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePinLock(bool value) async {
    final storage = context.read<SecureStorage>();
    final authBloc = context.read<AuthBloc>();

    if (value) {
      String? pinToSave = authBloc.state.currentPin;
      if (pinToSave == null || pinToSave.isEmpty) {
        final verifiedPin = await _showPinConfirmationDialog();
        if (verifiedPin == null) {
          return;
        }
        pinToSave = verifiedPin;
      }

      await storage.setUsePinLock(true);
      await storage.saveSavedPin(pinToSave);
      setState(() {
        _usePinLock = true;
      });
      if (mounted) {
        AppToast.show(context, message: 'PIN-kod bilan kirish faollashtirildi', type: ToastType.success);
      }
    } else {
      await storage.setUsePinLock(false);
      await storage.deleteSavedPin();
      await storage.setUseBiometric(false);
      setState(() {
        _usePinLock = false;
        _useBiometric = false;
      });
      if (mounted) {
        AppToast.show(context, message: 'PIN-kod bilan kirish oʻchirildi', type: ToastType.info);
      }
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    final storage = context.read<SecureStorage>();
    if (value) {
      try {
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Biometrik kirishni faollashtirish uchun tasdiqlang',
          persistAcrossBackgrounding: true,
          biometricOnly: true,
        );
        if (!authenticated) return;
      } catch (e) {
        if (mounted) {
          AppToast.show(context, message: 'Biometrik tasdiqlash bajarilmadi', type: ToastType.error);
        }
        return;
      }

      await storage.setUseBiometric(true);
      setState(() {
        _useBiometric = true;
      });
      if (mounted) {
        AppToast.show(context, message: 'Biometrik autentifikatsiya yoqildi', type: ToastType.success);
      }
    } else {
      await storage.setUseBiometric(false);
      setState(() {
        _useBiometric = false;
      });
      if (mounted) {
        AppToast.show(context, message: 'Biometrik autentifikatsiya oʻchirildi', type: ToastType.info);
      }
    }
  }

  Future<String?> _showPinConfirmationDialog() async {
    final textController = TextEditingController();
    String? result;

    await showCupertinoDialog<void>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('PIN kodni tasdiqlang'),
          content: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: CupertinoTextField(
              controller: textController,
              placeholder: '4 xonali PIN kod',
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, letterSpacing: 8),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Bekor qilish'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              child: const Text('Tasdiqlash'),
              onPressed: () async {
                final pin = textController.text;
                if (pin.length != 4) return;
                
                showCupertinoDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CupertinoActivityIndicator()),
                );

                try {
                  await context.read<AuthRepository>().verifyPin(pin);
                  result = pin;
                  if (context.mounted) {
                    Navigator.pop(context); 
                    Navigator.pop(context); 
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); 
                    String msg = "PIN kod noto'g'ri";
                    if (e is NetworkException) {
                      msg = e.message;
                    }
                    AppToast.show(context, message: msg, type: ToastType.error);
                  }
                }
              },
            ),
          ],
        );
      },
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;

    return Column(
      children: [
        CupertinoListTile(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Icon(CupertinoIcons.lock_shield, size: 24, color: CupertinoTheme.of(context).primaryColor),
          title: Text('PIN-kod bilan kirish', style: textStyle.copyWith(color: AppColors.labelPrimary)),
          trailing: CupertinoSwitch(
            value: _usePinLock,
            onChanged: _togglePinLock,
          ),
        ),
        if (_usePinLock && _isBiometricSupported)
          CupertinoListTile(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Icon(CupertinoIcons.device_phone_portrait, size: 24, color: CupertinoTheme.of(context).primaryColor),
            title: Text('Face ID / Touch ID', style: textStyle.copyWith(color: AppColors.labelPrimary)),
            trailing: CupertinoSwitch(
              value: _useBiometric,
              onChanged: _toggleBiometric,
            ),
          ),
      ],
    );
  }
}

