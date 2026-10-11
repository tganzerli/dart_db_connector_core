# Changelog

## 1.0.0

First public release, consumed by `git` reference to the tag `v1.0.0`.

- Contract: `UnitOfWork<E>`, `Repository<T, K>`.
- Errors: `TransactionStateError`, `QueryFailedException`, `QueryTimeoutException`, `ConnectionLostException`.
- Native library resolution (`openDriverLibrary`, `LibNames`, `libraryFileName`, `detectPlatformId`) and the
  shared ABI check (`assertNativeAbiCompatible`).
- Conformance battery in `conformance/` (`runUnitOfWorkConformance`), versioned with this tag.
