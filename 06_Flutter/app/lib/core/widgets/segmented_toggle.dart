import 'package:flutter/cupertino.dart';
import 'package:texerp/core/theme/app_theme.dart';

class SegmentedToggle<T> extends StatelessWidget {
  final T groupValue;
  final Map<T, String> children;
  final ValueChanged<T> onValueChanged;

  const SegmentedToggle({
    super.key,
    required this.groupValue,
    required this.children,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children.entries.map((entry) {
          final isSelected = entry.key == groupValue;
          return GestureDetector(
            onTap: () => onValueChanged(entry.key),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected 
                    ? CupertinoColors.tertiarySystemGroupedBackground.resolveFrom(context)
                    : const Color(0x00000000),
                borderRadius: BorderRadius.circular(12),
                boxShadow: isSelected
                    ? [
                        const BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ]
                    : [],
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected 
                      ? AppColors.labelPrimary 
                      : AppColors.labelSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
