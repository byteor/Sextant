import 'package:flutter_test/flutter_test.dart';
import 'package:sextant/platform/network_discovery.dart';

void main() {
  group('retryWhileEmpty', () {
    test('returns the first non-empty result without retrying', () async {
      var calls = 0;
      final result = await retryWhileEmpty<int>(
        () async {
          calls++;
          return [1, 2];
        },
        attempts: 4,
        delay: Duration.zero,
      );
      expect(result, [1, 2]);
      expect(calls, 1);
    });

    test('retries while empty, then returns once populated', () async {
      // Models a network coming up a couple of polls after a switch.
      var calls = 0;
      final result = await retryWhileEmpty<int>(
        () async {
          calls++;
          return calls < 3 ? <int>[] : [9];
        },
        attempts: 5,
        delay: Duration.zero,
      );
      expect(result, [9]);
      expect(calls, 3);
    });

    test('gives up after the attempt budget, returning empty', () async {
      var calls = 0;
      final result = await retryWhileEmpty<int>(
        () async {
          calls++;
          return <int>[];
        },
        attempts: 4,
        delay: Duration.zero,
      );
      expect(result, isEmpty);
      expect(calls, 4); // bounded — does not loop forever on a genuine no-network
    });
  });
}
