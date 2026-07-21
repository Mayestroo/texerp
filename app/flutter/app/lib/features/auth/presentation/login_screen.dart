import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:texerp/core/l10n/locale_cubit.dart';
import 'package:texerp/features/auth/presentation/auth_bloc.dart';
import 'package:texerp/generated/app_localizations.dart';
import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/core/widgets/segmented_toggle.dart';
import 'package:texerp/core/widgets/app_toast.dart';
// ─────────────────────────────────────────────────────────────────────────────
// LoginScreen
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController(text: '');
  final _phoneFocusNode = FocusNode();

  String _pin = '';
  bool _phoneError = false;
  bool _showPin = false;
  bool _hasError = false;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  String get _rawDigits =>
      _phoneController.text.replaceAll(RegExp(r'\D'), '');
  bool get _phoneComplete => _rawDigits.length == 9;
  bool get _pinComplete => _pin.length == 4;
  bool get _canLogin => _phoneComplete && _pinComplete;

  void _onPhoneChanged(String value) {
    setState(() {
      _phoneError = false;
      if (!_phoneComplete) _pin = '';
    });
  }

  void _onDigitTapped(String digit) {
    if (_pin.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _hasError = false;
      _pin += digit;
    });
    if (_pin.length == 4) {
      Future.microtask(_onLoginPressed);
    }
  }

  void _onBackspaceTapped() {
    if (_pin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _hasError = false;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  void _triggerShake() {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0);
  }

  void _clearPin() => setState(() {
        _pin = '';
        _hasError = true;
      });

  void _onLoginPressed() {
    if (!_canLogin) return;
    context.read<AuthBloc>().add(
          AuthLoginRequested(phone: '+998$_rawDigits', pin: _pin),
        );
  }

  void _onForgotPin() => AppToast.show(context, message: 'PIN reset is not available yet', type: ToastType.info);

  // ─── build ────────────────────────────────────────────────────────────────

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
            AppToast.show(context, message: l10n.wrongPin, type: ToastType.error);
          } else if (code == 'ACCOUNT_LOCKED') {
            AppToast.show(context, message: l10n.accountLocked, type: ToastType.error);
          } else if (code == 'PHONE_NOT_FOUND') {
            setState(() => _phoneError = true);
            AppToast.show(context, message: l10n.phoneNotFound, type: ToastType.error);
          } else if (code == 'NETWORK_ERROR') {
            AppToast.show(context, message: l10n.offlineMessage, type: ToastType.error);
          } else {
            AppToast.show(context, message: state.error.message, type: ToastType.error);
          }
        }
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          automaticallyImplyLeading: false,
          trailing: const _LanguageToggle(),
        ),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, animation) {
              final isPin = child.key == const ValueKey('pin');
              final slide = Tween<Offset>(
                begin: isPin ? const Offset(1.0, 0) : const Offset(-1.0, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ));
              return SlideTransition(position: slide, child: child);
            },
            child: _showPin ? _buildPinScreen(l10n) : _buildPhoneScreen(l10n),
          ),
        ),
      ),
    );
  }

  // ─── Phone screen ─────────────────────────────────────────────────────────

  Widget _buildPhoneScreen(AppLocalizations l10n) {
    return CustomScrollView(
      key: const ValueKey('phone'),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                _buildLogo(),
                const SizedBox(height: 16),
                Text(
                  l10n.loginTitle,
                  textAlign: TextAlign.center,
                  style: CupertinoTheme.of(context)
                      .textTheme
                      .navTitleTextStyle
                      .copyWith(fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.labelPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.phoneNumber,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.labelSecondary,
                    fontSize: 15,
                    inherit: true,
                  ),
                ),
                const SizedBox(height: 32),
                _buildPhoneField(l10n),
                const Spacer(),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24, top: 16),
                    child: SizedBox(
                      height: 48,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        color: CupertinoTheme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(12),
                        onPressed: _phoneComplete 
                            ? () {
                                _phoneFocusNode.unfocus();
                                setState(() => _showPin = true);
                              }
                            : null,
                        child: Text(
                          l10n.submit,
                          style: const TextStyle(
                            color: AppColors.labelPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return Container(
      height: 80,
      alignment: Alignment.center,
      child: Icon(
        CupertinoIcons.rectangle_3_offgrid,
        size: 80,
        color: CupertinoTheme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildPhoneField(AppLocalizations l10n) {
    final theme = CupertinoTheme.of(context);
    return CupertinoTextField(
      controller: _phoneController,
      focusNode: _phoneFocusNode,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        _PhoneInputFormatter(),
        LengthLimitingTextInputFormatter(16),
      ],
      placeholder: '90 123 45 67',
      placeholderStyle: theme.textTheme.textStyle.copyWith(
        color: CupertinoColors.placeholderText,
      ),
      prefix: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Text(
          '+998',
          style: theme.textTheme.textStyle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.labelPrimary,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      style: const TextStyle(color: AppColors.labelPrimary),
      decoration: BoxDecoration(
        color: theme.barBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: _phoneError
            ? Border.all(color: CupertinoColors.destructiveRed, width: 1.5)
            : null,
      ),
      onChanged: _onPhoneChanged,
    );
  }

  Widget _buildForgotPinButton(AppLocalizations l10n) {
    return CupertinoButton(
      onPressed: _onForgotPin,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Text(
        l10n.forgotPin,
        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontSize: 14,
          color: CupertinoTheme.of(context).primaryColor,
        ),
      ),
    );
  }

  // ─── PIN screen ───────────────────────────────────────────────────────────

  Widget _buildPinScreen(AppLocalizations l10n) {
    return BlocBuilder<AuthBloc, AuthState>(
      key: const ValueKey('pin'),
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        
        final rawPhone = _phoneController.text;
        final maskedPhone = rawPhone.length == 12 
            ? '+998 ${rawPhone.substring(0, 2)} *** ** ${rawPhone.substring(10, 12)}'
            : '+998 $rawPhone';

        return Stack(
          children: [
            Positioned(
              top: 8,
              left: 8,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                onPressed: isLoading
                    ? null
                    : () => setState(() {
                          _showPin = false;
                          _pin = '';
                          _hasError = false;
                        }),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.chevron_left, size: 18),
                    const SizedBox(width: 4),
                    Text(l10n.phoneNumber,
                        style: const TextStyle(fontSize: 16, inherit: true)),
                  ],
                ),
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                  Text(
                    maskedPhone,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.labelSecondary,
                      inherit: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.pinLabel,
                    textAlign: TextAlign.center,
                    style: CupertinoTheme.of(context)
                        .textTheme
                        .navTitleTextStyle
                        .copyWith(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.labelPrimary),
                  ),
                  const SizedBox(height: 32),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: isLoading ? 2 : 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: isLoading
                        ? const CupertinoActivityIndicator()
                        : const SizedBox.shrink(),
                  ),
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      final t = _shakeAnimation.value;
                      final shake = _shakeController.isAnimating
                          ? 16 * (0.5 - (t - 0.5).abs()) * 2
                          : 0.0;
                      return Transform.translate(
                        offset: Offset(shake, 0),
                        child: child,
                      );
                    },
                    child: PinDots(pin: _pin, hasError: _hasError),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildForgotPinButton(l10n),
                      const SizedBox(width: 16),
                      CupertinoButton(
                        padding: const EdgeInsets.all(8),
                        onPressed: () => AppToast.show(context, message: 'Biometric auth not configured', type: ToastType.info),
                        child: Icon(
                          CupertinoIcons.person_crop_circle_fill,
                          color: CupertinoTheme.of(context).primaryColor,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _NumPad(
                    onDigit: isLoading ? (_) {} : _onDigitTapped,
                    onBackspace: isLoading ? () {} : _onBackspaceTapped,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LanguageToggle
// ─────────────────────────────────────────────────────────────────────────────

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context) {
    final localeCubit = context.watch<LocaleCubit>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedToggle<String>(
        groupValue: localeCubit.state.languageCode,
        children: const {
          'uz': 'UZ',
          'ru': 'RU',
        },
        onValueChanged: (value) => localeCubit.setLocale(Locale(value)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PhoneInputFormatter
// ─────────────────────────────────────────────────────────────────────────────

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.substring(0, digits.length.clamp(0, 9));
    final formatted = _format(limited);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
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

// ─────────────────────────────────────────────────────────────────────────────
// _PinDots
// ─────────────────────────────────────────────────────────────────────────────

class PinDots extends StatelessWidget {
  const PinDots({required this.pin, required this.hasError});

  final String pin;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final activeColor =
        hasError ? CupertinoColors.destructiveRed : primaryColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final filled = index < pin.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutBack,
          width: filled ? 20 : 16,
          height: filled ? 20 : 16,
          margin: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? activeColor : const Color(0x00000000),
            border: filled
                ? null
                : Border.all(
                    color: AppColors.labelTertiary,
                    width: 1.5,
                  ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NumPad
// ─────────────────────────────────────────────────────────────────────────────

class _NumPad extends StatelessWidget {
  const _NumPad({required this.onDigit, required this.onBackspace});

  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', '⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: _rows.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map<Widget>((key) {
                if (key.isEmpty) {
                  return const SizedBox(width: 80, height: 80);
                }
                if (key == '⌫') {
                  return _NumPadKey(
                    onTap: onBackspace,
                    label: 'Delete',
                    child: const Icon(
                      CupertinoIcons.delete_left,
                      size: 26,
                      color: AppColors.labelPrimary,
                    ),
                  );
                }
                return _NumPadKey(
                  onTap: () => onDigit(key),
                  label: key,
                  child: Text(
                    key,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      color: AppColors.labelPrimary,
                      inherit: true,
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NumPadKey
// ─────────────────────────────────────────────────────────────────────────────

class _NumPadKey extends StatefulWidget {
  const _NumPadKey({required this.onTap, required this.child, required this.label});

  final VoidCallback onTap;
  final Widget child;
  final String label;

  @override
  State<_NumPadKey> createState() => _NumPadKeyState();
}

class _NumPadKeyState extends State<_NumPadKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      button: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _pressed
                ? CupertinoColors.systemGrey5.resolveFrom(context)
                : CupertinoColors.tertiarySystemGroupedBackground.resolveFrom(context),
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}

// Removed old showCupertinoToast function
