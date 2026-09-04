## ADDED Requirements

### Requirement: Host-mounted global config can shadow baked-in opsx tooling
When the host's `~/.claude` folder is mounted into the sandbox (see `sandbox/host-claude-config`), it SHALL take precedence over the build-time baked-in opsx commands and openspec skills at the same path. If the host's `~/.claude` does not itself provide the opsx commands and openspec skills, they SHALL NOT be available inside the sandbox for that run.

#### Scenario: Host ~/.claude mounted without opsx scaffolding
- **WHEN** a host `~/.claude` folder is mounted and does not contain the opsx commands or openspec skills
- **THEN** the opsx commands and openspec skills baked into the image at build time SHALL NOT be available inside the sandbox, since the host mount hides them

#### Scenario: No host ~/.claude mounted
- **WHEN** no host `~/.claude` folder is mounted, or none exists on the host
- **THEN** the build-time baked-in opsx commands and openspec skills SHALL remain available, per the existing requirements in this capability
