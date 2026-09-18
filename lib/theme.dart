// The interface's point of view, in one place.
//
// Colours are a ThemeExtension rather than a set of constants, because dark
// mode is coming. A widget reads `context.rabta.ink`, so adding the dark
// scheme is one more instance of this class and nothing else changes. Constants
// would mean revisiting every widget instead.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class RabtaColors extends ThemeExtension<RabtaColors> {
  const RabtaColors({
    required this.ground,
    required this.surface,
    required this.raised,
    required this.line,
    required this.edge,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.urgent,
    required this.instagram,
    required this.messenger,
  });

  /// Behind everything.
  final Color ground;

  /// The list, the thread header, message bubbles from the customer.
  final Color surface;

  /// A row that is open or hovered. A shift in ground, never a card.
  final Color raised;

  /// Hairlines inside a pane: between rows, around the window card.
  final Color line;

  /// The boundaries between panes, and the group rules in the list. Tinted
  /// toward the accent rather than neutral grey: a plain grey rule at this
  /// weight disappears against a near-white ground, which is what made the
  /// sections read as one undifferentiated sheet.
  final Color edge;

  /// Names and message text.
  final Color ink;

  /// Previews, timestamps, anything secondary.
  final Color muted;

  /// The seller's own actions and their own words, and nothing else.
  final Color accent;

  /// Text sitting on the accent.
  final Color onAccent;

  /// The accent at reading strength — the wait rail's track fill, quiet
  /// highlights. Stored rather than computed so the dark scheme can pick its
  /// own value instead of inheriting an opacity that only works on white.
  final Color accentSoft;

  /// A reply window about to close, and nothing else.
  final Color urgent;

  final Color instagram;
  final Color messenger;

  /// Light. White ground with a violet accent, closer to the platforms the
  /// product lives inside than the near-monochrome it started as.
  ///
  /// The violet is a single flat colour rather than Instagram's gradient. The
  /// gradient is their identity, not ours, and a gradient behind small text is
  /// unreadable in both scripts.
  ///
  /// The accent is sampled from the app icon rather than chosen alongside it.
  /// The two sit side by side in a browser tab, so they cannot be two different
  /// purples, and of the pair the icon is the harder one to change later.
  static const light = RabtaColors(
    ground: Color(0xFFFAF8FC),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFF2EAFC),
    line: Color(0xFFE5DCF4),
    edge: Color(0xFFCFBDEE),
    ink: Color(0xFF1B1526),
    muted: Color(0xFF6E6880),
    accent: Color(0xFF6010C0),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFEDE1FC),
    urgent: Color(0xFFD1365B),
    instagram: Color(0xFFE1306C),
    messenger: Color(0xFF0866FF),
  );

  /// Dark. Not wired up yet — `main.dart` has no dark theme and no toggle — but
  /// defined so the extension is exercised by both schemes from the start and
  /// the values are chosen once, with the light ones in front of us, rather
  /// than guessed later.
  static const dark = RabtaColors(
    ground: Color(0xFF130F1A),
    surface: Color(0xFF1C1726),
    raised: Color(0xFF272034),
    line: Color(0xFF322A42),
    edge: Color(0xFF473A5E),
    ink: Color(0xFFF1EDF7),
    muted: Color(0xFF9D95AE),
    accent: Color(0xFFA779F0),
    onAccent: Color(0xFF1B1526),
    accentSoft: Color(0xFF2E2440),
    urgent: Color(0xFFFF8098),
    instagram: Color(0xFFF06595),
    messenger: Color(0xFF5B9DFF),
  );

  Color platform(String name) => name == 'instagram' ? instagram : messenger;

  @override
  RabtaColors copyWith({
    Color? ground,
    Color? surface,
    Color? raised,
    Color? line,
    Color? edge,
    Color? ink,
    Color? muted,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? urgent,
    Color? instagram,
    Color? messenger,
  }) =>
      RabtaColors(
        ground: ground ?? this.ground,
        surface: surface ?? this.surface,
        raised: raised ?? this.raised,
        line: line ?? this.line,
        edge: edge ?? this.edge,
        ink: ink ?? this.ink,
        muted: muted ?? this.muted,
        accent: accent ?? this.accent,
        onAccent: onAccent ?? this.onAccent,
        accentSoft: accentSoft ?? this.accentSoft,
        urgent: urgent ?? this.urgent,
        instagram: instagram ?? this.instagram,
        messenger: messenger ?? this.messenger,
      );

  @override
  RabtaColors lerp(RabtaColors? other, double t) {
    if (other == null) return this;
    return RabtaColors(
      ground: Color.lerp(ground, other.ground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      line: Color.lerp(line, other.line, t)!,
      edge: Color.lerp(edge, other.edge, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      urgent: Color.lerp(urgent, other.urgent, t)!,
      instagram: Color.lerp(instagram, other.instagram, t)!,
      messenger: Color.lerp(messenger, other.messenger, t)!,
    );
  }
}

extension RabtaTheme on BuildContext {
  RabtaColors get rabta => Theme.of(this).extension<RabtaColors>()!;
}

/// Almarai covers Arabic and Latin from one family, chosen on measured width in
/// Arabic — see DECISIONS.md. Weights are deliberate: 700 for names, 300 for
/// previews. That contrast is what lets a name detach at a glance in a dense
/// list; the same family at 300/500 did not.
ThemeData rabtaTheme({required Brightness brightness}) {
  final colors =
      brightness == Brightness.dark ? RabtaColors.dark : RabtaColors.light;

  final base = ThemeData(brightness: brightness, useMaterial3: true);

  return base.copyWith(
    extensions: [colors],
    scaffoldBackgroundColor: colors.ground,
    canvasColor: colors.surface,
    dividerColor: colors.line,
    textTheme: GoogleFonts.almaraiTextTheme(base.textTheme).apply(
      bodyColor: colors.ink,
      displayColor: colors.ink,
    ),
    colorScheme: base.colorScheme.copyWith(
      primary: colors.accent,
      onPrimary: colors.onAccent,
      surface: colors.surface,
      error: colors.urgent,
    ),
    dividerTheme: DividerThemeData(color: colors.line, thickness: 1, space: 1),
  );
}

/// Arabic needs more leading than Flutter's 1.2 default: Almarai's ascenders
/// and descenders collide at it, and dense Arabic in a narrow column is the
/// hardest thing this interface has to render.
abstract final class Style {
  static const brand = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w800,
    height: 1.25,
    letterSpacing: -0.2,
  );

  static const heading =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.35);

  static const name =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.4);

  static const preview =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w300, height: 1.5);

  static const message =
      TextStyle(fontSize: 14.5, fontWeight: FontWeight.w300, height: 1.6);

  static const meta =
      TextStyle(fontSize: 11.5, fontWeight: FontWeight.w300, height: 1.35);

  /// Group headings. Not tracked-out caps — that is template chrome, and it
  /// makes Arabic unreadable, which rules it out for a reason beyond taste.
  static const groupLabel =
      TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.35);

  static const monogram = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
}

