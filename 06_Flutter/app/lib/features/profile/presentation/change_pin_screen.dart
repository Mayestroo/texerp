import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:texerp/features/auth/presentation/auth_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen>
    with SingleTickerProviderStateMixin {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();

  int _step = 0; // 0 = current, 1 = new, 2 = confirm
  String _newPin = '';
  String _confirmPin = '';
  String _errorMessage = '';

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
    _requestFocus();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _requestFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
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

  void _onPinChanged(String value) {
    setState(() {
      _errorMessage = '';
    });
    if (value.length != 4) return;

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

  void _validateCurrentPin(String pin) {
    // For the MVP stub the current PIN is verified against the in-memory PIN
    // captured at login. Once the backend exposes POST /users/me/pin this will
    // be replaced by a server check.
    if (_currentPin.isNotEmpty && pin != _currentPin) {
      _triggerError(AppLocalizations.of(context)!.currentPinIncorrect);
      return;
    }
    _pinController.clear();
    setState(() {
      _step = 1;
    });
    _requestFocus();
  }

  void _validateNewPin(String pin) {
    if (_isWeakPin(pin)) {
      _triggerError(AppLocalizations.of(context)!.simplePinWarning);
      return;
    }
    setState(() {
      _newPin = pin;
      _step = 2;
    });
    _pinController.clear();
    _requestFocus();
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
      _pinController.clear();
    });
    _focusNode.requestFocus();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    // Backend endpoint POST /users/me/pin is not wired up yet.
    // ignore: avoid_print
    debugPrint('PIN change stub: $_newPin');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.pinChanged)));
    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.changePin),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Text(
                _stepLabel(l10n),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
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
                child: _PinDots(
                  pin: _pinController.text,
                  hasError: _errorMessage.isNotEmpty,
                ),
              ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                height: 0,
                child: TextField(
                  controller: _pinController,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: _onPinChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.pin, required this.hasError});

  final String pin;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final filled = index < pin.length;
        return Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? (hasError ? colorScheme.error : colorScheme.primary)
                : colorScheme.outline,
          ),
        );
      }),
    );
  }
}
