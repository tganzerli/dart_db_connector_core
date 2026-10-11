# dart_db_connector_conformance

The conformance battery for the `dart_db_connector` contract. The contract (`UnitOfWork`) declares the states; this
battery checks that a driver honours the transitions between them.

A driver imports it as a `dev_dependency`, from the same tag of the core repository it implements:

```yaml
dev_dependencies:
  dart_db_connector_conformance:
    git:
      url: https://github.com/tganzerli/dart_db_connector_core
      ref: v1.0.0
      path: conformance
```

and calls `runUnitOfWorkConformance` with an `open` callback that yields a fresh unit of work on its own
database. Not meant to be published.

## License

MIT, see `LICENSE`.
