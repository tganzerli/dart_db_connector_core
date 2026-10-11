# dart_db_connector_core

The contract shared by every `dart_db_connector` driver package. It carries no driver and links no client
library; it holds only what every driver must agree on:

- `UnitOfWork<E>`: the transaction lifecycle, generic in the driver's own executor type. The shape of a query is
  deliberately not part of the contract.
- `Repository<T, K>`: CRUD by primary key.
- `TransactionStateError`, `QueryFailedException`, `QueryTimeoutException`, `ConnectionLostException`: how
  failure reaches the caller.
- `openDriverLibrary` and `assertNativeAbiCompatible`: how a driver finds its native library and validates its
  ABI.

Applications normally do not depend on this package directly; they get it through a driver such as
[`dart_db_connector_postgres`](https://github.com/tganzerli/dart_db_connector_postgres).

**Experimental, not on pub.dev yet.** Drivers depend on it by `git` reference to a tag:

```yaml
dependencies:
  dart_db_connector_core:
    git:
      url: https://github.com/tganzerli/dart_db_connector_core
      ref: v1.0.0
```

## Versioning

Adding a member to `UnitOfWork` or `Repository` breaks every implementor, so it is a MAJOR release of this
package and must extend the conformance battery in the same change. A new error class, or a new optional field
on an existing one, is a MINOR release.

## Conformance battery

`conformance/` holds `dart_db_connector_conformance`, the executable half of the contract: each driver imports it
as a `dev_dependency` from the same tag and runs `runUnitOfWorkConformance` against its own database. It is not
meant to be published.

## License

MIT, see `LICENSE`.
