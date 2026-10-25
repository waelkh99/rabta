// The name.
//
// Inboxara is a Latin coinage, so it is set once, in Latin, in both interface
// languages — the way Careem or Talabat appear in an Arabic layout. Arabic copy
// writes it إنبوكسارا, as the strings already write إنستغرام and واتساب.
//
// "Inbox" carries the ink and "ara" the accent: the plain word the product is
// built around, and the part that makes it a name.
//
// It is one widget so the spelling and the split are fixed in one place.

import 'package:flutter/material.dart';

import '../theme.dart';

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 21, this.onDark = false});

  final double size;

  /// When the mark sits on one of the dark panels rather than on the ground.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final style = display(Style.brand.copyWith(fontSize: size));

    // Always left-to-right: a Latin name must not be mirrored in an Arabic
    // layout.
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: 'Inbox',
            style: TextStyle(color: onDark ? colors.onNight : colors.ink),
          ),
          TextSpan(
            text: 'ara',
            style: TextStyle(color: onDark ? colors.saffron : colors.accent),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    );
  }
}
