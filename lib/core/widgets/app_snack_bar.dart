import 'package:goodfood_ecosystem/core/localization/goodfood_localizations.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppSnackBar(
  BuildContext context, {
  required String message,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 3),
  ValueListenable<String>? messageListenable,
}) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final messenger = ScaffoldMessenger.of(context);
  final compact = screenWidth <= 320;
  messenger.clearSnackBars();
  final content = messageListenable == null
      ? AppText(message)
      : ValueListenableBuilder<String>(
          valueListenable: messageListenable,
          builder: (context, value, _) => AppText(value),
        );
  return messenger.showSnackBar(
    SnackBar(
      content: compact && action != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () {
                      action.onPressed();
                      messenger.hideCurrentSnackBar();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: action.textColor,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: AppText(action.label),
                  ),
                ),
              ],
            )
          : content,
      behavior: compact ? SnackBarBehavior.fixed : SnackBarBehavior.floating,
      width: screenWidth > 600
          ? (screenWidth - 48).clamp(0.0, 560.0).toDouble()
          : null,
      duration: duration,
      action: compact || action == null
          ? null
          : SnackBarAction(
              label: context.tr(action.label),
              onPressed: action.onPressed,
              textColor: action.textColor,
              disabledTextColor: action.disabledTextColor,
              backgroundColor: action.backgroundColor,
              disabledBackgroundColor: action.disabledBackgroundColor,
            ),
    ),
  );
}

void clearAppSnackBars(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..clearSnackBars();
}
