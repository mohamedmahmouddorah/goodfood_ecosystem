import 'package:flutter/material.dart';

import '../localization/goodfood_localizations.dart';

class AppTrashButton extends StatelessWidget {
  const AppTrashButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: IconButton(
      tooltip: context.tr(label),
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      visualDensity: VisualDensity.standard,
      icon: const Icon(
        Icons.delete_outline_rounded,
        color: Color(0xFFEF4444),
        size: 24,
      ),
    ),
  );
}
