import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:texerp/core/l10n/locale_cubit.dart';
import 'package:texerp/features/auth/presentation/auth_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController(text: '+998 ');
  final _phoneFocusNode = FocusNode();
  final _pinFocusNode = FocusNode();

  String _pin = '';
  bool _phoneError = false;
  bool _pinError = false;
  bool _showPin = false;

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
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    _pinFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  String get _rawDigits => _phoneController.text
      .replaceFirst('+998 ', '')
      .replaceAll(RegExp(r'\D'), '');

  bool get _phoneComplete => _rawDigits.length == 9;
  bool get _pinComplete => _pin.length == 4;
  bool get _canLogin => _phoneComplete && _pinComplete;

  void _onPhoneChanged(String value) {
    setState(() {
      _phoneError = false;
      _showPin = _phoneComplete;
    });
  }

  void _onPinChanged(String value) {
    setState(() {
      _pin = value;
      _pinError = false;
    });
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
  }

  void _clearPin() {
    setState(() {
      _pin = '';
    });
    _pinFocusNode.requestFocus();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onLoginPressed() {
    if (!_canLogin) return;
    final phone = '+998$_rawDigits';
    context.read<AuthBloc>().add(
          AuthLoginRequested(phone: phone, pin: _pin),
        );
  }

  void _onForgotPin() {
    // PIN reset via OTP is Sprint 2; not implemented yet.
    _showErrorSnackBar('PIN reset is not available yet');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthFailure) {
          final code = state.error.code;
          if (code == 'INVALID_CREDENTIALS') {
            _triggerShake();
            _clearPin();
            _showErrorSnackBar(l10n.wrongPin);
          } else if (code == 'ACCOUNT_LOCKED') {
            _showErrorSnackBar(l10n.accountLocked);
          } else if (code == 'PHONE_NOT_FOUND') {
            setState(() {
              _phoneError = true;
            });
            _showErrorSnackBar(l10n.phoneNotFound);
          } else if (code == 'NETWORK_ERROR') {
            _showErrorSnackBar(l10n.offlineMessage);
          } else {
            _showErrorSnackBar(state.error.message);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: const [_LanguageToggle()],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                _buildLogo(),
                const SizedBox(height: 24),
                Text(
                  l10n.loginTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(flex: 2),
                _buildPhoneField(l10n),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _showPin
                      ? AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(_shakeAnimation.value, 0),
                              child: child,
                            );
                          },
                          child: _buildPinSection(l10n),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),
                _buildLoginButton(l10n),
                const SizedBox(height: 12),
                _buildForgotPinButton(l10n),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      height: 80,
      alignment: Alignment.center,
      child: const FlutterLogo(size: 80),
    );
  }

  Widget _buildPhoneField(AppLocalizations l10n) {
    return TextField(
      controller: _phoneController,
      focusNode: _phoneFocusNode,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        _PhoneInputFormatter(),
        LengthLimitingTextInputFormatter(16), // '+998 XX XXX XX XX'
      ],
      decoration: InputDecoration(
        labelText: l10n.phoneNumber,
        prefixText: '+998 ',
        errorText: _phoneError ? l10n.phoneNotFound : null,
      ),
      onChanged: _onPhoneChanged,
    );
  }

  Widget _buildPinSection(AppLocalizations l10n) {
    return Column(
      key: const ValueKey('pin_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.pinLabel,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        _PinDots(
          pin: _pin,
          hasError: _pinError,
          onTap: () => _pinFocusNode.requestFocus(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 0,
          child: TextField(
            focusNode: _pinFocusNode,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: _onPinChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(AppLocalizations l10n) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return ElevatedButton(
          onPressed: isLoading || !_canLogin ? null : _onLoginPressed,
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.loginButton),
        );
      },
    );
  }

  Widget _buildForgotPinButton(AppLocalizations l10n) {
    return TextButton(
      onPressed: _onForgotPin,
      child: Text(l10n.forgotPin),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context) {
    final localeCubit = context.watch<LocaleCubit>();
    final isUz = localeCubit.state.languageCode == 'uz';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: isUz ? null : () => localeCubit.setLocale(const Locale('uz')),
          child: const Text('UZ'),
        ),
        const Text('|'),
        TextButton(
          onPressed: isUz ? () => localeCubit.setLocale(const Locale('ru')) : null,
          child: const Text('RU'),
        ),
      ],
    );
  }
}

class _PhoneInputFormatter extends TextInputFormatter {
  static const _prefix = '+998 ';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.text.startsWith(_prefix)) {
      return oldValue;
    }
    final digits = newValue.text.substring(_prefix.length).replaceAll(RegExp(r'\D'), '');
    final limited = digits.substring(0, digits.length.clamp(0, 9));
    final formatted = _format(limited);
    final text = '$_prefix$formatted';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  String _format(String digits) {
    if (digits.length <= 2) return digits;
    if (digits.length <= 5) {
      return '${digits.substring(0, 2)} ${digits.substring(2)}';
    }
    if (digits.length <= 7) {
      return '${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5)}';
    }
    return '${digits.substring(0, 2)} ${digits.substring(2, 5)} ${digits.substring(5, 7)} ${digits.substring(7)}';
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({
    required this.pin,
    required this.hasError,
    required this.onTap,
  });

  final String pin;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Row(
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
      ),
    );
  }
}
