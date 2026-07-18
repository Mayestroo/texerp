import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';

import 'package:texerp/core/storage/secure_storage.dart';
import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/core/widgets/num_pad.dart';
import 'package:texerp/core/widgets/pin_dots.dart';
import 'package:texerp/core/widgets/app_toast.dart';
import 'package:texerp/features/auth/presentation/auth_bloc.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String _errorMessage = '';
  bool _isLoading = true;
  bool _useBiometric = false;
  String? _savedPin;

  final LocalAuthentication _localAuth = LocalAuthentication();
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _loadSettingsAndAuth();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettingsAndAuth() async {
    final storage = context.read<SecureStorage>();
    _savedPin = await storage.loadSavedPin();
    _useBiometric = await storage.getUseBiometric();

    setState(() {
      _isLoading = false;
    });

    if (_useBiometric) {
      // Auto-trigger biometric authentication on launch after a small layout build delay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authenticateWithBiometrics();
      });
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Ilovaga kirish uchun tasdiqlang',
        persistAcrossBackgrounding: true,
        biometricOnly: true,
      );
      if (authenticated && mounted) {
        context.read<AuthBloc>().add(const AuthUnlockRequested());
      }
    } catch (_) {
      // Ignore errors (e.g. cancelled), let user enter PIN
    }
  }

  void _onDigitTapped(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _errorMessage = '';
        _pin += digit;
      });

      if (_pin.length == 4) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (!mounted) return;
          _verifyPin(_pin);
        });
      }
    }
  }

  void _onBackspaceTapped() {
    if (_pin.isNotEmpty) {
      setState(() {
        _errorMessage = '';
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _verifyPin(String enteredPin) {
    if (_savedPin == enteredPin) {
      context.read<AuthBloc>().add(const AuthUnlockRequested());
    } else {
      _shakeController.forward(from: 0);
      setState(() {
        _errorMessage = 'PIN-kod notoʻgʻri';
        _pin = '';
      });
      AppToast.show(context, message: _errorMessage, type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CupertinoPageScaffold(
        child: Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(
              CupertinoIcons.lock_shield,
              size: 64,
              color: CupertinoTheme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            const Text(
              'Ilova qulflangan',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.labelPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Davom etish uchun PIN-kodni kiriting',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.labelSecondary,
              ),
            ),
            const SizedBox(height: 32),
            AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final double offset = (1.0 - _shakeController.value) *
                    15 *
                    double.parse(((_shakeController.value * 5).floor() % 2 == 0 ? 1 : -1).toString());
                return Transform.translate(
                  offset: Offset(_shakeController.isAnimating ? offset : 0, 0),
                  child: child,
                );
              },
              child: PinDots(
                pin: _pin,
                hasError: _errorMessage.isNotEmpty,
              ),
            ),
            const Spacer(),
            NumPad(
              onDigit: _onDigitTapped,
              onBackspace: _onBackspaceTapped,
              leftButton: _useBiometric
                  ? CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _authenticateWithBiometrics,
                      child: Icon(
                        CupertinoIcons.device_phone_portrait,
                        size: 28,
                        color: CupertinoTheme.of(context).primaryColor,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
