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
    required this.saffron,
    required this.saffronSoft,
    required this.night,
    required this.onNight,
    required this.urgent,
    required this.assistant,
    required this.won,
    required this.instagram,
    required this.messenger,
  });

  /// Behind everything. Warm sand rather than a cold near-white: a ground
  /// with some colour in it is what stops the panes reading as blank paper.
  final Color ground;

  /// The list, the thread header, message bubbles from the customer.
  final Color surface;

  /// A row that is open or hovered. Saffron-tinted, so the open row is a
  /// different colour from the violet around it rather than a paler step of
  /// the same one — which is what made selection invisible before.
  final Color raised;

  /// Hairlines inside a pane: between rows, around cards.
  final Color line;

  /// The boundaries between panes, and the group rules in the list.
  final Color edge;

  /// Names and message text. A violet-black rather than a neutral one, so
  /// text belongs to the same family as the accent.
  final Color ink;

  /// Previews, timestamps, anything secondary.
  final Color muted;

  /// The seller's own actions and their own words.
  final Color accent;

  /// Text sitting on the accent.
  final Color onAccent;

  /// The accent at reading strength — the wait rail's track, quiet highlights.
  final Color accentSoft;

  /// Violet's complement, and the second half of the brand. Used where the
  /// interface wants to point at something without alarming anyone: the open
  /// row, the count of people waiting, the selected item in the menu. Never
  /// for text on a light ground — it is far too light to read there — only
  /// as a fill with ink on it.
  final Color saffron;
  final Color saffronSoft;

  /// The dark panels: the menu, and the brand side of sign-in.
  final Color night;
  final Color onNight;

  /// Something needs the seller now: a reply window about to close, or a
  /// conversation the assistant handed to them.
  final Color urgent;

  /// A message the assistant sent, and nothing else. Teal because it is the
  /// furthest readable hue from the violet that is not already spoken for. Not
  /// the only signal: an assistant message also carries a word saying so.
  final Color assistant;

  /// A conversation that ended in an order, and nothing else.
  final Color won;

  final Color instagram;
  final Color messenger;

  /// Violet and saffron on sand. See docs/DECISIONS.md, 26 September 2026.
  static const light = RabtaColors(
    ground: Color(0xFFF5F0E8),
    surface: Color(0xFFFFFDF9),
    raised: Color(0xFFFFF1CF),
    line: Color(0xFFEBE3D6),
    edge: Color(0xFFDCCFBC),
    ink: Color(0xFF1D1626),
    muted: Color(0xFF6A6272),
    accent: Color(0xFF5B16C8),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFEDE4FB),
    saffron: Color(0xFFFFB42E),
    saffronSoft: Color(0xFFFFEBC2),
    night: Color(0xFF1D1626),
    onNight: Color(0xFFF6F0E6),
    urgent: Color(0xFFCF2F55),
    assistant: Color(0xFF0B7A6E),
    won: Color(0xFF1C7C3A),
    instagram: Color(0xFFE1306C),
    messenger: Color(0xFF0866FF),
  );

  /// Dark. Not wired up yet — `main.dart` has no dark theme and no toggle.
  static const dark = RabtaColors(
    ground: Color(0xFF15111B),
    surface: Color(0xFF1E1826),
    raised: Color(0xFF3A2E1A),
    line: Color(0xFF2F2739),
    edge: Color(0xFF443A52),
    ink: Color(0xFFF3EEE6),
    muted: Color(0xFFA39AAE),
    accent: Color(0xFFA77BF5),
    onAccent: Color(0xFF15111B),
    accentSoft: Color(0xFF2E2440),
    saffron: Color(0xFFFFB42E),
    saffronSoft: Color(0xFF3A2E1A),
    night: Color(0xFF0E0B12),
    onNight: Color(0xFFF3EEE6),
    urgent: Color(0xFFFF8098),
    assistant: Color(0xFF58D5C9),
    won: Color(0xFF74D38F),
    instagram: Color(0xFFF06595),
    messenger: Color(0xFF5B9DFF),
  );

  Color platform(String name) => name == 'instagram' ? instagram : messenger;

  @override
  RabtaColors copyWith() => this;

  @override
  RabtaColors lerp(RabtaColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return RabtaColors(
      ground: l(ground, other.ground),
      surface: l(surface, other.surface),
      raised: l(raised, other.raised),
      line: l(line, other.line),
      edge: l(edge, other.edge),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      accentSoft: l(accentSoft, other.accentSoft),
      saffron: l(saffron, other.saffron),
      saffronSoft: l(saffronSoft, other.saffronSoft),
      night: l(night, other.night),
      onNight: l(onNight, other.onNight),
      urgent: l(urgent, other.urgent),
      assistant: l(assistant, other.assistant),
      won: l(won, other.won),
      instagram: l(instagram, other.instagram),
      messenger: l(messenger, other.messenger),
    );
  }
}

