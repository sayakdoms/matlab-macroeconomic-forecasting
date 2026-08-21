# Changelog

All notable changes to this project are documented in this file.

## [1.0.0] - Unreleased

First stable reproducible version of the MATLAB macroeconometrics and GDP
growth forecasting project.

### Reproducibility and engineering

- Added `run_all.m` as a configuration-aware entry point for executing all 12
  analysis phases from any MATLAB working directory.
- Added project-root detection, centralized path configuration, safe output
  directory creation, isolated output-root support, and MATLAB path cleanup.
- Converted all analysis phases into independently callable functions with an
  optional shared configuration.
- Added reusable helpers for input validation, lag/design-matrix construction,
  ordinary least squares calculations, and forecast evaluation.
- Preserved committed FRED snapshots as the default data source; live refresh
  remains explicitly opt-in.
- Added figure-free execution for faster analytical reproduction while
  retaining the complete figure-producing workflow.

### Testing

- Added 97 MATLAB unit, integration, alignment, no-leakage, and end-to-end
  parity tests.
- Covered project configuration, output isolation, data validation, lag
  alignment, numerical helpers, independently callable phases, pipeline path
  restoration, output schemas, filenames, and committed headline results.
- Verified the forecast design uses only information from the preceding quarter
  or earlier.

### Continuous integration

- Added GitHub Actions CI on pushes and pull requests to `main` using the
  MathWorks-supported MATLAB setup and command actions with MATLAB R2026a.
- Configured CI to run the authoritative MATLAB test suite from an isolated
  temporary repository copy without refreshing FRED data or overwriting the
  checked-out analytical outputs.

### Documentation and metadata

- Expanded the README with project architecture, one-command reproduction,
  configuration options, testing, dependencies, data provenance, output
  inventory, no-leakage design, limitations, and portfolio context.
- Added `CITATION.cff` with verified author, repository, license, and project
  metadata.
- Retained the existing MIT license.

### Preserved analytical methodology

- Retained the original datasets, transformations, samples, model
  specifications, covariance and p-value conventions, forecast definitions,
  structural-break calculation, benchmarks, filenames, schemas, figures, and
  headline conclusions.
- This release introduces reproducibility and software-engineering improvements;
  it does not introduce new econometric findings or methodological extensions.
