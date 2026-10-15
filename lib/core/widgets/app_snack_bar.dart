import 'package:flutter/material.dart';

ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppSnackBar(
  BuildContext context, {
  required String message,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 3),
}) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final messenger = ScaffoldMessenger.of(context);
  final compact = screenWidth <= 320;
  messenger.clearSnackBars();
  return messenger.showSnackBar(
    SnackBar(
      content: compact && action != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      action.onPressed();
                      messenger.hideCurrentSnackBar();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: action.textColor,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(action.label),
                  ),
                ),
              ],
            )
          : Text(message),
      behavior: compact ? SnackBarBehavior.fixed : SnackBarBehavior.floating,
      width: screenWidth > 600
          ? (screenWidth - 48).clamp(0.0, 560.0).toDouble()
          : null,
      duration: duration,
      action: compact ? null : action,
    ),
  );
}

void clearAppSnackBars(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..clearSnackBars();
}
