/// The conformance battery every driver runs against its own database.
///
/// The contract declares the states ([UnitOfWork]); this battery checks that a
/// driver honours the transitions between them. Import it as a
/// `dev_dependency` and call [runUnitOfWorkConformance] with an `open` callback
/// that yields a fresh unit of work.
library;

export 'src/unit_of_work_conformance.dart' show runUnitOfWorkConformance;