extension RabtaTheme on BuildContext {
  RabtaColors get rabta => Theme.of(this).extension<RabtaColors>()!;
}

/// Corners, in one place. Softer than before: the old 10 everywhere was the
/// radius of every default kit.
abstract final class Radii {
  static const control = 12.0;
  static const card = 18.0;
  static const bubble = 20.0;
}

/// Almarai for everything read — narrowest in Arabic, see docs/DECISIONS.md.
/// Rubik for everything that names a place or a number: the wordmark, page
/// titles, the counts. Rounded and heavy in both scripts, and it is the part of
/// the type that gives the interface a voice.
TextStyle display(TextStyle style) => GoogleFonts.rubik(textStyle: style);

ThemeData rabtaTheme({required Brightness brightness}) {
  final colors =
      brightness == Brightness.dark ? RabtaColors.dark : RabtaColors.light;

  final base = ThemeData(brightness: brightness, useMaterial3: true);
  final control = BorderRadius.circular(Radii.control);

  OutlineInputBorder field(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: control,
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    extensions: [colors],
    scaffoldBackgroundColor: colors.ground,
    canvasColor: colors.surface,
    dividerColor: colors.line,
    splashFactory: InkSparkle.constantTurbulenceSeedSplashFactory,
    textTheme: GoogleFonts.almaraiTextTheme(base.textTheme).apply(
      bodyColor: colors.ink,
      displayColor: colors.ink,
    ),
    colorScheme: base.colorScheme.copyWith(
      primary: colors.accent,
      onPrimary: colors.onAccent,
      secondary: colors.saffron,
      onSecondary: colors.ink,
      surface: colors.surface,
      onSurface: colors.ink,
      surfaceContainerHighest: colors.ground,
      error: colors.urgent,
      outline: colors.edge,
      outlineVariant: colors.line,
    ),
    dividerTheme: DividerThemeData(color: colors.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.ground,
      surfaceTintColor: Colors.transparent,
      foregroundColor: colors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: display(Style.title.copyWith(color: colors.ink)),
      iconTheme: IconThemeData(color: colors.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
        disabledBackgroundColor: colors.accentSoft,
        disabledForegroundColor: colors.muted,
        textStyle: Style.name,
        elevation: 0,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: control),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.ink,
        textStyle: Style.name,
        side: BorderSide(color: colors.ink, width: 1.5),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: control),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.accent,
        textStyle: Style.name,
        shape: RoundedRectangleBorder(borderRadius: control),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: control),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      hintStyle: Style.preview.copyWith(color: colors.muted),
      labelStyle: Style.preview.copyWith(color: colors.muted),
      floatingLabelStyle: Style.meta.copyWith(color: colors.accent),
      border: field(colors.edge),
      enabledBorder: field(colors.edge),
      focusedBorder: field(colors.accent, 2),
      errorBorder: field(colors.urgent),
      focusedErrorBorder: field(colors.urgent, 2),
      disabledBorder: field(colors.line),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.accent,
      selectionColor: colors.saffron.withValues(alpha: 0.45),
      selectionHandleColor: colors.accent,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? colors.onAccent : colors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? colors.accent : colors.ground,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.transparent : colors.edge,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      side: BorderSide(color: colors.muted, width: 1.5),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surface,
      selectedColor: colors.saffron,
      side: BorderSide(color: colors.edge),
      labelStyle: Style.meta.copyWith(color: colors.ink),
      shape: const StadiumBorder(),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: colors.ink, width: 1.5),
      ),
      titleTextStyle: display(Style.title.copyWith(color: colors.ink)),
      contentTextStyle: Style.preview.copyWith(color: colors.ink),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.night,
      contentTextStyle: Style.preview.copyWith(color: colors.onNight),
      actionTextColor: colors.saffron,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: control),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colors.night,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: Style.meta.copyWith(color: colors.onNight),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        side: WidgetStatePropertyAll(BorderSide(color: colors.ink, width: 1.5)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.ink, width: 1.5),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.accent,
      linearTrackColor: colors.accentSoft,
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: colors.urgent,
      textColor: Colors.white,
    ),
  );
}

