// What `files.dart` talks to when there is no browser.
//
// Only the tests reach this, for the same reason as `alerts_stub.dart`: the VM
// that runs `flutter test` has no `dart:js_interop`.

import 'dart:convert';
import 'dart:typed_data';

import 'files.dart';

Future<Picked> pickPhotos() async => (photos: const <Never>[], failed: 0);

Future<({String name, Uint8List bytes})?> pickFile(String accept) async => null;

String decodeText(Uint8List bytes) => utf8.decode(bytes, allowMalformed: true);

void saveFile(String name, Uint8List bytes, String type) {}
