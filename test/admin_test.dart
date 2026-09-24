// The admin screen's rules, and the reporting that feeds it.

import 'package:flutter_test/flutter_test.dart';

import 'package:rabta/admin_page.dart';
import 'package:rabta/data.dart';
import 'package:rabta/reporting.dart';

AdminOverview _o(Map<String, dynamic> health) => AdminOverview({'health': health});

void main() {
  group('what needs attention', () {
    test('nothing when every count is zero', () {
      expect(healthProblems(_o({'stuck': 0, 'failing': 0, 'errors_24h': 0})), isEmpty);
    });

    test('a message that gave up leads, before an ordinary error', () {
      expect(
        healthProblems(_o({'errors_24h': 3, 'stuck': 1, 'accounts_need_reconnect': 2})),
        ['stuck', 'accounts_need_reconnect', 'errors_24h'],
      );
    });

    test('warnings alone are not a problem', () {
      expect(healthProblems(_o({'warnings_24h': 9})), isEmpty);
    });

    test('a missing health block is read as nothing wrong, not a crash', () {
      expect(healthProblems(AdminOverview({})), isEmpty);
    });

    test('cost arrives as a number or as numeric text', () {
      expect(_o({'ai_cost_month': 1.25}).aiCostMonth, 1.25);
      expect(_o({'ai_cost_month': '0.004200'}).aiCostMonth, 0.0042);
    });
  });

  group('password rule, matching the server', () {
    test('ten characters with lower, upper and a digit passes', () {
      expect(passwordStrongEnough('Rabta2026ok'), isTrue);
    });

    test('each missing part is refused', () {
      expect(passwordStrongEnough('Rabta2026'), isFalse, reason: 'nine characters');
      expect(passwordStrongEnough('rabta2026ok'), isFalse, reason: 'no upper case');
      expect(passwordStrongEnough('RABTA2026OK'), isFalse, reason: 'no lower case');
      expect(passwordStrongEnough('RabtaRabtaok'), isFalse, reason: 'no digit');
    });
  });

  group('reporting', () {
    test('the build hash is read from flutter_bootstrap.js', () {
      expect(buildIdIn('_flutter.loader.load({serviceWorkerSettings: {serviceWorkerVersion: "2256469244" /* x */}})'), '2256469244');
      expect(buildIdIn('no hash here'), isNull);
    });

    test('a report is cut to what the table accepts', () {
      expect(trimmed('x' * 3000, 2000).length, 2000);
      expect(trimmed('short', 2000), 'short');
    });
  });
}
