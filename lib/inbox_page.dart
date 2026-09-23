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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'accounts_page.dart';
import 'alerts.dart';
import 'data.dart';
import 'details_panel.dart';
import 'invite_page.dart';
import 'locale_switch.dart';
import 'menu.dart';
import 'offers_page.dart';
import 'platform_icon.dart';
import 'products_page.dart';
import 'shop_page.dart';
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

  /// The list as it stands now, replacing what was first loaded.
  ///
  /// Held beside the future rather than replacing it, so that a reply or an
  /// arriving message does not drop the inbox back to a spinner while it
  /// reloads — the seller is reading this list, and it must not blink at them.
  List<Conversation>? _live;

  /// Bumped whenever the database says something changed. The open thread
  /// watches it and reloads, which is how a message arriving mid-conversation
  /// reaches the screen.
  int _revision = 0;

  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authChanges;

  /// Null while loading. Empty means nothing is connected, and there is then
  /// no inbox to show — only the one thing worth doing.
  List<Account>? _accounts;

  @override
  void initState() {
    super.initState();
    _listen();
    _loadAccounts();

    // Registration used to happen only inside the permission prompt, so a
    // seller who had turned alerts on and then reloaded the page kept a menu
    // row saying they were on while nothing was ever shown — `notify` found no
    // worker and returned. Nothing on screen said so, which is the worst shape
    // for a bug like this to take.
    prepareAlerts();

    // The first list comes through this future rather than through _refresh,
    // so without this the count does not reach the title until something
    // changes — which on a quiet morning is not for hours. Nothing is
    // announced from it: `alertsFor` is given no previous list and returns
    // nothing, which is what stops a seller opening Rabta to nine waiting
    // customers and being notified about all nine.
    _conversations.then((first) {
      if (mounted) _announce(first);
    }).catchError((_) {});
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await _inbox.accounts();
      if (mounted) setState(() => _accounts = accounts);
    } catch (_) {
      // Leaves it null, which shows the inbox rather than wrongly claiming
      // nothing is connected.
    }
  }

  /// Subscribes to changes in this seller's own conversations.
  ///
  /// Realtime is used as a signal, not as a source of data. The payload is
  /// ignored and the list is read again through the ordinary query, so what
  /// reaches the screen has been through row level security exactly as it
  /// would on a reload. A change feed is the last place to start trusting rows
  /// about other people's customers.
  ///
  /// The conversations table is enough on its own: the trigger touches it on
  /// every message, inbound or outbound.
  void _listen() {
    final client = Supabase.instance.client;

    // The socket needs the seller's token, and it does not inherit it. Without
    // this the subscription is made as the anonymous role, which row level
    // security correctly shows no conversations at all — so it connects,
    // reports "Subscribed to PostgreSQL", and then never delivers anything.
    // A silent success is why this is asserted here rather than assumed.
    _applyToken();

    // A token lasts an hour and this is a tab left open all day. A refreshed
    // session has to reach the socket too, or the inbox stops updating at some
    // point in the afternoon and nothing says why.
    _authChanges = client.auth.onAuthStateChange.listen((_) => _applyToken());

    _channel = client
        .channel('inbox')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) => _refresh(),
        )
        .subscribe();
  }

  void _applyToken() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token != null) Supabase.instance.client.realtime.setAuth(token);
  }

  /// The list as it was at the previous refresh, which is what a change is
  /// measured against. Null until the first one has arrived — see `alertsFor`,
  /// which announces nothing on a first list.
  List<Conversation>? _announced;

  /// Updates the tab title, and tells the seller about anything new.
  ///
  /// Called on every refresh rather than only on the realtime path, because a
  /// refresh is also what happens when the seller comes back from the shop
  /// screen — and a customer who wrote while they were in there is exactly the
  /// case this exists for.
  void _announce(List<Conversation> fresh) {
    showWaitingCount('Rabta', _inbox.waitingCount(fresh));

    final alerts = alertsFor(_announced, fresh, openId: _open?.id);
    _announced = fresh;

    if (!alertsAreOn()) return;

    for (final alert in alerts) {
      final said = alertText(context.l, alert);
      announce(alert, said.title, said.body);
    }
  }

  @override
  void dispose() {
    // Otherwise a seller who signs out is left looking at a tab still counting
    // customers they can no longer see.
    showWaitingCount('Rabta', 0);
    _authChanges?.cancel();
    final channel = _channel;
    if (channel != null) Supabase.instance.client.removeChannel(channel);
    super.dispose();
  }

  Future<void> _refresh() async {
    final List<Conversation> fresh;
    try {
      fresh = await _inbox.conversations();
    } catch (_) {
      // A refresh that fails leaves what is on screen alone. The seller is
      // reading it, and replacing a working list with an error because one
      // background reload failed would be worse than being briefly stale.
      return;
    }

    if (!mounted) return;

    _announce(fresh);

    setState(() {
      _live = fresh;
      _revision++;

      // The open conversation, as it now stands. Kept by id rather than by
      // identity so the header, the details pane and the composer all follow.
      final open = _open;
      if (open != null) {
        for (final c in fresh) {
          if (c.id == open.id) {
            _open = c;
            break;
          }
        }
      }
    });
  }

  /// Needed because the button that opens the menu is inside the same Scaffold
  /// it belongs to, so there is no ancestor to reach it through.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openMenu() => _scaffoldKey.currentState?.openDrawer();

  Future<void> _openShop() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ShopPage(inbox: _inbox)),
    );

    if (mounted) await _refresh();
  }

  Future<void> _openProducts() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ProductsPage(inbox: _inbox)),
    );

    // The catalog may have changed, and with it whether the assistant is
    // answering at all. The list shows what it did, so it is read again.
    if (mounted) await _refresh();
  }

  Future<void> _openOffers() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => OffersPage(inbox: _inbox)),
    );
  }

  Future<void> _openAccounts() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AccountsPage(inbox: _inbox)),
    );

    // An account may have been connected or turned off while that was open,
    // which changes both what the list contains and whether there is a list.
    if (!mounted) return;
    await _loadAccounts();
    if (mounted) await _refresh();
  }

  /// A reply has gone. The conversation is no longer waiting for one, so it
  /// moves out of the first group and the list is put back in order.
  void _sent(List<Conversation> current, Message reply) {
    final open = _open;
    if (open == null) return;

    final updated = open.afterReply(reply);

    final next = inboxOrder([
      for (final c in current) c.id == updated.id ? updated : c,
    ]);

    // The same list the seller is now looking at. Without this the count in
    // the title still includes the customer they have just answered, until the
    // next refresh happens to come along.
    _announce(next);

    setState(() {
      _open = updated;
      _live = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return Scaffold(
      key: _scaffoldKey,
      // Opens from the start edge, which follows the reading direction — the
      // right in Arabic, the left in English — because Flutter resolves it
      // against the locale rather than pinning it to one side.
      drawer: AppMenu(
        inbox: _inbox,
        onProducts: _openProducts,
        onOffers: _openOffers,
        onShop: _openShop,
        onAccounts: _openAccounts,
      ),
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

            final all = _live ?? snapshot.data!;

            // Nothing connected yet. The inbox is empty and will stay empty
            // until this is done, so it is the whole screen rather than a
            // panel inside one — and it is the same at every width.
            if (_accounts != null && _accounts!.isEmpty) {
              return _FirstRun(inbox: _inbox);
            }

            final list = _ConversationList(
              conversations: all,
              waiting: _inbox.waitingCount(all),
              openId: _open?.id,
              onOpen: (c) => setState(() {
                _open = c;
                _messages = null;
              }),
              onSignOut: () => Supabase.instance.client.auth.signOut(),
              onAccounts: _openAccounts,
              onMenu: _openMenu,
              inbox: _inbox,
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
                      showAssistant: true,
                      onBack: () => setState(() => _open = null),
                      onMessages: (m) => setState(() => _messages = m),
                      onSent: (m) => _sent(all, m),
                      revision: _revision,
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
                              showAssistant:
                                  constraints.maxWidth < _threePaneFrom,
                              onMessages: (m) => setState(() => _messages = m),
                              onSent: (m) => _sent(all, m),
                              revision: _revision,
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

/// What a seller sees before they have connected anything.
///
/// Keeps the language switch and the way out, because being unable to read the
/// screen or leave it are the two things a seller cannot click past.
class _FirstRun extends StatelessWidget {
  const _FirstRun({required this.inbox});

  final Inbox inbox;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: colors.surface,
          padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 12, 14),
          child: Row(
            children: [
              const Wordmark(size: 19),
              const Spacer(),
              const LocaleSwitch(compact: true),
              InviteButton(inbox: inbox),
              IconButton(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                icon: const Icon(Icons.logout, size: 17),
                color: colors.muted,
                tooltip: context.l.signOut,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.edge),
        Expanded(child: ConnectPrompt(inbox: inbox)),
      ],
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
    required this.onAccounts,
    required this.onMenu,
    required this.inbox,
  });

  final Inbox inbox;
  final List<Conversation> conversations;
  final int waiting;
  final String? openId;
  final ValueChanged<Conversation> onOpen;
  final VoidCallback onSignOut;
  final VoidCallback onAccounts;
  final VoidCallback onMenu;

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
          _ListHeader(
            waiting: waiting,
            needsYou: conversations.where((c) => c.escalated).toList(),
            onOpen: onOpen,
            onSignOut: onSignOut,
            onAccounts: onAccounts,
            onMenu: onMenu,
            inbox: inbox,
          ),
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
  const _ListHeader({
    required this.waiting,
    required this.needsYou,
    required this.onOpen,
    required this.onSignOut,
    required this.onAccounts,
    required this.onMenu,
    required this.inbox,
  });

  final Inbox inbox;
  final int waiting;
  final List<Conversation> needsYou;
  final ValueChanged<Conversation> onOpen;
  final VoidCallback onSignOut;
  final VoidCallback onAccounts;
  final VoidCallback onMenu;

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NeedsYouBell(needsYou: needsYou, onOpen: onOpen),
                  IconButton(
                    onPressed: onMenu,
                    icon: const Icon(Icons.menu, size: 19),
                    color: colors.muted,
                    tooltip: context.l.menu,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const LocaleSwitch(compact: true),
            ],
          ),
        ],
      ),
    );
  }
}

