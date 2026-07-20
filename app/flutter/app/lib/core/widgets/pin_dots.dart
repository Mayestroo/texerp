import 'package:flutter/cupertino.dart';
import 'package:texerp/core/theme/app_theme.dart';

class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.pin, required this.hasError});

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