/// Message content takes its direction from its own text, never from the
/// interface locale. A seller reading the Arabic interface receives English
/// messages and the reverse, and getting this wrong makes conversations
/// unreadable while looking correct in whichever language you tested.
///
/// First strong directional character wins, which is the Unicode rule and is
/// enough here: it skips leading digits, punctuation and emoji, so "؟هل" and
/// "50 ريال" both resolve the way a reader expects.
TextDirection directionOf(String? value) {
  for (final rune in (value ?? '').runes) {
    // Hebrew, Arabic, Syriac, Thaana, and the Arabic supplement/extended and
    // presentation-form blocks.
    final rtl = (rune >= 0x0590 && rune <= 0x08FF) ||
        (rune >= 0xFB1D && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF);
    if (rtl) return TextDirection.rtl;

    final ltr = (rune >= 0x0041 && rune <= 0x005A) ||
        (rune >= 0x0061 && rune <= 0x007A) ||
        (rune >= 0x00C0 && rune <= 0x02AF);
    if (ltr) return TextDirection.ltr;
  }

  return TextDirection.ltr;
}

/// How much of the 24 hour reply window is left, as 0..1.
///
/// This is the one number the interface is really about. Meta closes the window
/// 24 hours after the customer's last message and the conversation becomes
/// permanently unanswerable, so how long is left outranks almost everything
/// else on a waiting row — including, often, what the customer actually said.
double? windowRemainingFraction(DateTime? expiresAt, {DateTime? now}) {
  if (expiresAt == null) return null;

  final left = expiresAt.toUtc().difference(now ?? DateTime.now().toUtc());
  if (left.isNegative) return 0;

  const window = Duration(hours: 24);
  return (left.inSeconds / window.inSeconds).clamp(0.0, 1.0);
}

/// Whether Meta will still accept a reply in this conversation.
///
/// The window decides this and nothing else. Whether the customer wrote last
/// says who is waiting, which is a different question: a seller who has already
/// answered may follow up for as long as the 24 hours run, and `send-message`
/// on the server tests exactly this and nothing more.
///
/// One function because two readings of it disagreed on screen — the details
/// pane said the window was closed while the composer offered eight hours to
/// reply, about the same conversation, at the same moment.
bool replyWindowOpen(DateTime? expiresAt, {DateTime? now}) =>
    expiresAt != null &&
    expiresAt.toUtc().isAfter(now ?? DateTime.now().toUtc());

/// Under four hours the window stops being background information.
bool windowClosingSoon(DateTime? expiresAt, {DateTime? now}) {
  final fraction = windowRemainingFraction(expiresAt, now: now);
  return fraction != null && fraction > 0 && fraction < 4 / 24;
}

/// Which unit a gap should be spoken in. The wording lives in the localisation
/// files; this only decides the shape, so it can be tested without a widget
/// tree and cannot drift between languages.
enum Elapsed { now, minutes, hours, days, weeks }

({Elapsed unit, int count}) elapsedSince(DateTime since, {DateTime? now}) {
  final gap = (now ?? DateTime.now().toUtc()).difference(since.toUtc());

  if (gap.inMinutes < 1) return (unit: Elapsed.now, count: 0);
  if (gap.inMinutes < 60) return (unit: Elapsed.minutes, count: gap.inMinutes);
  if (gap.inHours < 24) return (unit: Elapsed.hours, count: gap.inHours);
  if (gap.inDays < 7) return (unit: Elapsed.days, count: gap.inDays);
  return (unit: Elapsed.weeks, count: (gap.inDays / 7).floor());
}
