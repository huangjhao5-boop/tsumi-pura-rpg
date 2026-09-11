import 'package:flutter_test/flutter_test.dart';
import 'package:nifty_heisenberg/core/utils/async_lock.dart';

void main() {
  group('AsyncLock Unit Tests', () {
    test('Sequential execution: operations run strictly one after another in FIFO order', () async {
      final lock = AsyncLock();
      final executionOrder = <int>[];

      final f1 = lock.synchronized(() async {
        await Future.delayed(const Duration(milliseconds: 30));
        executionOrder.add(1);
        return 'first';
      });

      final f2 = lock.synchronized(() async {
        await Future.delayed(const Duration(milliseconds: 10));
        executionOrder.add(2);
        return 'second';
      });

      final f3 = lock.synchronized(() async {
        executionOrder.add(3);
        return 'third';
      });

      final results = await Future.wait([f1, f2, f3]);

      expect(executionOrder, equals([1, 2, 3]));
      expect(results, equals(['first', 'second', 'third']));
      expect(lock.isLocked, isFalse);
    });

    test('Error resilience: an exception in an earlier operation does NOT block subsequent operations', () async {
      final lock = AsyncLock();
      final executed = <int>[];

      final f1 = lock.synchronized(() async {
        await Future.delayed(const Duration(milliseconds: 20));
        executed.add(1);
        throw Exception('Operation 1 simulated failure');
      });

      final f2 = lock.synchronized(() async {
        executed.add(2);
        return 'op2_ok';
      });

      expect(f1, throwsA(isA<Exception>()));
      final result2 = await f2;

      expect(executed, equals([1, 2]));
      expect(result2, equals('op2_ok'));
      expect(lock.isLocked, isFalse);
    });

    test('Re-entrancy: nested synchronized calls in the same Zone execute without deadlocking', () async {
      final lock = AsyncLock();

      final result = await lock.synchronized(() async {
        final inner1 = await lock.synchronized(() async {
          final inner2 = await lock.synchronized(() async {
            return 'deeply_nested_success';
          });
          return 'level1_$inner2';
        });
        return 'root_$inner1';
      });

      expect(result, equals('root_level1_deeply_nested_success'));
      expect(lock.isLocked, isFalse);
    });

    test('High-concurrency stress: 50 concurrent async tasks execute without dropping or corruption', () async {
      final lock = AsyncLock();
      final list = <int>[];
      const taskCount = 50;

      final futures = List.generate(taskCount, (i) {
        return lock.synchronized(() async {
          await Future.delayed(const Duration(milliseconds: 1));
          list.add(i);
        });
      });

      await Future.wait(futures);

      expect(list.length, equals(taskCount));
      expect(list, equals(List.generate(taskCount, (i) => i)));
      expect(lock.isLocked, isFalse);
    });

    test('Synchronous computation support and immediate return', () async {
      final lock = AsyncLock();

      final val = await lock.synchronized(() => 42);
      expect(val, equals(42));
      expect(lock.isLocked, isFalse);
    });
  });
}
