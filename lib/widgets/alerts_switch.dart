// The control that turns notifications on and off.
//
// It lived in the drawer at first, for a reason that had nothing to do with
// where it belongs: every browser requires the permission prompt to come from
// something the seller did, so there had to be a thing to tap, and the drawer
// already existed. Now that the shop screen carries the seller's own settings,
// this is one of them.
//
// The row states what is true rather than always offering a switch. Two of the
// four states are not a choice: refused once, no browser will ask again, and a
// switch that cannot move is worse than a sentence saying why. In a Safari tab
// on an iPhone the API is absent entirely, which is not a refusal and must not
// read as a fault — the seller has to add Rabta to their home screen first.

import 'package:flutter/material.dart';

import '../services/alerts.dart';
import '../strings.dart';
import '../theme.dart';

class AlertsSwitch extends StatefulWidget {
  const AlertsSwitch({super.key});

  @override
  State<AlertsSwitch> createState() => _AlertsSwitchState();
}

class _AlertsSwitchState extends State<AlertsSwitch> {
  late AlertState _state = alertState();
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;

    if (_state == AlertState.on) {
      turnAlertsOff();
      setState(() => _state = alertState());
      return;
    }

    // Asking the browser takes as long as the seller takes to read the prompt,
    // and the switch must not look stuck or accept a second tap while it does.
    setState(() => _busy = true);
    final next = await turnAlertsOn();
    if (mounted) {
      setState(() {
        _state = next;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    final choosable = _state == AlertState.on || _state == AlertState.off;
    final on = _state == AlertState.on;

    return InkWell(
      onTap: choosable && !_busy ? _toggle : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 8, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.line),
        ),
        child: Row(
          children: [
            Icon(
              on ? Icons.notifications_active_outlined : Icons.notifications_none,
              size: 18,
              color: on ? colors.accent : colors.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                alertStateLabel(l, _state),
                style: Style.name.copyWith(
                  color: choosable ? colors.ink : colors.muted,
                ),
              ),
            ),
            // Nothing at all where there is no choice. A greyed-out switch
            // invites a tap and then refuses it, which reads as a fault.
            if (choosable)
              Switch(
                value: on,
                onChanged: _busy ? null : (_) => _toggle(),
              ),
          ],
        ),
      ),
    );
  }
}