/// The conversations the assistant handed to the seller, as a bell with a
/// count and a list that opens each one.
///
/// Asked for on 23 September 2026: "I have the page opened but I can't tell a
/// chat requires my attention." Only hand-overs, not every unanswered message —
/// the waiting count beside the wordmark already says how many are unanswered,
/// and a bell that rings for everything is a bell nobody looks at.
class _NeedsYouBell extends StatelessWidget {
  const _NeedsYouBell({required this.needsYou, required this.onOpen});

  final List<Conversation> needsYou;
  final ValueChanged<Conversation> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      style: const MenuStyle(
        maximumSize: WidgetStatePropertyAll(Size(340, 420)),
      ),
      menuChildren: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
          child: Text(
            needsYou.isEmpty ? l.needsYouEmpty : l.needsYouList,
            style: Style.meta.copyWith(
              color: colors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (final c in needsYou)
          MenuItemButton(
            onPressed: () => onOpen(c),
            leadingIcon: PlatformIcon(platform: c.platform, size: 14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Two widgets, not one string: an Arabic name and a Latin
                  // "23h" in one line reorder into "23 · سارةh".
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          c.customerName ?? l.customer,
                          style: Style.name.copyWith(color: colors.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        waitedFor(context, c.lastInboundAt),
                        style: Style.meta.copyWith(color: colors.muted),
                      ),
                    ],
                  ),
                  if (assistantReason(l, c) case final reason?)
                    Text(
                      reason,
                      style: Style.meta.copyWith(color: colors.urgent),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
      ],
      builder: (context, menu, _) => IconButton(
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        tooltip: l.needsYouTooltip,
        visualDensity: VisualDensity.compact,
        color: needsYou.isEmpty ? colors.muted : colors.urgent,
        icon: Badge(
          isLabelVisible: needsYou.isNotEmpty,
          backgroundColor: colors.urgent,
          label: Text('${needsYou.length}'),
          child: Icon(
            needsYou.isEmpty
                ? Icons.notifications_none
                : Icons.notifications_active,
            size: 19,
          ),
        ),
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
            //
            // The shift alone was not enough. Hover uses the same colour at
            // half strength, so the open conversation differed from whichever
            // row the pointer happened to be over by one step of a very pale
            // violet, and on a screen that is not the one this was designed on
            // it read as nothing at all. The bar below is the part hover cannot
            // imitate.
            //
            // A hand-over is tinted red whatever else is true of the row, so
            // it stands out in a list the seller is scanning, not reading.
            color: widget.selected
                ? colors.raised
                : c.escalated
                    ? colors.urgent.withValues(alpha: _hovered ? 0.12 : 0.07)
                    : _hovered
                        ? colors.raised.withValues(alpha: 0.5)
                        : colors.surface,
            padding: EdgeInsetsDirectional.only(
              // The bar is drawn inside the row's own start padding rather than
              // over it, so nothing shifts sideways when a row is opened.
              start: widget.selected ? 13 : 16,
              top: 13,
              end: 20,
              bottom: 13,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full height and hard against the start edge, which is what
                // separates it from the wait rail 13px along: that one is a
                // short gauge, mostly pale, and it says something else.
                if (widget.selected) ...[
                  Container(
                    width: 3,
                    constraints: const BoxConstraints(minHeight: 46),
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                // The rail only appears where a window is running down. On an
                // answered row nothing is counting, and an empty track is noise.
                SizedBox(
                  width: 12,
                  child: c.awaitingReply
                      ? _WaitRail(expiresAt: c.windowExpiresAt)
                      : null,
                ),
                _Monogram(
                  name: name,
                  platform: c.platform,
                  avatarUrl: c.customerAvatarUrl,
                ),
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
                      if (c.escalated)
                        const _NeedsYouPill()
                      else
                        _AssistantMark(conversation: c),
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

/// That the assistant touched this conversation, on the row, so the seller does
/// not have to open one to find out.
///
/// The row says what happened and the details pane says why. It carried the why
/// too at first, and on a row that already holds a name, a time and the
/// customer's own words it was a third line of prose that ran out of width at
/// the point it began to mean something.
///
/// Without any mark at all an escalated conversation is indistinguishable from
/// one the seller has simply not got to, and the whole point of the assistant is
/// that those are now different things. So the mark stays on the row; only the
/// sentence moved.
///
/// Teal, the same colour as an assistant message in the thread. As there, the
/// colour is not the only signal — it says in words what happened, which is what
/// a seller who cannot separate teal from violet reads instead.
class _AssistantMark extends StatelessWidget {
  const _AssistantMark({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final note = assistantMark(context.l, conversation);
    if (note == null) return const SizedBox.shrink();

    final colors = context.rabta;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            // Handing back and having answered are opposite outcomes and must
            // not share a glyph: one needs the seller and one does not.
            //
            // A flag rather than anything cleverer because this is drawn at
            // 12px. The first choice here was assistant_direction_outlined,
            // which at this size resolves to a dark circular blob that reads
            // as an error badge — seen in the browser, invisible to every test
            // written about this widget.
            conversation.escalated
                ? Icons.flag_outlined
                : Icons.auto_awesome_outlined,
            size: 12,
            color: colors.assistant,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              note,
              style: Style.meta.copyWith(color: colors.assistant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A solid red pill on a row the assistant handed over. Words and a hand as
/// well as colour, for a seller who cannot tell red from violet.
class _NeedsYouPill extends StatelessWidget {
  const _NeedsYouPill();

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: colors.urgent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.front_hand, size: 12, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                context.l.needsYou,
                style: Style.meta.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
  const _Monogram({
    required this.name,
    required this.platform,
    this.avatarUrl,
  });

  final String name;
  final String platform;

  /// Meta's own URL, which expires after about 30 days. Nothing is downloaded
  /// and stored, because the monogram below is a good enough answer when it
  /// eventually breaks — and it is already drawn.
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final trimmed = name.trim();
    // Characters, not code units: an Arabic or emoji first letter must survive.
    final initial =
        trimmed.isEmpty ? '·' : String.fromCharCode(trimmed.runes.first);

    final monogram = Container(
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
    );

    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (avatarUrl == null)
            monogram
          else
            ClipOval(
              child: Image.network(
                avatarUrl!,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                // An expired URL, a blocked request, or no network. The
                // monogram is the answer in all three, and it is the same
                // shape and size, so nothing moves when it takes over.
                errorBuilder: (context, error, stack) => monogram,
                // Shown rather than nothing while it loads: a hole where a
                // face will appear reads as broken.
                frameBuilder: (context, child, frame, wasSynchronous) =>
                    frame == null && !wasSynchronous ? monogram : child,
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
    this.onSent,
    this.revision = 0,
    this.showAssistant = false,
  });

  final Inbox inbox;
  final Conversation conversation;

  /// Changes when the database says something happened. The thread reloads,
  /// which is how a customer's reply appears without the seller reloading.
  final int revision;

  /// Only set when the thread has the screen to itself.
  final VoidCallback? onBack;

  /// Hands the loaded messages back up, so the details pane can describe them
  /// without asking the database for the same rows again.
  final ValueChanged<List<Message>>? onMessages;

  /// A reply has reached the customer. The list above needs to know: the
  /// conversation has just left the group of those waiting for one.
  final ValueChanged<Message>? onSent;

  /// Whether this thread has to carry what the assistant did, because the
  /// details pane that normally shows it is not on screen at this width.
  final bool showAssistant;

  @override
  State<_Thread> createState() => _ThreadState();
}

class _ThreadState extends State<_Thread> {
  late final Future<List<Message>> _messages = _load();

  /// What came from the database, and what has been sent since. Kept apart so
  /// a reply can be shown the moment Meta accepts it without asking for the
  /// whole conversation again.
  List<Message> _loaded = const [];
  final List<Message> _sent = [];

  List<Message> get _all => mergeMessages(_loaded, _sent);

  @override
  void didUpdateWidget(_Thread old) {
    super.didUpdateWidget(old);
    if (old.revision != widget.revision) _reload();
  }

  /// Reads the conversation again, without dropping what is on screen.
  ///
  /// The future is deliberately not replaced: doing that empties the builder
  /// and blanks the thread the seller is reading, for as long as the query
  /// takes.
  Future<void> _reload() async {
    final List<Message> messages;
    try {
      messages = await widget.inbox.messages(widget.conversation.id);
    } catch (_) {
      return;
    }

    if (!mounted) return;

    // Anything sent from here that has since come back — our own echo, most
    // often — is dropped by mergeMessages rather than shown twice.
    setState(() => _loaded = messages);

    widget.onMessages?.call(_all);
  }

  void _handleSent(Message message) {
    setState(() => _sent.add(message));
    widget.onMessages?.call(_all);
    widget.onSent?.call(message);
  }

  Future<List<Message>> _load() async {
    final messages = await widget.inbox.messages(widget.conversation.id);
    _loaded = messages;
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
                _Monogram(
                  name: name,
                  platform: c.platform,
                  avatarUrl: c.customerAvatarUrl,
                ),
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

          // Above the messages rather than among them: it is not something
          // anyone said, and a card in the run of bubbles reads as one.
          //
          // A hand-over is shown at every width, even where the details pane
          // is open beside it: it is the one thing here the seller must not
          // miss, and the pane is where the eye goes last.
          if (widget.showAssistant || widget.conversation.escalated)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: AssistantCard(conversation: widget.conversation),
            ),

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

                final messages = _all;

                // Built oldest to newest, because whether a bubble carries a
                // time depends on the message that follows it.
                //
                // Time separates runs of messages rather than stamping each
                // one. Repeating it on every bubble is noise when three arrive
                // in the same minute.
                final rows = [
                  for (var i = 0; i < messages.length; i++)
                    (
                      message: messages[i],
                      showTime: i == messages.length - 1 ||
                          messages[i + 1].inbound != messages[i].inbound ||
                          messages[i + 1].sentAt.difference(messages[i].sentAt) >
                              const Duration(minutes: 10),
                    ),
                ];

                // Anchored at the newest message, which is the one the seller
                // came for — and which a reply has just added to. Scrolling
                // there after the fact means racing the layout, and it lost:
                // the reply landed with its timestamp cut off by the composer.
                return ListView.builder(
                  reverse: true,
                  padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 28),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final row = rows[rows.length - 1 - i];
                    return _Bubble(
                      message: row.message,
                      showTime: row.showTime,
                    );
                  },
                );
              },
            ),
          ),
          _Composer(
            conversation: c,
            inbox: widget.inbox,
            onSent: _handleSent,
          ),
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
                // carry the accent; the assistant's carry teal. No border on
                // any of them — the ground behind them does the separating,
                // and a hairline around every bubble is what makes an
                // interface look like a default kit.
                color: switch (message) {
                  _ when inbound => colors.surface,
                  _ when message.byAssistant => colors.assistant,
                  _ => colors.accent,
                },
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
                child: message.byAssistant
                    // The colour is the signal a seller reads at a glance, but
                    // it cannot be the only one: violet and teal are close in
                    // lightness, so anyone who cannot separate the two hues
                    // would have nothing to go on. One word costs a line and
                    // removes the doubt.
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.l.sentAutomatically,
                            style: Style.meta.copyWith(
                              color: colors.onAccent.withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: 4),
                          _Body(message: message, inbound: inbound),
                        ],
                      )
                    : _Body(message: message, inbound: inbound),
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
/// Writing a reply, or being told plainly why one cannot be written.
///
/// Whether the box appears at all is decided by the reply window and nothing
/// else — not by whether the customer wrote last. A seller who has already
/// answered may still follow up, because the 24 hours run from the customer's
/// message and Meta does not care how many replies fill them. Deciding it any
/// other way here would make the interface refuse what the server accepts.
class _Composer extends StatefulWidget {
  const _Composer({required this.conversation, required this.inbox, this.onSent});

  final Conversation conversation;
  final Inbox inbox;
  final ValueChanged<Message>? onSent;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  String? _refusal;
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _text.text.trim().isEmpty) return;

    setState(() {
      _sending = true;
      _refusal = null;
    });

    try {
      final sent = await widget.inbox.send(widget.conversation.id, _text.text);
      if (!mounted) return;

      // Cleared only once it has actually gone. A reply that failed is still
      // in the box, because asking the seller to type it again is the worst
      // thing this screen could do to them.
      _text.clear();
      widget.onSent?.call(sent);
      _focus.requestFocus();
    } on SendRefused catch (error) {
      if (mounted) setState(() => _refusal = error.reason);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final expires = widget.conversation.windowExpiresAt;
    final open = replyWindowOpen(expires);
    final gutter = _gutter(context);

    final frame = BoxDecoration(
      color: colors.surface,
      border: Border(top: BorderSide(color: colors.edge)),
    );
    final padding = EdgeInsetsDirectional.fromSTEB(gutter, 16, gutter, 18);

    if (!open) {
      final never = expires == null;

      return Container(
        decoration: frame,
        padding: padding,
        child: Row(
          children: [
            Icon(
              never ? Icons.schedule : Icons.lock_outline,
              size: 15,
              color: never ? colors.muted : colors.urgent,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                never
                    ? context.l.sendFailedNoWindow
                    : context.l.replyWindowClosedLong,
                style: Style.preview.copyWith(
                  color: never ? colors.muted : colors.urgent,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final remaining = windowRemaining(context, expires);
    final closing = windowClosingSoon(expires);

    return Container(
      decoration: frame,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_refusal != null) ...[
            Row(
              children: [
                Icon(Icons.error_outline, size: 15, color: colors.urgent),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    sendRefusal(context.l, _refusal!),
                    style: Style.preview.copyWith(color: colors.urgent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                // Enter sends, because this is a keyboard job done all day.
                // Shift+Enter does not match this activator, so it still puts
                // in a line break.
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.enter): _send,
                  },
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _text,
                    builder: (context, value, _) => TextField(
                      controller: _text,
                      focusNode: _focus,
                      enabled: !_sending,
                      minLines: 1,
                      maxLines: 5,
                      // The seller's own words take their direction from what
                      // they are writing, exactly as the customer's do. An
                      // Arabic reply typed into an English interface is the
                      // case that looks correct until someone tries it.
                      textDirection: directionOf(value.text),
                      style: Style.message.copyWith(color: colors.ink),
                      cursorColor: colors.accent,
                      decoration: InputDecoration(
                        hintText: context.l.composerHint,
                        hintStyle: Style.preview.copyWith(color: colors.muted),
                        filled: true,
                        fillColor: colors.ground,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        border: _fieldBorder(colors.line),
                        enabledBorder: _fieldBorder(colors.line),
                        focusedBorder: _fieldBorder(colors.accent, 1.5),
                        disabledBorder: _fieldBorder(colors.line),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _text,
                builder: (context, value, _) {
                  final ready = !_sending && value.text.trim().isNotEmpty;

                  return IconButton.filled(
                    onPressed: ready ? _send : null,
                    tooltip: _sending ? context.l.sending : context.l.sendReply,
                    // Directional: in Arabic the arrow points the other way.
                    icon: Icon(
                      _sending ? Icons.more_horiz : Icons.send,
                      size: 18,
                      textDirection: Directionality.of(context),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: colors.onAccent,
                      disabledBackgroundColor: colors.accentSoft,
                      disabledForegroundColor: colors.muted,
                      padding: const EdgeInsets.all(13),
                    ),
                  );
                },
              ),
            ],
          ),
          if (remaining != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (closing) ...[
                  Icon(Icons.timelapse, size: 13, color: colors.urgent),
                  const SizedBox(width: 7),
                ],
                Text(
                  remaining,
                  style: Style.meta.copyWith(
                    color: closing ? colors.urgent : colors.muted,
                    fontWeight: closing ? FontWeight.w700 : FontWeight.w300,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

OutlineInputBorder _fieldBorder(Color color, [double width = 1]) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: width),
    );

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
