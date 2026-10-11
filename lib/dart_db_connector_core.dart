/// The vertical contract shared by every `dart_db_connector` driver package.
///
/// This package carries no driver and links no client library. It holds only
/// what every driver must agree on:
///
///   - [UnitOfWork] — the transaction lifecycle, generic in the driver's own
///     executor type. The *shape of the query* is deliberately not part of the
///     contract.
///   - [Repository] — CRUD by primary key, the one interface that generalised
///     cleanly across relational and document stores.
///   - [TransactionStateError], [QueryFailedException], [QueryTimeoutException]
///     — how failure reaches the caller.
///   - [openDriverLibrary] and [assertNativeAbiCompatible] — how a driver
///     package finds its native library and validates its ABI.
///
/// Versioning policy: adding a
/// member to [UnitOfWork] or [Repository] breaks every implementor, so it is a
/// MAJOR of this package and must grow the conformance battery in the same PR.
library;

export 'src/domain/errors.dart'
    show
        ConnectionLostException,
        QueryFailedException,
        QueryTimeoutException,
        TransactionStateError;
export 'src/domain/repository.dart' show Repository;
export 'src/domain/unit_of_work.dart' show UnitOfWork;
export 'src/native/abi_check_protocol.dart' show assertNativeAbiCompatible;
export 'src/native/library_resolver.dart'
    show LibNames, detectPlatformId, libraryFileName, openDriverLibrary;
