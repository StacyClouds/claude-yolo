## ADDED Requirements

### Requirement: A default status line is available in every container
The sandbox SHALL provide a status line to Claude Code inside the container on every start, whether or not the host has a `~/.claude` folder. The container's status line SHALL always be the sandbox's own: a status line script from the host's `~/.claude`, and a `statusLine` setting from the host's `settings.json`, SHALL NOT be used, because they typically reference host-only paths. (A user-facing override is deferred to a later change.) The default SHALL be part of the built image and SHALL NOT depend on the host.

#### Scenario: Host provides neither script nor setting
- **WHEN** a container starts and the host has no `statusline-command.sh` and no `statusLine` entry in its `settings.json`
- **THEN** `statusline-command.sh` SHALL exist in the container's global configuration path
- **AND** the container's `settings.json` SHALL define `statusLine` as a command that runs that script

#### Scenario: No host ~/.claude folder
- **WHEN** a container starts and the host has no `~/.claude` folder
- **THEN** the default status line script and `statusLine` setting SHALL still be present

#### Scenario: Host provides its own script
- **WHEN** a container starts and the host's `~/.claude` contains `statusline-command.sh`
- **THEN** the container SHALL use the baked default script, not the host's copy

#### Scenario: Host provides its own statusLine setting
- **WHEN** a container starts and the host's `settings.json` defines `statusLine`
- **THEN** the container's `settings.json` SHALL define `statusLine` as the command that runs the baked script, replacing the host's value

#### Scenario: Host provides a script but no statusLine setting
- **WHEN** a container starts and the host has `statusline-command.sh` but its `settings.json` has no `statusLine` entry
- **THEN** the container's `settings.json` SHALL define `statusLine` as a command that runs the baked script

#### Scenario: Repeated starts
- **WHEN** a container starts more than once on the same `claude-yolo-home` volume
- **THEN** the `statusLine` setting SHALL be defined exactly once, with the same value each time
