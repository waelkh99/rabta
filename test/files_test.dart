// How big a product photo is kept.
//
// The browser does the drawing; this is the arithmetic that decides it, and
// the part that would quietly store 6 MB photos or squash a portrait shot if
// it were wrong.

import 'package:flutter_test/flutter_test.dart';
import 'package:rabta/files.dart';

void main() {
  test('a phone photo is brought down to the long edge, keeping its shape', () {
    // 4032 x 3024 is what a recent phone camera takes.
    final size = fitWithin(4032, 3024, photoEdge);

    expect(size.width, 1600);
    expect(size.height, 1200);
  });

  test('a portrait photo is limited by its height, not its width', () {
    final size = fitWithin(3024, 4032, photoEdge);

    expect(size.width, 1200);
    expect(size.height, 1600);
  });

  test('a small photo is never scaled up', () {
    final size = fitWithin(800, 600, photoEdge);

    expect(size.width, 800);
    expect(size.height, 600);
  });

  test('a thumbnail is the same shape at its own size', () {
    final size = fitWithin(4032, 3024, thumbnailEdge);

    expect(size.width, 320);
    expect(size.height, 240);
  });

  test('a very thin image keeps at least one pixel', () {
    final size = fitWithin(10000, 2, photoEdge);

    expect(size.width, 1600);
    expect(size.height, 1);
  });
}
