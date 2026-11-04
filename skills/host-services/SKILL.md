---
name: host-services
description: Use when an app or test running in this container needs a service that runs on the user's host machine, such as the Cosmos DB emulator, Azurite (blob, queue, table), a database or a queue, or when a connection to localhost or 127.0.0.1 is refused.
---

# Reaching services on the host

Inside this container `localhost` and `127.0.0.1` are the container itself. The
host machine is `host.docker.internal`. Use it in connection strings,
environment variables and app settings instead of `localhost`.

## Check first

Probe the port from inside the container before changing any code:

```bash
timeout 3 bash -c 'exec 3<>/dev/tcp/host.docker.internal/8081' && echo open || echo closed
```

- Refused straight away: the host is reachable but nothing is listening. Ask the
  user to start the service.
- Timed out: something is blocking the route. Tell the user.

The host's containers must publish their ports (for example `-p 8081:8081`),
otherwise they are not reachable from here.

## Azurite

Plain HTTP. Default ports: blob 10000, queue 10001, table 10002.

```
BlobEndpoint=http://host.docker.internal:10000/devstoreaccount1
QueueEndpoint=http://host.docker.internal:10001/devstoreaccount1
TableEndpoint=http://host.docker.internal:10002/devstoreaccount1
```

Use the usual development account name and key (`devstoreaccount1`). The
shortcut `UseDevelopmentStorage=true` points at `127.0.0.1`, so write the
endpoints out instead.

## Cosmos DB emulator

Port 8081. The emulator the user runs may be the plain-HTTP variant, in which
case use `http://host.docker.internal:8081/`. Probe with
`GET http://host.docker.internal:8081/`: a JSON account document whose
`databaseAccountEndpoint` is `http://host.docker.internal:8081/` means the SDK
will stay on that address. If it answers only over HTTPS with a self-signed
certificate, accept the emulator certificate for development and use Gateway
connection mode.

## Overriding settings without editing files

Prefer environment variables to editing `appsettings*.json` or user secrets,
for example `ConnectionStrings__Cosmos=...`. If user secrets are shared into
the container (`claude-yolo --secrets`), do not read them: they are for the
.NET runtime only.
