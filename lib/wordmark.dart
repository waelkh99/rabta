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

import 'theme.dart';

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 19, this.onAccent = false});

  final double size;

  /// When the mark sits on the accent colour rather than on the ground.
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    // Always left-to-right, in both interface directions: this is a lockup, and
    // mirroring it would reorder the two halves of a name.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            'Rabta',
            style: Style.brand.copyWith(
              fontSize: size,
              color: onAccent ? colors.onAccent : colors.ink,
            ),
          ),
          SizedBox(width: size * 0.36),
          Text(
            'ربطة',
            textDirection: TextDirection.rtl,
            style: Style.brand.copyWith(
              fontSize: size * 0.88,
              fontWeight: FontWeight.w400,
              color: onAccent ? colors.onAccent : colors.accent,
            ),
          ),
        ],
      ),
    );
  }
}
