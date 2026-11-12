import 'package:flutter/material.dart';

enum AppButtonVariant { filled, outlined, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.variant = AppButtonVariant.filled,
    this.foregroundColor,
    this.backgroundColor,
    this.borderColor,
    this.minimumHeight = 44,
    this.isLoading = false,
    this.tooltip,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final AppButtonVariant variant;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final double minimumHeight;
  final bool isLoading;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground =
        foregroundColor ??
        (variant == AppButtonVariant.filled
            ? colorScheme.onPrimary
            : colorScheme.primary);
    final content = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            )
          else if (icon != null)
            Icon(icon, size: 18),
          if (isLoading || icon != null) const SizedBox(width: 8),
          child,
        ],
      ),
    );
    final size = Size(0, minimumHeight);

    final button = switch (variant) {
      AppButtonVariant.filled => FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: backgroundColor ?? colorScheme.primary,
          minimumSize: size,
        ),
        child: content,
      ),
      AppButtonVariant.outlined => OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          side: BorderSide(color: borderColor ?? foreground),
          minimumSize: size,
        ),
        child: content,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          minimumSize: size,
        ),
        child: content,
      ),
    };
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
