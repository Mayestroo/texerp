import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:texerp/core/error/network_exception.dart';
import 'package:texerp/features/auth/data/auth_repository.dart';
import 'package:texerp/features/auth/presentation/auth_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/core/widgets/num_pad.dart';
import 'package:texerp/core/widgets/pin_dots.dart';
import 'package:texerp/core/widgets/app_toast.dart';
class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen>
    with SingleTickerProviderStateMixin {
  
  int _step = 0;
  String _pin = '';
  String _newPin = '';
  String _confirmPin = '';
  String _typedCurrentPin = '';
  String _errorMessage = '';
  bool _isLoading = false;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  String get _currentPin => context.read<AuthBloc>().state.currentPin ?? '';

  String _stepLabel(AppLocalizations l10n) {
    switch (_step) {
      case 0:
        return l10n.currentPin;
      case 1:
        return l10n.newPin;
      case 2:
        return l10n.confirmNewPin;
      default:
        return '';
    }
  }

  void _onDigitTapped(String digit) {
    if (_isLoading) return;
    if (_pin.length < 4) {
      setState(() {
        _errorMessage = '';
        _pin += digit;
      });

      if (_pin.length == 4) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (!mounted) return;
          _onPinComplete(_pin);
        });
      }
    }
  }

  void _onBackspaceTapped() {
    if (_isLoading) return;
    if (_pin.isNotEmpty) {
      setState(() {
        _errorMessage = '';
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _onPinComplete(String value) {
    switch (_step) {
      case 0:
        _validateCurrentPin(value);
        break;
      case 1:
        _validateNewPin(value);
        break;
      case 2:
        _validateConfirmPin(value);
        break;
    }
  }

  Future<void> _validateCurrentPin(String pin) async {
    if (_currentPin.isNotEmpty) {
      if (pin != _currentPin) {
        _triggerError(AppLocalizations.of(context)!.currentPinIncorrect);
        return;
      }
      setState(() {
        _typedCurrentPin = pin;
        _pin = '';
        _step = 1;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<AuthRepository>().verifyPin(pin).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw const NetworkException(code: 'TIMEOUT', message: 'Ulanish vaqti tugadi'),
      );
      if (!mounted) return;
      setState(() {
        _typedCurrentPin = pin;
        _pin = '';
        _step = 1;
      });
    } catch (e) {
      if (!mounted) return;
      String errorMessage = 'Joriy PIN noto\'g\'ri';
      if (e is NetworkException) {
        errorMessage = e.message;
      }
      try {
        AppToast.show(context, message: errorMessage, type: ToastType.error);
      } catch (_) {}
      _triggerError(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _validateNewPin(String pin) {
    if (_isWeakPin(pin)) {
      _triggerError(AppLocalizations.of(context)!.simplePinWarning);
      return;
    }
    setState(() {
      _newPin = pin;
      _pin = '';
      _step = 2;
    });
  }

  void _validateConfirmPin(String pin) {
    setState(() {
      _confirmPin = pin;
    });
    if (_confirmPin != _newPin) {
      _triggerError(AppLocalizations.of(context)!.pinMismatch);
      return;
    }
    _submit();
  }

  bool _isWeakPin(String pin) {
    return pin == '0000' || pin == '1111' || pin == '1234' || pin == '9999';
  }

  void _triggerError(String message) {
    _shakeController.forward(from: 0);
    setState(() {
      _errorMessage = message;
      _pin = '';
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    
    try {
      // Added a 15 second timeout to prevent getting stuck forever
      await context.read<AuthRepository>().changePin(_typedCurrentPin, _newPin).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw const NetworkException(code: 'TIMEOUT', message: 'Ulanish vaqti tugadi'),
      );
      
      if (!mounted) return;
      context.read<AuthBloc>().add(AuthPinUpdated(newPin: _newPin));
      AppToast.show(context, message: l10n.pinChanged, type: ToastType.success);
      
      // Give user a brief moment to see all 4 PIN dots filled before disappearing
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/profile');
        }
      }
    } catch (e) {
      if (!mounted) return;
      String errorMessage = 'Xatolik yuz berdi';
      if (e is NetworkException) {
        errorMessage = e.message;
      }
      try {
        AppToast.show(context, message: errorMessage, type: ToastType.error);
      } catch (_) {
        // Fallback if AppToast fails
      }
      _triggerError(errorMessage);
      setState(() {
        _step = 0;
        _pin = '';
        _newPin = '';
        _confirmPin = '';
        _typedCurrentPin = '';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

// Removed _showToast

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: Text(l10n.changePin, style: const TextStyle(color: AppColors.labelPrimary)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back, color: AppColors.labelPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _stepLabel(l10n),
                textAlign: TextAlign.center,
                style: CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.labelPrimary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                );
              },
              child: _isLoading 
                  ? const CupertinoActivityIndicator(radius: 16)
                  : PinDots(
                      pin: _pin,
                      hasError: _errorMessage.isNotEmpty,
                    ),
            ),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 24, right: 24),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    color: CupertinoColors.destructiveRed,
                  ),
                ),
              ),
            const Spacer(),
            NumPad(
              onDigit: _onDigitTapped,
              onBackspace: _onBackspaceTapped,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