/// The one physical-looking thing in the interface: an ink edge and a hard
/// shadow that sits down and away, like a rubber stamp. Kept to the primary
/// action of a screen and to the cards that hold one — used everywhere it
/// would be noise, and a default kit again.
///
/// The shadow falls toward the end edge, so it mirrors with the language.
class Stamp extends StatelessWidget {
  const Stamp({
    super.key,
    required this.child,
    this.radius = Radii.control,
    this.depth = 3,
    this.enabled = true,
    this.color,
  });

  final Widget child;
  final double radius;
  final double depth;
  final bool enabled;

  /// The fill, for a card. A button brings its own and leaves this null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final shape = BorderRadius.circular(radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: shape,
        border: Border.all(color: colors.ink, width: 1.5),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: colors.ink,
                  offset: Offset(rtl ? -depth : depth, depth),
                ),
              ]
            : null,
      ),
      child: ClipRRect(borderRadius: shape, child: child),
    );
  }
}

/// A group of rows on one card, with hairlines between them. Flat, unlike a
/// [Stamp]: it holds content, it is not an action.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: colors.edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) Divider(height: 1, color: colors.line),
            child,
          ],
        ],
      ),
    );
  }
}

/// A faint dot grid, so a large flat area has a surface rather than being a
/// void: behind the brand panel, and behind the messages in a thread.
class DotGrid extends CustomPainter {
  DotGrid(this.color, this.strength);

  final Color color;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: strength);
    const gap = 22.0;
    for (var y = gap / 2; y < size.height; y += gap) {
      for (var x = gap / 2; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotGrid old) =>
      old.color != color || old.strength != strength;
}

/// Arabic needs more leading than Flutter's 1.2 default: Almarai's ascenders
/// and descenders collide at it, and dense Arabic in a narrow column is the
/// hardest thing this interface has to render.
abstract final class Style {
  static const brand = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  /// Page titles, in Rubik through [display].
  static const title =
      TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3);

  /// Large numbers and hero lines, in Rubik through [display].
  static const hero =
      TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1.15);

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

  static const monogram = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
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

/// Text set inside a sentence in the other script — an email address in an
/// Arabic sentence — kept in one left-to-right piece. Without it an address
/// reorders around its + . and @. Built from character codes rather than
/// written out, because the isolates are invisible in source.
String isolated(String text) =>
    '${String.fromCharCode(0x2066)}$text${String.fromCharCode(0x2069)}';

/// A piece of a joined line — "10% off · عطور · until 26/10" — set in the
/// direction of its own first letter, so no piece reorders its neighbours or
/// carries its full stop to the wrong end. Character codes, as in [isolated].
String ownDirection(String text) =>
    '${String.fromCharCode(0x2068)}$text${String.fromCharCode(0x2069)}';

/// A customer's name, ordered by its own script but lined up with the
/// interface. "Dana K." in the Arabic interface rendered as ".Dana K" when it
/// took the interface's direction; given its own and left to align itself, an
/// Arabic name in the English list sat flush right, away from its monogram.
({TextDirection direction, TextAlign align}) nameLayout(
  BuildContext context,
  String name,
) =>
    (
      direction: directionOf(name),
      align: Directionality.of(context) == TextDirection.rtl
          ? TextAlign.right
          : TextAlign.left,
    );

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
