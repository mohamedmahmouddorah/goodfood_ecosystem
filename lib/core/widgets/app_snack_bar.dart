import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../localization/goodfood_localizations.dart';

enum FeedbackKind { success, error, warning, info }

(Color, IconData) _appearance(BuildContext context, FeedbackKind kind) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  return switch (kind) {
    FeedbackKind.success => (
      dark ? const Color(0xFF73DBA5) : const Color(0xFF18764B),
      Icons.check_circle_outline,
    ),
    FeedbackKind.error => (theme.colorScheme.error, Icons.error_outline),
    FeedbackKind.warning => (
      dark ? const Color(0xFFFFCC70) : const Color(0xFF865600),
      Icons.warning_amber_rounded,
    ),
    FeedbackKind.info => (
      dark ? const Color(0xFF87CDFF) : const Color(0xFF1967A2),
      Icons.info_outline,
    ),
  };
}

class AppInlineFeedback extends StatelessWidget {
  const AppInlineFeedback(
    this.message, {
    super.key,
    this.kind = FeedbackKind.error,
  });

  final String message;
  final FeedbackKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (accent, _) = _appearance(context, kind);
    return Center(
      heightFactor: 1,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            accent.withValues(alpha: .08),
            colors.surface,
          ),
          border: Border.all(color: accent.withValues(alpha: .42)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Semantics(
          liveRegion: true,
          child: _feedbackContent(context, message, kind),
        ),
      ),
    );
  }
}

Widget _feedbackContent(
  BuildContext context,
  String message,
  FeedbackKind kind, {
  bool brief = false,
}) {
  final (accent, icon) = _appearance(context, kind);
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: accent, size: 20),
      const SizedBox(width: 8),
      Expanded(
        child: AppText(
          message,
          maxLines: brief ? 2 : null,
          overflow: brief ? TextOverflow.ellipsis : null,
          semanticsLabel: message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
          ),
        ),
      ),
    ],
  );
}

ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppSnackBar(
  BuildContext context, {
  required String message,
  FeedbackKind kind = FeedbackKind.info,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 3),
  ValueListenable<String>? messageListenable,
}) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final messenger = ScaffoldMessenger.of(context);
  final colors = Theme.of(context).colorScheme;
  final (accent, _) = _appearance(context, kind);
  final compactAction = screenWidth <= 360 && action != null;
  final content = messageListenable == null
      ? _feedbackContent(context, message, kind, brief: true)
      : ValueListenableBuilder<String>(
          valueListenable: messageListenable,
          builder: (context, value, _) =>
              _feedbackContent(context, value, kind, brief: true),
        );

  clearAppSnackBars(context);
  return messenger.showSnackBar(
    SnackBar(
      content: compactAction
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
                      foregroundColor: action.textColor ?? colors.onSurface,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: AppText(action.label),
                  ),
                ),
              ],
            )
          : content,
      behavior: SnackBarBehavior.floating,
      width: screenWidth > 600 ? 560 : null,
      margin: screenWidth > 600
          ? null
          : const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      backgroundColor: colors.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: accent.withValues(alpha: .42)),
      ),
      showCloseIcon: kind == FeedbackKind.error && action == null,
      closeIconColor: colors.onSurface,
      duration: duration,
      action: compactAction || action == null
          ? null
          : SnackBarAction(
              label: context.tr(action.label),
              onPressed: action.onPressed,
              textColor: action.textColor ?? colors.onSurface,
              disabledTextColor: action.disabledTextColor,
              backgroundColor: action.backgroundColor,
              disabledBackgroundColor: action.disabledBackgroundColor,
            ),
    ),
  );
}

void clearAppSnackBars(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..removeCurrentSnackBar();
}
