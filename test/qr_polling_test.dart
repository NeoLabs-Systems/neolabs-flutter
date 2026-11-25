import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neolabs_flutter/neolabs_flutter.dart';

void main() {
  test('backs off failures and uses the long-poll gap after success', () {
    fakeAsync((time) {
      var count = 0;
      var held = false;
      final scheduler = NeoQrPolling(
        poll: () async {
          count++;
          return count > 1;
        },
        serverHoldsPolls: () => held,
        canPoll: () => true,
        interval: const Duration(seconds: 5),
        heldPollGap: const Duration(seconds: 1),
        maxInterval: const Duration(seconds: 8),
      );
      scheduler.start(fresh: true);
      time.elapse(const Duration(seconds: 1));
      expect(count, 1);
      time.elapse(const Duration(seconds: 2));
      expect(count, 2);
      held = true;
      time.elapse(const Duration(seconds: 5));
      expect(count, 3);
      time.elapse(const Duration(seconds: 1));
      expect(count, 4);
      scheduler.pause();
      time.elapse(const Duration(seconds: 20));
      expect(count, 4);
      scheduler.dispose();
    });
  });

  test('a held request for an old challenge does not block a new one', () {
    fakeAsync((time) {
      final first = Completer<bool?>();
      var count = 0;
      final scheduler = NeoQrPolling(
        poll: () {
          count++;
          return count == 1 ? first.future : Future.value(true);
        },
        serverHoldsPolls: () => true,
        canPoll: () => true,
        heldPollGap: const Duration(seconds: 1),
      );
      scheduler.start(fresh: true);
      time.elapse(const Duration(seconds: 1));
      expect(count, 1);
      scheduler.start(fresh: true);
      time.elapse(const Duration(seconds: 1));
      expect(count, 2);
      first.complete(false);
      time.flushMicrotasks();
      time.elapse(const Duration(seconds: 1));
      expect(count, 3);
      scheduler.dispose();
    });
  });
}
