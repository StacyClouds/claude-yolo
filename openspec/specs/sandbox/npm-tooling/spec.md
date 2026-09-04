# npm-tooling Specification

## Purpose

Makes `npm` usable by the unprivileged `node` user the sandbox runs as, including global package installs, rather than only working during the root-run build steps.

## Requirements

### Requirement: npm global install directory is writable by the sandbox user
The sandbox SHALL ensure npm's global package install location is writable by the `node` user, so `npm install -g` succeeds without a permission-denied or read-only-filesystem error.

#### Scenario: Global install as the node user
- **WHEN** `npm install -g <package>` is run inside the container as the `node` user
- **THEN** the install SHALL succeed without a permission-denied or read-only-filesystem error

### Requirement: npm cache directory is writable by the sandbox user
The sandbox SHALL ensure npm's cache directory is writable by the `node` user.

#### Scenario: npm cache write during install
- **WHEN** npm writes to its cache directory during an install run as the `node` user
- **THEN** the write SHALL succeed without a permission-denied or read-only-filesystem error
