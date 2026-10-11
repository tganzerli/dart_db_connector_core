/// The transaction-lifecycle conformance battery, shared by every driver.
///
/// This is the executable half of the vertical contract: `UnitOfWork<E>`
/// declares the states, this file checks that a driver actually honours
/// the transitions between them. It is a plain library, not a `_test.dart`
/// file, so a driver that lives in its own package can import it and run
/// the same battery it passed while it was still in the monolith.
///
/// Nothing here knows what a query looks like — the query shape is
/// per-driver by design. Everything here is `begin` / `commit` /
/// `rollback` / `close` and the errors those transitions raise.
library;

import 'package:dart_db_connector_core/dart_db_connector_core.dart';
import 'package:test/test.dart';

/// Runs the battery for one driver.
///
/// [open] must return a **fresh, not-yet-begun** unit of work on every
/// call; each test drives its own instance so the cases stay independent.
/// [driver] only names the group.
void runUnitOfWorkConformance<E extends Object>({
  required String driver,
  required Future<UnitOfWork<E>> Function() open,
}) {
  group('$driver — transaction contract conformance', () {
    test('a fresh unit of work is not active', () async {
      final uow = await open();
      try {
        expect(uow.isActive, isFalse);
      } finally {
        await uow.close();
      }
    });

    test('reading executor before begin throws TransactionStateError',
        () async {
      final uow = await open();
      try {
        expect(() => uow.executor, throwsA(isA<TransactionStateError>()));
      } finally {
        await uow.close();
      }
    });

    test('commit without begin throws TransactionStateError', () async {
      final uow = await open();
      try {
        await expectLater(uow.commit(), throwsA(isA<TransactionStateError>()));
      } finally {
        await uow.close();
      }
    });

    test('rollback without begin throws TransactionStateError', () async {
      final uow = await open();
      try {
        await expectLater(
            uow.rollback(), throwsA(isA<TransactionStateError>()));
      } finally {
        await uow.close();
      }
    });

    test('begin activates and hands out an executor of type E', () async {
      final uow = await open();
      try {
        await uow.begin();
        expect(uow.isActive, isTrue);
        expect(uow.executor, isA<E>());
      } finally {
        await uow.close();
      }
    });

    test('nested begin throws TransactionStateError', () async {
      final uow = await open();
      try {
        await uow.begin();
        await expectLater(uow.begin(), throwsA(isA<TransactionStateError>()));
      } finally {
        await uow.close();
      }
    });

    test('commit deactivates', () async {
      final uow = await open();
      try {
        await uow.begin();
        await uow.commit();
        expect(uow.isActive, isFalse);
      } finally {
        await uow.close();
      }
    });

    test('rollback deactivates', () async {
      final uow = await open();
      try {
        await uow.begin();
        await uow.rollback();
        expect(uow.isActive, isFalse);
      } finally {
        await uow.close();
      }
    });

    test('close rolls back an open transaction and is idempotent', () async {
      final uow = await open();
      await uow.begin();
      await uow.close();
      expect(uow.isActive, isFalse);
      // Second close must be a no-op, so `try/finally` cleanup is safe
      // even when the body already closed.
      await uow.close();
      expect(uow.isActive, isFalse);
    });

    test('commit after close throws TransactionStateError', () async {
      final uow = await open();
      await uow.begin();
      await uow.close();
      await expectLater(uow.commit(), throwsA(isA<TransactionStateError>()));
    });
  });
}
