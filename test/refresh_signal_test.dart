import 'package:flutter_test/flutter_test.dart';
import 'package:adot_shop_app/services/refresh_signal.dart';

void main() {
  group('RefreshSignal Singleton Tests', () {
    test('RefreshSignal factory returns singleton instance', () {
      final s1 = RefreshSignal();
      final s2 = RefreshSignal();
      expect(identical(s1, s2), isTrue);
    });

    test('notifyDataChanged increments version and triggers listeners', () {
      final signal = RefreshSignal();
      final initialVersion = signal.version;
      int listenerCallCount = 0;

      void listener() {
        listenerCallCount++;
      }

      signal.addListener(listener);
      signal.notifyDataChanged();

      expect(signal.version, equals(initialVersion + 1));
      expect(listenerCallCount, equals(1));

      signal.removeListener(listener);
    });
  });
}
