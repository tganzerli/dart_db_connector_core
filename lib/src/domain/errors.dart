/// Vertical-contract errors, shared by every driver.
///
/// No imports: this file is the leaf of the contract package's dependency
/// graph. Drivers that only need the error types must not have to pull in
/// a relational `ResultSet`/`Param` to reach them.
library;

/// Signals an attempt to drive a `UnitOfWork` outside the lifecycle
/// states it allows.
///
/// Raised on illegal transitions: `commit` or `rollback` without a
/// preceding `begin`, double `begin`, or accessing `UnitOfWork.executor`
/// before the transaction is open. Wraps Dart's [StateError] for
/// `is`/`catch` compatibility with generic state-machine handling.
class TransactionStateError extends StateError {
  TransactionStateError(super.message);
}

/// Signals a SQL/protocol failure surfaced by the driver's client library
/// during query execution.
///
/// The native side refused dispatch (e.g. libpq `PQsendQuery` returned 0)
/// or the connection entered an error state mid-query. [serverMessage]
/// holds the client-library diagnostic when available. The connection is
/// left in an undefined state — most callers should `rollback()` the
/// transaction (or release + reopen the pool) before retrying.
class QueryFailedException implements Exception {
  final String sql;
  final String? serverMessage;

  /// Native error code when available (e.g. libmysqlclient `mysql_errno`).
  /// `null` for failures with no numeric code (dispatch refusals, PG paths).
  final int? code;

  QueryFailedException(this.sql, this.serverMessage, {this.code});

  @override
  String toString() {
    final detail = serverMessage ?? 'no detail';
    final codePart = code != null ? ' [code $code]' : '';
    return 'QueryFailedException($detail)$codePart while executing: $sql';
  }
}

/// Signals that a query exceeded its configured wall-clock timeout
/// (`timeout_ms` in the native ABI). The worker issued `PQcancel`
/// before throwing.
///
/// **The connection survives a timeout.** Until 2026-09-11 this doc
/// said the connection state was "undefined" and the caller should
/// close + reconnect, because the native layer could not tell a slow
/// query from a dead link — both arrived as port code 2. Now it can,
/// and a lost link raises [ConnectionLostException] instead. A timeout
/// means one query ran out of budget; the session is intact.
///
/// Added in ABI MAJOR 1.
class QueryTimeoutException implements Exception {
  final String sql;
  final Duration timeout;
  QueryTimeoutException(this.sql, this.timeout);

  @override
  String toString() =>
      'QueryTimeoutException after ${timeout.inMilliseconds}ms: $sql';
}

/// Signals that the link to the database server was lost.
///
/// Distinct from [QueryFailedException] (the server answered, with an
/// error) and from [QueryTimeoutException] (the session is alive, this
/// query ran out of budget). Here the session itself is gone.
///
/// **What the driver guarantees, and what it does not.** The submitted
/// statement is **not retried**: the wire protocol cannot distinguish
/// "the dispatch never reached the server" from "the server executed it
/// and the reply was lost", so an automatic retry would duplicate
/// writes, and no idempotency key exists to make that safe. A
/// transaction open when the link dropped is **poisoned** — every later
/// `commit()`, `rollback()` or query on that unit of work raises this
/// exception. The driver offers *"nothing was committed"*, never
/// *"it was undone"*: the rollback is the server's, performed when it
/// notices the dropped socket.
///
/// The connection slot itself is reconnected in the background by the
/// native worker, so the pool recovers without the caller doing
/// anything. [reconnected] reports whether that already succeeded by
/// the time this exception was raised; `false` is not fatal, since the
/// next acquire of that slot retries.
///
/// Taxonomy lives in the core because divergence between drivers would
/// be a defect, not a feature. Added as a
/// class (additive ⇒ MINOR of this package); it does not touch
/// `UnitOfWork` or `Repository`, so it does not grow the conformance
/// battery.
class ConnectionLostException implements Exception {
  /// The statement that was in flight, when one is known.
  final String? sql;

  /// Whether the native worker had already re-established the link for
  /// this pool slot when the failure was surfaced.
  final bool reconnected;

  const ConnectionLostException({this.sql, this.reconnected = false});

  @override
  String toString() {
    final where = sql != null ? ' while executing: $sql' : '';
    final state = reconnected
        ? 'slot reconnected; the lost statement was NOT retried'
        : 'slot not yet reconnected; it will be retried on next acquire';
    return 'ConnectionLostException($state)$where';
  }
}
