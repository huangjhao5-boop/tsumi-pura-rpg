import 'dart:async';

/// An asynchronous mutual exclusion lock (mutex).
///
/// Guarantees that asynchronous critical sections execute sequentially in FIFO order.
/// Supports re-entrancy within the same async Zone context to prevent deadlocks
/// when nested methods acquire the same lock.
class AsyncLock {
  Future<void>? _lastOperation;
  final Object _zoneKey = Object();

  /// Returns true if the lock is currently held by an ongoing operation.
  bool get isLocked => _lastOperation != null;

  /// Executes [computation] exclusively within the lock.
  ///
  /// - If the current asynchronous context already holds this lock (re-entrant call),
  ///   [computation] is executed immediately to prevent deadlock.
  /// - If an earlier queued operation throws an exception, subsequent operations
  ///   will still execute without being blocked or cancelled.
  Future<T> synchronized<T>(FutureOr<T> Function() computation) {
    // Re-entrancy check: if already executing inside this lock's zone, run immediately.
    if (Zone.current[_zoneKey] == true) {
      return Future.sync(computation);
    }

    final prev = _lastOperation;
    final completer = Completer<void>();
    _lastOperation = completer.future;

    Future<void> waitForPrev() {
      if (prev == null) return Future.value();
      return prev.catchError((_) {
        // Suppress previous errors so that a failed operation does not
        // deadlock or break subsequent operations in the queue.
      });
    }

    return waitForPrev().then((_) {
      return runZoned(
        () => Future.sync(computation),
        zoneValues: {_zoneKey: true},
      );
    }).whenComplete(() {
      if (identical(_lastOperation, completer.future)) {
        _lastOperation = null;
      }
      completer.complete();
    });
  }
}
