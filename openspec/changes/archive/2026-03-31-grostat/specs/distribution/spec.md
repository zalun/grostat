## ADDED Requirements

### Requirement: Python package with entry point
The project SHALL be a PEP 621 compliant Python package with `pyproject.toml` defining a console script entry point `grostat` pointing to the Typer CLI app.

#### Scenario: Install and run
- **WHEN** user runs `uv tool install .` from the project directory
- **THEN** `grostat` command SHALL be available in PATH and display help when run without arguments

### Requirement: Homebrew tap
The project SHALL provide a Homebrew formula in a separate repository `zalun/homebrew-grostat` that installs grostat from a GitHub release tarball.

#### Scenario: Homebrew installation
- **WHEN** user runs `brew tap zalun/grostat && brew install grostat`
- **THEN** `grostat` command SHALL be installed and functional

#### Scenario: Homebrew upgrade
- **WHEN** a new version is released and formula updated
- **THEN** `brew upgrade grostat` SHALL install the new version

### Requirement: Development tooling
The project SHALL configure ruff (linter + formatter) and ty (type checker) in `pyproject.toml`.

#### Scenario: Lint check
- **WHEN** developer runs `ruff check src/`
- **THEN** the codebase SHALL pass with zero violations

#### Scenario: Type check
- **WHEN** developer runs `ty check src/`
- **THEN** the codebase SHALL pass with zero type errors
