// The name, in both scripts.
//
// رِبطة is Arabic for a tie — the thing that binds two things together, and the
// knot a seller ties with a customer. The Latin "Rabta" is a transliteration of
// it, not the other way round, which is why the Arabic is set at equal weight
// rather than as a subtitle under an English name.
//
// It is one widget so the two never drift apart, and so the spelling is fixed
// in one place: it was briefly written رابطة, which is a different word — a
// league or an association.

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
    final first = onDark ? colors.onNight : colors.ink;
    final second = onDark ? colors.saffron : colors.accent;

    // Always left-to-right, in both interface directions: this is a lockup, and
    // mirroring it would reorder the two halves of a name.
    //
    // The saffron knot between the two halves is the name made literal: a tie
    // between two things.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Rabta',
            style: display(Style.brand.copyWith(fontSize: size, color: first)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.22),
            child: _Knot(size: size * 0.62, color: colors.saffron, ink: first),
          ),
          Text(
            'ربطة',
            textDirection: TextDirection.rtl,
            style: display(
              Style.brand.copyWith(
                fontSize: size * 0.95,
                fontWeight: FontWeight.w700,
                color: second,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two interlocking rings.
class _Knot extends StatelessWidget {
  const _Knot({required this.size, required this.color, required this.ink});

  final double size;
  final Color color;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final ring = size * 0.62;
    final stroke = size * 0.15;

    Widget circle(Color c) => Container(
          width: ring,
          height: ring,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c, width: stroke),
          ),
        );

    return SizedBox(
      width: size,
      height: ring,
      child: Stack(
        children: [
          Positioned(left: 0, child: circle(color)),
          Positioned(right: 0, child: circle(ink)),
        ],
      ),
    );
  }
}
