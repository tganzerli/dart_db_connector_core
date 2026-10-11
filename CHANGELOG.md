# Changelog

## 1.0.1

Packaging only; the contract is unchanged. The conformance battery in `conformance/` now depends on this
package by the same `git` url and tag that drivers use, so a driver can depend on both. With 1.0.0 the battery
referenced the core by relative path, which pub resolves as a different source and refuses.

## 1.0.0

First public release, consumed by `git` reference to the tag `v1.0.0`.

- Contract: `UnitOfWork<E>`, `Repository<T, K>`.
- Errors: `TransactionStateError`, `QueryFailedException`, `QueryTimeoutException`, `ConnectionLostException`.
- Native library resolution (`openDriverLibrary`, `LibNames`, `libraryFileName`, `detectPlatformId`) and the
  shared ABI check (`assertNativeAbiCompatible`).
- Conformance battery in `conformance/` (`runUnitOfWorkConformance`), versioned with this tag.
