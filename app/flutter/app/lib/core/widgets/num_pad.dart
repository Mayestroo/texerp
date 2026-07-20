import 'package:flutter/cupertino.dart';
import 'package:texerp/core/theme/app_theme.dart';

class NumPad extends StatelessWidget {
  const NumPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.leftButton,
  });

  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final Widget? leftButton;

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
                  if (leftButton != null) {
                    return SizedBox(
                      width: 80,
                      height: 80,
                      child: Center(child: leftButton),
                    );
                  }
                  return const SizedBox(width: 80, height: 80);
                }
                if (key == '⌫') {
                  return NumPadKey(
                    onTap: onBackspace,
                    label: 'Delete',
                    child: const Icon(
                      CupertinoIcons.delete_left,
                      size: 26,
                      color: AppColors.labelPrimary,
                    ),
                  );
                }
                return NumPadKey(
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

class NumPadKey extends StatefulWidget {
  const NumPadKey({
    super.key, 
    required this.onTap, 
    required this.child, 
    required this.label,
  });

  final VoidCallback onTap;
  final Widget child;
  final String label;

  @override
  State<NumPadKey> createState() => _NumPadKeyState();
}

class _NumPadKeyState extends State<NumPadKey> {
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
