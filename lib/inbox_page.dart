// The inbox.
//
// Two panes: the conversation list, and the conversation that is open. The list
// is the product — the seller lives there, not in the thread.
//
// One element is allowed to be loud, and it is the wait rail: a gauge on every
// waiting row showing how much of the 24 hour reply window is left. That is the
// physics of this product — Meta closes the window 24 hours after the
// customer's last message and the conversation becomes permanently
// unanswerable — so how long is left outranks almost everything else on a row.
// Everything around it is kept quiet so that it reads.
//
// Nothing here sets a text direction for the interface. That follows the
// locale. Direction is set by hand in exactly two places: the wordmark, which
// is a lockup, and message content, which takes its direction from its own
// text rather than from the reader's language.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data.dart';
import 'details_panel.dart';
import 'locale_switch.dart';
import 'platform_icon.dart';
import 'strings.dart';
import 'theme.dart';
import 'wordmark.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

/// Below this the two panes do not both fit, so the list and the thread take
/// turns. Chosen from the list's own width rather than a device category.
const _twoPaneFrom = 760.0;

/// Where the details pane earns its place. Below this the thread would be
/// squeezed to buy room for facts the seller can already see in the header.
const _threePaneFrom = 1180.0;

const _listWidth = 368.0;
const _detailsWidth = 300.0;

double _gutter(BuildContext context) =>
    MediaQuery.sizeOf(context).width < _twoPaneFrom ? 18 : 32;

class _InboxPageState extends State<InboxPage> {
  late final Inbox _inbox = Inbox(Supabase.instance.client);
  late final Future<List<Conversation>> _conversations = _inbox.conversations();
  Conversation? _open;

  /// Lifted out of the thread so the details pane can count them without
  /// fetching the same rows a second time.
  List<Message>? _messages;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Conversation>>(
          future: _conversations,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _Notice(
                title: context.l.inboxFailedTitle,
                body: context.l.inboxFailedBody,
                detail: '${snapshot.error}',
              );
            }
            if (!snapshot.hasData) {
              return Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: colors.muted,
                  ),
                ),
              );
            }

            final all = snapshot.data!;

            final list = _ConversationList(
              conversations: all,
              waiting: _inbox.waitingCount(all),
              openId: _open?.id,
              onOpen: (c) => setState(() {
                _open = c;
                _messages = null;
              }),
              onSignOut: () => Supabase.instance.client.auth.signOut(),
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < _twoPaneFrom) {
                  // One pane at a time. The list is where the seller lives, so
                  // it is what they return to, and the browser's own back has
                  // to do the same thing as the back control.
                  if (_open == null) return list;

                  return PopScope(
                    canPop: false,
                    onPopInvokedWithResult: (didPop, _) {
                      if (!didPop) setState(() => _open = null);
                    },
                    child: _Thread(
                      key: ValueKey(_open!.id),
                      inbox: _inbox,
                      conversation: _open!,
                      onBack: () => setState(() => _open = null),
                      onMessages: (m) => setState(() => _messages = m),
                    ),
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: _listWidth, child: list),
                    VerticalDivider(width: 1, color: colors.edge),
                    Expanded(
                      child: _open == null
                          ? _NothingOpen(conversations: all)
                          : _Thread(
                              key: ValueKey(_open!.id),
                              inbox: _inbox,
                              conversation: _open!,
                              onMessages: (m) => setState(() => _messages = m),
                            ),
                    ),
                    if (_open != null &&
                        constraints.maxWidth >= _threePaneFrom)
                      SizedBox(
                        width: _detailsWidth,
                        child: DetailsPanel(
                          conversation: _open!,
                          messages: _messages,
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The list
// ---------------------------------------------------------------------------

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.conversations,
    required this.waiting,
    required this.openId,
    required this.onOpen,
    required this.onSignOut,
  });

  final List<Conversation> conversations;
  final int waiting;
  final String? openId;
  final ValueChanged<Conversation> onOpen;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final showGroups =
        showGroupLabels(waiting: waiting, total: conversations.length);

    return Container(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ListHeader(waiting: waiting, onSignOut: onSignOut),
          Expanded(
            child: conversations.isEmpty
                ? _Notice(
                    title: context.l.noConversationsTitle,
                    body: context.l.noConversationsBody,
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 28),
                    children: _rows(context, showGroups),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _rows(BuildContext context, bool showGroups) {
    final items = <Widget>[];

    if (showGroups) {
      items.add(_GroupHeading(context.l.waitingForReply, count: waiting));
    }

    for (var i = 0; i < conversations.length; i++) {
      if (showGroups && i == waiting) {
        items.add(_GroupHeading(
          context.l.answered,
          count: conversations.length - waiting,
        ));
      }

      final conversation = conversations[i];

      // A hairline between rows. Without it the list reads as one
      // undifferentiated block, and the grouping stops being visible at all.
      final startsGroup = i == 0 || (showGroups && i == waiting);
      if (!startsGroup) {
        items.add(const _RowDivider());
      }

      items.add(_ConversationRow(
        conversation: conversation,
        selected: conversation.id == openId,
        onTap: () => onOpen(conversation),
      ));
    }

    return items;
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.waiting, required this.onSignOut});

  final int waiting;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 20, 12, 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.edge)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Wordmark(),
                const SizedBox(height: 5),
                Text(
                  // The count a seller acts on. A total conversation count is a
                  // number nobody does anything with.
                  waiting == 0
                      ? context.l.everyoneAnswered
                      : context.l.customersWaiting(waiting),
                  style: Style.meta.copyWith(
                    color: waiting == 0 ? colors.muted : colors.accent,
                    fontWeight:
                        waiting == 0 ? FontWeight.w300 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout, size: 17),
                color: colors.muted,
                tooltip: context.l.signOut,
                visualDensity: VisualDensity.compact,
              ),
              const LocaleSwitch(compact: true),
            ],
          ),
        ],
      ),
    );
  }
}

