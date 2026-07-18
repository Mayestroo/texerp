import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:texerp/core/theme/app_theme.dart';

enum ToastType { info, success, error }

class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
        duration: duration,
        onDismiss: () {
          if (entry.mounted) {
            entry.remove();
          }
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  final String message;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0), // Start from above the screen
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    Future.delayed(widget.duration, () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData get _icon {
    switch (widget.type) {
      case ToastType.success:
        return CupertinoIcons.check_mark_circled_solid;
      case ToastType.error:
        return CupertinoIcons.exclamationmark_circle_fill;
      case ToastType.info:
      default:
        return CupertinoIcons.info_circle_fill;
    }
  }

  Color get _iconColor {
    switch (widget.type) {
      case ToastType.success:
        return CupertinoColors.activeGreen;
      case ToastType.error:
        return CupertinoColors.destructiveRed;
      case ToastType.info:
      default:
        return AppColors.labelPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    
    return Positioned(
      top: topPadding > 0 ? topPadding + 8 : 16, // Position right below dynamic island / notch
      left: 16,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: Material(
          type: MaterialType.transparency,
          child: Align(
            alignment: Alignment.topCenter,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100), // Pill shape
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), // Glassmorphism
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.darkBackgroundGray.withOpacity(0.7), // Semi-transparent
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: CupertinoColors.white.withOpacity(0.1),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _icon,
                            color: _iconColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              widget.message,
                              style: const TextStyle(
                                color: CupertinoColors.white, // Always white text on dark pill
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
