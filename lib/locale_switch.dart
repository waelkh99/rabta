// Choosing the interface language.
//
// A seller's browser is often set to English on a machine they share or did not
// configure, which is not the language they want to work in. The choice sits on
// the sign-in screen because that is the first thing they see, and being unable
// to read that screen is the one failure they cannot click past.

import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'prefs.dart';
import 'theme.dart';

/// The language chosen in this tab, or null until somebody chooses one.
///
/// It used to stop there, with a note saying the durable home was the seller's
/// own row once a profile existed, and that a local preference would be a
/// second source of truth to reconcile later. **Changed 22 September 2026**,
/// and the reasoning inverted rather than merely expired: per-device is not a
/// compromise here, it is the correct answer. The case this exists for is a
/// browser set to a language the seller did not choose — a machine at a
/// counter, a laptop somebody else configured — and the same seller can easily
/// want Arabic on one and English on another. A language attached to the
/// account would be wrong on one of those machines every time.
///
/// So there is no second source of truth to reconcile. There is one, and it is
/// the browser.
final currentLocale = ValueNotifier<Locale?>(null);

/// What was chosen here last time, if anything.
///
/// Ranked below `?lang=` in `main.dart`: a link someone has just been sent is a
/// more recent statement of intent than a choice made on a previous visit.
Locale? get savedLocale {
  final code = savedLanguage;
  return code == null ? null : Locale(code);
}

/// Applies a language and remembers it, which are one action from the seller's
/// side and must not come apart.
void chooseLocale(Locale locale) {
  savedLanguage = locale.languageCode;
  currentLocale.value = locale;
}

class LocaleSwitch extends StatelessWidget {
  const LocaleSwitch({super.key, this.compact = false});

  /// In the header of the inbox, where there is no room for two words.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final active = Localizations.localeOf(context).languageCode;

    // Each language names itself, in its own script. "Arabic" written in
    // English is no use to someone who cannot read the English interface.
    const names = {'ar': 'العربية', 'en': 'English'};

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final locale in L.supportedLocales)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: _Choice(
              label: names[locale.languageCode] ?? locale.languageCode,
              selected: locale.languageCode == active,
              compact: compact,
              onTap: () => chooseLocale(locale),
              colors: colors,
            ),
          ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
    required this.colors,
  });

  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;
  final RabtaColors colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 4 : 7,
            ),
            decoration: BoxDecoration(
              color: selected ? colors.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: (compact ? Style.meta : Style.preview).copyWith(
                color: selected ? colors.accent : colors.muted,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
