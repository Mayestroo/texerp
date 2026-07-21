import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:texerp/core/theme/app_theme.dart';
import 'package:texerp/core/widgets/app_toast.dart';
import 'package:texerp/features/settings/data/settings_models.dart';
import 'package:texerp/features/settings/presentation/settings_bloc.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _payrollController = TextEditingController();
  var _initialized = false;

  var _backDateWindowDays = 3;
  var _duplicateWindowMinutes = 60;
  var _suspiciousQuantityMultiplier = 3;
  var _payrollMinPay = 0;
  var _stockNegativeMode = 'HARD_BLOCK';

  @override
  void initState() {
    super.initState();
    context.read<SettingsBloc>().add(const SettingsLoadRequested());
  }

  @override
  void dispose() {
    _payrollController.dispose();
    super.dispose();
  }

  void _applySettings(TenantSettings settings) {
    setState(() {
      _backDateWindowDays = settings.backDateWindowDays;
      _duplicateWindowMinutes = settings.duplicateWindowMinutes;
      _suspiciousQuantityMultiplier = settings.suspiciousQuantityMultiplier;
      _payrollMinPay = settings.payrollMinPay;
      _stockNegativeMode = settings.stockNegativeMode;
      _payrollController.text = _formatTiyinAsSom(settings.payrollMinPay);
    });
  }

  void _onStateChanged(BuildContext context, SettingsState state) {
    if (state is SettingsLoaded && !_initialized) {
      _applySettings(state.settings);
      _initialized = true;
    } else if (state is SettingsUpdated) {
      _applySettings(state.settings);
      AppToast.show(
        context,
        message: 'Sozlamalar saqlandi',
        type: ToastType.success,
      );
    } else if (state is SettingsError) {
      AppToast.show(
        context,
        message: state.message,
        type: ToastType.error,
      );
    }
  }

  String _formatTiyinAsSom(int tiyin) {
    final som = tiyin ~/ 100;
    return NumberFormat.decimalPattern().format(som);
  }

  int _parseSomToTiyin(String text) {
    final digits = text.replaceAll(RegExp(r'[^\d]'), '');
    final som = int.tryParse(digits) ?? 0;
    return som * 100;
  }

  void _onPayrollAmountChanged(String value) {
    final tiyin = _parseSomToTiyin(value);
    _payrollMinPay = tiyin;
    final formatted = _formatTiyinAsSom(tiyin);
    if (_payrollController.text != formatted) {
      _payrollController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  void _adjustValue(
    int current,
    int delta,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) {
    final newValue = (current + delta).clamp(min, max);
    if (newValue != current) {
      onChanged(newValue);
    }
  }

  void _save() {
    final dto = SettingsUpdateDto(
      backDateWindowDays: _backDateWindowDays,
      suspiciousQuantityMultiplier: _suspiciousQuantityMultiplier,
      payrollMinPay: _payrollMinPay,
      duplicateWindowMinutes: _duplicateWindowMinutes,
    );
    context.read<SettingsBloc>().add(SettingsUpdateRequested(dto: dto));
  }

  void _reload() {
    _initialized = false;
    context.read<SettingsBloc>().add(const SettingsLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SettingsBloc, SettingsState>(
      listener: _onStateChanged,
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          final content = _buildContent(context, state);
          if (widget.embedded) {
            return content;
          }
          return CupertinoPageScaffold(
            navigationBar: const CupertinoNavigationBar(
              middle: Text(
                'Sozlamalar',
                style: TextStyle(color: AppColors.labelPrimary),
              ),
            ),
            child: SafeArea(child: content),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, SettingsState state) {
    if (state is SettingsInitial || state is SettingsLoading) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 14),
      );
    }

    if (state is SettingsError && !_initialized) {
      return _buildErrorView(context);
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (widget.embedded) const SizedBox(height: 16),
          _buildSectionTitle('Ishlab chiqarish'),
          _buildCard(
            children: [
              _buildStepperRow(
                label: 'Orqaga sana oynasi (kun)',
                value: _backDateWindowDays,
                min: 1,
                max: 7,
                onChanged: (value) => setState(
                  () => _backDateWindowDays = value,
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildStepperRow(
                label: 'Dublikat oynasi (daqiqa)',
                value: _duplicateWindowMinutes,
                min: 1,
                max: 1440,
                onChanged: (value) => setState(
                  () => _duplicateWindowMinutes = value,
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildStepperRow(
                label: 'Gumdon miqdor ko\'paytiruvchisi',
                value: _suspiciousQuantityMultiplier,
                min: 1,
                max: 10,
                onChanged: (value) => setState(
                  () => _suspiciousQuantityMultiplier = value,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Ish haqi'),
          _buildCard(
            children: [
              _buildPayrollInput(),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Ombor'),
          _buildCard(
            children: [
              _buildStockModeControl(),
            ],
          ),
          const SizedBox(height: 32),
          _buildSaveButton(state is SettingsUpdating),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: AppColors.error,
              size: 44,
            ),
            const SizedBox(height: 16),
            Text(
              'Sozlamalarni yuklashda xatolik',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.labelDark : AppColors.labelLight,
                inherit: true,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton(
              color: CupertinoTheme.of(context).primaryColor,
              onPressed: _reload,
              child: const Text('Qayta urinish'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.labelSecondary,
          inherit: true,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildStepperRow({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppColors.labelDark : AppColors.labelLight,
                inherit: true,
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 36,
            onPressed: () => _adjustValue(value, -1, min, max, onChanged),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0x11FFFFFF) : const Color(0x11000000),
                ),
              ),
              child: Icon(
                CupertinoIcons.minus,
                size: 18,
                color: isDark ? AppColors.labelDark : AppColors.labelLight,
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 48),
            alignment: Alignment.center,
            child: Text(
              value.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.labelDark : AppColors.labelLight,
                inherit: true,
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 36,
            onPressed: () => _adjustValue(value, 1, min, max, onChanged),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor.withOpacity(0.2),
                ),
              ),
              child: Icon(
                CupertinoIcons.plus,
                size: 18,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollInput() {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Minimal to\'lov (so\'m)',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? AppColors.labelDark : AppColors.labelLight,
                    inherit: true,
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: _payrollController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.left,
                  prefix: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(
                      CupertinoIcons.money_dollar_circle,
                      size: 20,
                      color: primaryColor,
                    ),
                  ),
                  suffix: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      'so\'m',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.labelSecondary
                            : AppColors.secondaryLabelLight,
                        inherit: true,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  placeholder: '0',
                  placeholderStyle: TextStyle(
                    color: isDark
                        ? AppColors.labelTertiary
                        : AppColors.secondaryLabelLight,
                  ),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.labelDark : AppColors.labelLight,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000),
                    ),
                  ),
                  onChanged: _onPayrollAmountChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockModeControl() {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Salbiy qoldiq rejimi',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppColors.labelDark : AppColors.labelLight,
                inherit: true,
              ),
            ),
          ),
          SizedBox(
            width: 180,
            child: CupertinoSlidingSegmentedControl<String>(
              groupValue: _stockNegativeMode,
              children: {
                'HARD_BLOCK': Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Blok',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.labelDark : AppColors.labelLight,
                      inherit: true,
                    ),
                  ),
                ),
                'WARNING': Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Ogohlantirish',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.labelDark : AppColors.labelLight,
                      inherit: true,
                    ),
                  ),
                ),
              },
              onValueChanged: (value) {
                if (value != null) {
                  setState(() => _stockNegativeMode = value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(bool isSaving) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: isSaving ? null : _save,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isSaving
            ? const CupertinoActivityIndicator(color: CupertinoColors.white)
            : const Text(
                'Saqlash',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