/// Indented past the monogram, so it separates rows without cutting the list
/// into slices — a full-width rule reads as a section break, and these are not
/// section breaks.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 65, end: 20),
        child: Divider(height: 1, color: context.rabta.line),
      );
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading(this.label, {required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 10),
      child: Row(
        children: [
          Text(label, style: Style.groupLabel.copyWith(color: colors.muted)),
          const SizedBox(width: 8),
          Text('$count', style: Style.meta.copyWith(color: colors.muted)),
          const SizedBox(width: 14),
          Expanded(child: Divider(height: 1, color: colors.edge)),
        ],
      ),
    );
  }
}

class _ConversationRow extends StatefulWidget {
  const _ConversationRow({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final Conversation conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ConversationRow> createState() => _ConversationRowState();
}

class _ConversationRowState extends State<_ConversationRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final c = widget.conversation;
    final unread = c.unreadCount > 0;
    final name = c.customerName ?? context.l.customer;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          button: true,
          selected: widget.selected,
          child: Container(
            // Selection is a shift in ground, not a card. No border, no
            // elevation anywhere in this list.
            color: widget.selected
                ? colors.raised
                : _hovered
                    ? colors.raised.withValues(alpha: 0.5)
                    : colors.surface,
            padding: const EdgeInsetsDirectional.fromSTEB(16, 13, 20, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The rail only appears where a window is running down. On an
                // answered row nothing is counting, and an empty track is noise.
                SizedBox(
                  width: 12,
                  child: c.awaitingReply
                      ? _WaitRail(expiresAt: c.windowExpiresAt)
                      : null,
                ),
                _Monogram(name: name, platform: c.platform),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: Style.name.copyWith(
                                color: colors.ink,
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            waitedFor(context, c.lastMessageAt),
                            style: Style.meta.copyWith(color: colors.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _Preview(conversation: c)),
                          if (unread) ...[
                            const SizedBox(width: 10),
                            Container(
                              margin: const EdgeInsets.only(top: 5),
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: colors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How much of the reply window is left, as a vertical gauge.
///
/// Length is the reading, not colour: a short bar is a conversation running
/// out, legible without knowing what any colour means and still legible to
/// someone who cannot distinguish the red. Colour joins in only at the end,
/// which is the one moment it carries information of its own.
class _WaitRail extends StatelessWidget {
  const _WaitRail({required this.expiresAt});

  final DateTime? expiresAt;

  static const _height = 46.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final remaining = windowRemainingFraction(expiresAt);
    if (remaining == null) return const SizedBox.shrink();

    final closing = windowClosingSoon(expiresAt);
    final expired = remaining == 0;

    return Tooltip(
      message: expired
          ? context.l.replyWindowClosedShort
          : windowRemaining(context, expiresAt) ?? '',
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: Container(
          width: 3,
          height: _height,
          decoration: BoxDecoration(
            color: colors.accentSoft,
            borderRadius: BorderRadius.circular(2),
          ),
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: expired ? 0 : remaining,
            child: Container(
              decoration: BoxDecoration(
                color: closing ? colors.urgent : colors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A monogram rather than a photo. Meta does not send a customer's picture with
/// the message, and a grey silhouette on every row is a scan anchor that
/// anchors nothing. The platform rides on the monogram instead of taking its
/// own column.
class _Monogram extends StatelessWidget {
  const _Monogram({required this.name, required this.platform});

  final String name;
  final String platform;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final trimmed = name.trim();
    // Characters, not code units: an Arabic or emoji first letter must survive.
    final initial =
        trimmed.isEmpty ? '·' : String.fromCharCode(trimmed.runes.first);

    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.accentSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initial.toUpperCase(),
              style: Style.monogram.copyWith(color: colors.accent),
              textAlign: TextAlign.center,
            ),
          ),
          PositionedDirectional(
            bottom: -3,
            end: -4,
            child: PlatformBadge(platform: platform),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final style = Style.preview.copyWith(color: colors.muted);
    final text = conversation.preview;

    if (text != null && text.isNotEmpty) {
      return Directionality(
        textDirection: directionOf(text),
        child: Text(
          text,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    // A message carrying only an attachment has no text, so the preview would
    // otherwise be blank.
    return Row(
      children: [
        Icon(
          _icon(conversation.lastMessageType),
          size: 13,
          color: colors.muted,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            attachmentLabel(context, conversation.lastMessageType),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  static IconData _icon(String? type) => switch (type) {
        'image' => Icons.image_outlined,
        'video' => Icons.videocam_outlined,
        'audio' => Icons.mic_none_outlined,
        'file' => Icons.description_outlined,
        'share' => Icons.link_outlined,
        _ => Icons.attachment_outlined,
      };
}

/// What fills the reading pane before a conversation is opened.
///
/// A blank sheet here is wasted: it is the largest area on the screen and the
/// seller looks at it every time they finish a conversation. So it answers the
/// question they are about to ask anyway — who is closest to running out of
/// time — using the same rail as the list, at a size where the reading is
/// unmissable.
class _NothingOpen extends StatelessWidget {
  const _NothingOpen({required this.conversations});

  final List<Conversation> conversations;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;
    final waiting = conversations.where((c) => c.awaitingReply).toList();

    // inboxOrder already puts the longest wait first, and with a fixed 24 hour
    // window the longest wait is also the one closest to closing.
    final urgent = waiting.isEmpty ? null : waiting.first;

    return Container(
      color: colors.ground,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: urgent == null
              ? [
                  Text(
                    l.everyoneAnswered,
                    style: Style.heading.copyWith(color: colors.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.noConversationsBody,
                    style: Style.preview.copyWith(color: colors.muted),
                  ),
                ]
              : [
                  Text(
                    l.customersWaiting(waiting.length),
                    style: Style.heading.copyWith(color: colors.ink),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BigRail(
                        remaining:
                            windowRemainingFraction(urgent.windowExpiresAt) ?? 0,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.longestWait,
                              style:
                                  Style.meta.copyWith(color: colors.muted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              urgent.customerName ?? l.customer,
                              style: Style.name.copyWith(color: colors.ink),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              windowRemaining(
                                    context,
                                    urgent.windowExpiresAt,
                                  ) ??
                                  l.replyWindowClosedShort,
                              style: Style.preview.copyWith(
                                color:
                                    windowClosingSoon(urgent.windowExpiresAt)
                                        ? colors.urgent
                                        : colors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l.windowExplanation,
                              style:
                                  Style.preview.copyWith(color: colors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
        ),
      ),
    );
  }
}

/// The list's wait rail, enlarged. Same encoding, same colours — a seller who
/// learns it here reads every row in the list for free.
class _BigRail extends StatelessWidget {
  const _BigRail({required this.remaining});

  final double remaining;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final closing = remaining > 0 && remaining < 4 / 24;

    return Container(
      width: 6,
      height: 112,
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: remaining.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: closing ? colors.urgent : colors.accent,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The thread
// ---------------------------------------------------------------------------

class _Thread extends StatefulWidget {
  const _Thread({
    super.key,
    required this.inbox,
    required this.conversation,
    this.onBack,
    this.onMessages,
  });

  final Inbox inbox;
  final Conversation conversation;

  /// Only set when the thread has the screen to itself.
  final VoidCallback? onBack;

  /// Hands the loaded messages back up, so the details pane can describe them
  /// without asking the database for the same rows again.
  final ValueChanged<List<Message>>? onMessages;

  @override
  State<_Thread> createState() => _ThreadState();
}

class _ThreadState extends State<_Thread> {
  late final Future<List<Message>> _messages = _load();

  Future<List<Message>> _load() async {
    final messages = await widget.inbox.messages(widget.conversation.id);
    // After the frame: this fires during the parent's build otherwise, and
    // setState from inside a build is an error.
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onMessages?.call(messages),
      );
    }
    return messages;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final c = widget.conversation;
    final gutter = _gutter(context);
    final name = c.customerName ?? context.l.customer;

    return Container(
      color: colors.ground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: colors.surface,
            padding: EdgeInsetsDirectional.fromSTEB(
              widget.onBack == null ? gutter : 6,
              14,
              gutter,
              14,
            ),
            child: Row(
              children: [
                if (widget.onBack != null)
                  IconButton(
                    // Directional: in Arabic, back points the other way.
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back, size: 19),
                    color: colors.ink,
                    tooltip: context.l.backToInbox,
                  ),
                _Monogram(name: name, platform: c.platform),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Style.heading.copyWith(color: colors.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          PlatformIcon(platform: c.platform, size: 11),
                          const SizedBox(width: 6),
                          Text(
                            platformName(context, c.platform),
                            style: Style.meta.copyWith(color: colors.muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.edge),
          Expanded(
            child: FutureBuilder<List<Message>>(
              future: _messages,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _Notice(
                    title: context.l.messagesFailedTitle,
                    body: context.l.messagesFailedBody,
                    detail: '${snapshot.error}',
                  );
                }
                if (!snapshot.hasData) return const SizedBox.shrink();

                final messages = snapshot.data!;

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 28),
                  itemCount: messages.length,
                  itemBuilder: (context, i) => _Bubble(
                    message: messages[i],
                    // Time separates runs of messages rather than stamping each
                    // one. Repeating it on every bubble is noise when three
                    // arrive in the same minute.
                    showTime: i == messages.length - 1 ||
                        messages[i + 1].inbound != messages[i].inbound ||
                        messages[i + 1].sentAt.difference(messages[i].sentAt) >
                            const Duration(minutes: 10),
                  ),
                );
              },
            ),
          ),
          _Composer(conversation: c),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.showTime});

  final Message message;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final inbound = message.inbound;

    return Padding(
      padding: EdgeInsets.only(bottom: showTime ? 18 : 4),
      child: Column(
        crossAxisAlignment:
            inbound ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          ConstrainedBox(
            // Under 80 characters, which is where a line stops being
            // comfortable to read.
            constraints: const BoxConstraints(maxWidth: 470),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                // The customer sits on the surface; the seller's own words
                // carry the accent. No border on either — the ground behind
                // them does the separating, and a hairline around every bubble
                // is what makes an interface look like a default kit.
                color: inbound ? colors.surface : colors.accent,
                borderRadius: BorderRadiusDirectional.only(
                  topStart: const Radius.circular(16),
                  topEnd: const Radius.circular(16),
                  bottomStart: Radius.circular(inbound ? 4 : 16),
                  bottomEnd: Radius.circular(inbound ? 16 : 4),
                ).resolve(Directionality.of(context)),
              ),
              // Each message takes its direction from its own text. This is the
              // rule most easily lost once screens are being built, because the
              // mistake looks correct in whichever language you tested in.
              child: Directionality(
                textDirection: directionOf(message.text),
                child: _Body(message: message, inbound: inbound),
              ),
            ),
          ),
          if (showTime) ...[
            const SizedBox(height: 6),
            Text(
              waitedFor(context, message.sentAt),
              style: Style.meta.copyWith(color: colors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.message, required this.inbound});

  final Message message;
  final bool inbound;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final onAccent = !inbound;
    final quiet = onAccent ? colors.onAccent.withValues(alpha: 0.75) : colors.muted;
    final text = message.text;

    if (text != null && text.isNotEmpty) {
      return Text(
        text,
        style: Style.message.copyWith(
          color: onAccent ? colors.onAccent : colors.ink,
        ),
      );
    }

    final first = message.attachments.isEmpty
        ? null
        : message.attachments.first as Map<String, dynamic>;
    final url = first?['payload']?['url'] as String?;

    if (first?['type'] == 'image' && url != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          url,
          width: 280,
          fit: BoxFit.cover,
          // Meta's attachment URLs expire — measured at roughly 30 days — so a
          // thread far enough back has images that no longer load. Saying so
          // beats a broken image icon.
          errorBuilder: (_, _, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_not_supported_outlined, size: 15, color: quiet),
              const SizedBox(width: 8),
              Text(
                context.l.photoExpired,
                style: Style.preview.copyWith(color: quiet),
              ),
            ],
          ),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : SizedBox(
                  width: 280,
                  height: 170,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: quiet,
                      ),
                    ),
                  ),
                ),
        ),
      );
    }

    return Text(
      attachmentLabel(context, first?['type'] as String?),
      style: Style.preview.copyWith(color: quiet),
    );
  }
}

/// The reply window is stated before the seller types, not after. A reply that
/// fails once written is a design failure rather than an error message.
class _Composer extends StatelessWidget {
  const _Composer({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final remaining = conversation.awaitingReply
        ? windowRemaining(context, conversation.windowExpiresAt)
        : null;
    final closed = conversation.awaitingReply && remaining == null;
    final closing = windowClosingSoon(conversation.windowExpiresAt);
    final gutter = _gutter(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.edge)),
      ),
      padding: EdgeInsetsDirectional.fromSTEB(gutter, 16, gutter, 18),
      child: Row(
        children: [
          if (closed)
            Icon(Icons.lock_outline, size: 15, color: colors.urgent)
          else if (closing)
            Icon(Icons.timelapse, size: 15, color: colors.urgent),
          if (closed || closing) const SizedBox(width: 9),
          Expanded(
            child: Text(
              closed
                  ? context.l.replyWindowClosedLong
                  : context.l.replyingNotBuilt,
              style: Style.preview.copyWith(
                color: closed ? colors.urgent : colors.muted,
              ),
            ),
          ),
          if (remaining != null) ...[
            const SizedBox(width: 16),
            Text(
              remaining,
              style: Style.meta.copyWith(
                color: closing ? colors.urgent : colors.muted,
                fontWeight: closing ? FontWeight.w700 : FontWeight.w300,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty and failed states say what to do, in the interface's voice. They do
/// not apologise and they are never vague about what happened.
class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body, this.detail});

  final String title;
  final String body;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Style.name.copyWith(color: colors.ink)),
              const SizedBox(height: 7),
              Text(body, style: Style.preview.copyWith(color: colors.muted)),
              if (detail != null) ...[
                const SizedBox(height: 16),
                Text(
                  detail!,
                  style: Style.meta
                      .copyWith(color: colors.muted, fontSize: 10.5),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
