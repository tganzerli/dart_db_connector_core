/// Transaction boundary abstraction, shared by every relational driver.
///
/// A [UnitOfWork] frames a sequence of executor calls inside a single
/// database transaction (`BEGIN` / `COMMIT` / `ROLLBACK`). `Repository`
/// implementations consume the executor handed out by an active UoW;
/// they do not know about transactions directly.
///
/// The **shape of the query is deliberately not part of this contract**.
/// Postgres speaks the Extended Query Protocol with bound params and an
/// optional binary result format, MySQL v1 is simple-protocol with no
/// bound params, and a document store has no SQL at all. Forcing one
/// `execute` signature here would invent a false common denominator; the
/// executor type is a parameter instead, and each driver package pins
/// its own.
library;

import 'errors.dart';

/// Frame for a single database transaction.
///
/// [E] is the driver's concrete executor type, pinned to the
/// transaction's connection.
///
/// Lifecycle: `begin → executor.execute(...) ×N → commit | rollback → close`.
/// `close()` is idempotent and rolls back if the transaction is still
/// active, so callers can rely on `try/finally` for cleanup.
abstract interface class UnitOfWork<E extends Object> {
  /// `true` while a transaction is open (between [begin] and a
  /// terminating [commit]/[rollback]/[close]).
  bool get isActive;

  /// The executor pinned to the transaction's connection. Reading this
  /// before [begin] throws [TransactionStateError].
  E get executor;

  /// Opens the transaction on a pooled connection.
  ///
  /// Implementations may **defer** the physical `BEGIN`: the Postgres
  /// implementation sends no `BEGIN` here and instead
  /// fuses it into the first statement of the body (`BEGIN;<sql>` in a
  /// single round-trip on the Simple Protocol), or emits a standalone
  /// `BEGIN` when that first statement uses the Extended Protocol
  /// (bound params or binary results). Either way the transaction
  /// exists server-side from the first executed statement onward, and
  /// [isActive] reads `true` from `begin()` — it tracks the *logical*
  /// transaction (pinned connection + valid executor), not the moment
  /// the server opened it.
  ///
  /// Error semantics of the deferred/fused BEGIN: a failure in the first
  /// body statement leaves the server in an aborted-transaction state
  /// and surfaces as [QueryFailedException] carrying the real server
  /// message; the transaction's [rollback] (or [close]) then cleans up
  /// correctly and the connection is reusable. A connection failure that
  /// a previous eager `BEGIN` would have raised here now surfaces on the
  /// first body statement instead — `withTransaction` already routes
  /// that through rollback + rethrow.
  ///
  /// Throws [TransactionStateError] if a transaction is already active.
  Future<void> begin();

  /// Commits the transaction (`COMMIT`) and releases the connection.
  /// Throws [TransactionStateError] if no transaction is active.
  Future<void> commit();

  /// Rolls back the transaction (`ROLLBACK`) and releases the connection.
  /// Throws [TransactionStateError] if no transaction is active.
  Future<void> rollback();

  /// Idempotent shutdown. If a transaction is still active, performs a
  /// best-effort rollback before releasing the connection. Calling twice
  /// is a no-op.
  Future<void> close();
}
