// Which platform a conversation came from.
//
// A coloured dot said "these two are different" and nothing more — the seller
// had to learn which colour meant which. A brand mark is recognised without
// being learned, which is the whole point of one.
//
// Drawn here rather than pulled from an icon package: font_awesome_flutter does
// not compile against Flutter 3.47, where IconData became a final class it can
// no longer extend. Two glyphs are not worth waiting on someone else's release,
// and these have no font to download.
//
// They stay small and appear in three places only: on the monogram in the list,
// beside the name in the thread header, and against the platform row in the
// details pane. The interface is never tinted by platform, because the product
// exists to be one workspace rather than two inboxes side by side.

import 'package:flutter/material.dart';

import 'theme.dart';

/// The mark on its own, in the platform's own colour.
class PlatformIcon extends StatelessWidget {
  const PlatformIcon({super.key, required this.platform, this.size = 14});

  final String platform;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = context.rabta.platform(platform);

    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: platform == 'instagram'
            ? _InstagramPainter(color)
            : _MessengerPainter(color, filled: false),
      ),
    );
  }
}

/// The mark as a badge on the corner of a monogram: filled with the platform's
/// colour so it reads at 15px, where an outline would not, with a ring of the
/// surface behind it to lift it off the circle underneath.
class PlatformBadge extends StatelessWidget {
  const PlatformBadge({super.key, required this.platform, this.ringColor});

  final String platform;

  /// What the badge sits on. Defaults to the surface.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: ringColor ?? colors.surface,
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 15,
        height: 15,
        decoration: BoxDecoration(
          color: colors.platform(platform),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(3),
        child: CustomPaint(
          painter: platform == 'instagram'
              ? _InstagramPainter(Colors.white, strokeScale: 0.14)
              : _MessengerPainter(Colors.white, filled: true),
        ),
      ),
    );
  }
}

/// Rounded square, a ring inside it, and the dot in the upper corner.
class _InstagramPainter extends CustomPainter {
  _InstagramPainter(this.color, {this.strokeScale = 0.11});

  final Color color;
  final double strokeScale;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * strokeScale;

    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final inset = stroke / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(inset, inset, s - stroke, s - stroke),
        Radius.circular(s * 0.28),
      ),
      pen,
    );

    canvas.drawCircle(Offset(s / 2, s / 2), s * 0.22, pen);

    canvas.drawCircle(
      Offset(s * 0.74, s * 0.26),
      stroke * 0.62,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_InstagramPainter old) =>
      old.color != color || old.strokeScale != strokeScale;
}

/// The Messenger balloon — a circle drawn slightly wide, with the tail at the
/// bottom start corner — and the bolt inside it.
class _MessengerPainter extends CustomPainter {
  _MessengerPainter(this.color, {required this.filled});

  final Color color;

  /// Filled draws the bolt as a hole in a solid balloon, for the badge. Unfilled
  /// outlines the balloon and strokes the bolt, for use beside text.
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;

    // The bolt: into the balloon, across, down, and back out.
    final bolt = Path()
      ..moveTo(s * 0.22, s * 0.56)
      ..lineTo(s * 0.46, s * 0.30)
      ..lineTo(s * 0.60, s * 0.47)
      ..lineTo(s * 0.79, s * 0.30)
      ..lineTo(s * 0.55, s * 0.57)
      ..lineTo(s * 0.41, s * 0.40)
      ..close();

    if (filled) {
      // The balloon is already the coloured circle behind this painter, so only
      // the bolt is drawn, in the ring colour.
      canvas.drawPath(bolt, Paint()..color = color);
      return;
    }

    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.10
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final balloon = Path()
      ..addOval(Rect.fromLTWH(s * 0.06, s * 0.04, s * 0.88, s * 0.82));

    // The tail, which is what tells it apart from any other round chat icon.
    final tail = Path()
      ..moveTo(s * 0.20, s * 0.78)
      ..lineTo(s * 0.12, s * 0.96)
      ..lineTo(s * 0.36, s * 0.86);

    canvas.drawPath(balloon, pen);
    canvas.drawPath(tail, pen..strokeWidth = s * 0.09);
    canvas.drawPath(
      bolt,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_MessengerPainter old) =>
      old.color != color || old.filled != filled;
}
