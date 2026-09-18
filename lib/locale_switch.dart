// Choosing the interface language.
//
// A seller's browser is often set to English on a machine they share or did not
// configure, which is not the language they want to work in. The choice sits on
// the sign-in screen because that is the first thing they see, and being unable
// to read that screen is the one failure they cannot click past.

import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'theme.dart';

/// ponytail: in memory, so a reload falls back to the browser again. The
/// durable home for this is the seller's own row once there is a profile —
/// a local preference would be a second source of truth to reconcile later.
final currentLocale = ValueNotifier<Locale?>(null);

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
              onTap: () => currentLocale.value = locale,
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
