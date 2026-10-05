# opencode-local-model-provider Specification

## Purpose

Lets `opencode-yolo` talk to a local OpenAI-compatible model server (e.g. an MLX server) without the user naming a model themselves, by discovering whatever model that server currently has loaded at container start and configuring `opencode` to use it as the default.

## Requirements

### Requirement: The currently-loaded model is discovered automatically at container start
On every `opencode-yolo` container start, the sandbox SHALL query the configured model server's `GET /v1/models` endpoint and SHALL configure `opencode` to use the first model id returned as its default model, without requiring the user to specify a model name.

#### Scenario: Server reports a single loaded model
- **WHEN** an `opencode-yolo` container starts and the model server's `/v1/models` response lists exactly one model id
- **THEN** `opencode` SHALL be configured to use that model id as its default, via a provider pointed at the server's base URL

#### Scenario: User issues a prompt without naming a model
- **WHEN** `opencode-yolo yolo "some prompt"` is invoked and the model server is reachable
- **THEN** opencode SHALL send the prompt to the discovered default model without the user having passed `--model`

### Requirement: Model server location defaults to localhost:8000 and is configurable
The model server SHALL be assumed to be `http://localhost:8000` (reached from inside the container as `http://host.docker.internal:8000`) unless overridden. Setting an `MLX_BASE_URL` environment variable when invoking `opencode-yolo` SHALL change which server is probed and configured as the provider's base URL.

#### Scenario: Default server location
- **WHEN** `opencode-yolo` is invoked with no `MLX_BASE_URL` set
- **THEN** the sandbox SHALL probe and configure `http://host.docker.internal:8000` as the model server

#### Scenario: Overridden server location
- **WHEN** `opencode-yolo` is invoked with `MLX_BASE_URL=http://host.docker.internal:9000` set
- **THEN** the sandbox SHALL probe and configure `http://host.docker.internal:9000` as the model server instead of the default

### Requirement: The container can reach a model server bound to the host's loopback interface
`opencode-yolo` containers SHALL be able to reach a server listening on `localhost`/`127.0.0.1` on the host machine, even though the container's own loopback interface is separate from the host's.

#### Scenario: Host-bound server is reachable
- **WHEN** an OpenAI-compatible server is listening on `127.0.0.1:8000` on the host and an `opencode-yolo` container starts
- **THEN** a request from inside the container to `http://host.docker.internal:8000` SHALL reach that host-bound server

### Requirement: An unreachable model server does not block the sandbox from starting
If the configured model server cannot be reached (or returns no models) at container start, `opencode-yolo` SHALL still start rather than failing outright, and SHALL surface a clear warning identifying the unreachable server so the user can start it and retry.

#### Scenario: Model server not running yet
- **WHEN** an `opencode-yolo` container starts and nothing is listening at the configured model server address
- **THEN** the container SHALL still start and reach a usable `opencode` prompt
- **AND** a warning naming the unreachable server address SHALL be printed
