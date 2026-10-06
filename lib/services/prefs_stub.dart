// What `prefs.dart` talks to when there is no browser.
//
// Only the tests reach this: the product is a web application and has no other
// target. Reading nothing back means every preference falls to its default,
// which is what a test that is not about storage wants.

String? read(String key) => null;

void write(String key, String? value) {}
