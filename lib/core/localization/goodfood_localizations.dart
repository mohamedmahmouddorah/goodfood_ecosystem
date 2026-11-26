import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'arabic_messages.dart';

/// The app's single catalog for UI copy. Server/user content stays unchanged.
class GoodFoodLocalizations {
  const GoodFoodLocalizations(this.locale);
  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('ar')];
  static const delegate = _GoodFoodDelegate();
  static GoodFoodLocalizations of(BuildContext context) =>
      Localizations.of<GoodFoodLocalizations>(context, GoodFoodLocalizations) ??
      const GoodFoodLocalizations(Locale('en'));

  String text(String source) {
    if (locale.languageCode != 'ar') return englishOverrides[source] ?? source;
    final exact = arabicMessages[source];
    if (exact != null) return exact;
    for (final entry in _templates) {
      final match = entry.pattern.firstMatch(source);
      if (match == null) continue;
      return entry.translation.replaceAllMapped(
        RegExp(r'\{(\d+)\}'),
        (token) => match.group(int.parse(token[1]!) + 1)!,
      );
    }
    return source;
  }

  static final _templates = arabicTemplates.entries.map((entry) {
    final parts = entry.key.split(RegExp(r'\{\d+\}'));
    final pattern = parts.map(RegExp.escape).join('(.+?)');
    return (
      pattern: RegExp('^$pattern\$', dotAll: true),
      translation: entry.value,
    );
  }).toList();
}

class _GoodFoodDelegate extends LocalizationsDelegate<GoodFoodLocalizations> {
  const _GoodFoodDelegate();
  @override
  bool isSupported(Locale locale) => ['ar', 'en'].contains(locale.languageCode);
  @override
  Future<GoodFoodLocalizations> load(Locale locale) =>
      SynchronousFuture(GoodFoodLocalizations(locale));
  @override
  bool shouldReload(_GoodFoodDelegate old) => false;
}

extension GoodFoodTranslation on BuildContext {
  String tr(String source) => GoodFoodLocalizations.of(this).text(source);
}

/// Keeps existing Text styling/const layouts while reacting to locale changes.
/// Pass server content to ordinary Text rather than translating that content.
class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });
  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) => Text(
    context.tr(data),
    style: style,
    strutStyle: strutStyle,
    textAlign: textAlign,
    textDirection: textDirection,
    locale: locale,
    softWrap: softWrap,
    overflow: overflow,
    textScaler: textScaler,
    maxLines: maxLines,
    semanticsLabel: semanticsLabel == null ? null : context.tr(semanticsLabel!),
    textWidthBasis: textWidthBasis,
    textHeightBehavior: textHeightBehavior,
    selectionColor: selectionColor,
  );
}
