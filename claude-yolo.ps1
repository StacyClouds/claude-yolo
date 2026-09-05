#Requires -Version 5.1
<#
Runs the claude-yolo sandbox against the stacyclouds folder tree (Windows/PowerShell port of claude-yolo).

Usage:
  claude-yolo.ps1 [--workspace <path>] [subcommand] [args passed through to claude]

  --workspace <path>   mount <path> as /workspace instead of the script's
                       own parent directory. Must come before the
                       subcommand (if any). No rebuild required - this is
                       a docker run -v argument, resolved fresh each call.
  (no subcommand)      same as "yolo"
  yolo    [args...]    ensure the image exists (building it only if
                       missing), then run claude --dangerously-skip-
                       permissions [args...] (YOLO mode)
  run     [args...]    same image-ensure behavior, then run claude
                       [args...] with normal permission prompts
  rebuild              force a fresh docker build; does not run a
                       container
  nuke [--preserve-token]
                       remove the built image and the claude-yolo-home
                       volume (your persisted Claude login), after
                       confirmation. With --preserve-token, the volume
                       is emptied instead of removed, keeping only
                       ~/.claude/.credentials.json (your OAuth token)
                       so the next run skips the login flow.

Note: after the first build, "run"/"yolo" reuse the existing image and
do NOT rebuild automatically - run "claude-yolo.ps1 rebuild" explicitly
to pick up Dockerfile changes or newer floating package versions (e.g.
.NET SDK patches).

Safe to YOLO because the container has no git binary and can't reach
anything outside the mounted project folder.

Callable from anywhere once its folder is on PATH (see README's Windows
section) - unlike the sh script, this does not follow symlinks to find
the Dockerfile/context; $PSScriptRoot is used directly.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Image = 'claude-yolo'
$Volume = 'claude-yolo-home'
$ScriptDir = $PSScriptRoot
$ProjectDir = (Get-Item (Join-Path $ScriptDir '..')).FullName

function Assert-Success {
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

function Test-SandboxImage {
    docker image inspect $Image *> $null
    return ($LASTEXITCODE -eq 0)
}

function Invoke-SandboxImageBuild {
    docker build -t $Image $ScriptDir
    Assert-Success
}

function Initialize-SandboxImage {
    if (-not (Test-SandboxImage)) {
        Invoke-SandboxImageBuild
    }
}

function Invoke-SandboxContainer {
    param([string[]]$ClaudeArgs)

    # claude-yolo-home persists Claude's login/auth across container runs,
    # separate from the project bind mount so it never lands inside a repo.
    $dockerArgs = @(
        'run', '-it', '--rm',
        '-v', "${ProjectDir}:/workspace",
        '-v', "${Volume}:/home/node"
    )

    if ($script:ClaudeConfigMount) {
        $dockerArgs += $script:ClaudeConfigMount
    }

    if ($env:ANTHROPIC_API_KEY) {
        $dockerArgs += @('-e', 'ANTHROPIC_API_KEY')
    }

    $dockerArgs += $Image
    $dockerArgs += $ClaudeArgs

    docker @dockerArgs
    Assert-Success
}

# --workspace must come before the subcommand: args after the subcommand (or
# after this script itself in the no-args/yolo default) are forwarded
# verbatim to `claude` inside the container, so allowing --workspace there
# too would make it ambiguous which side it was meant for.
$remaining = @($args)

if ($remaining.Count -ge 1 -and $remaining[0] -eq '--workspace') {
    if ($remaining.Count -lt 2) {
        Write-Error "claude-yolo: --workspace requires a path argument"
        exit 1
    }

    $workspacePath = $remaining[1]
    if (-not (Test-Path -LiteralPath $workspacePath -PathType Container)) {
        Write-Error "claude-yolo: --workspace path '$workspacePath' does not exist or is not a directory"
        exit 1
    }

    $ProjectDir = (Resolve-Path -LiteralPath $workspacePath).Path

    if ($remaining.Count -gt 2) {
        $remaining = $remaining[2..($remaining.Count - 1)]
    } else {
        $remaining = @()
    }
}

# Mounted read-only at run time (not baked into the image) so edits to your
# global ~/.claude folder (settings, agents, skills, plugins, commands, etc.)
# take effect on the next run without a rebuild. Skipped entirely if you
# don't have one.
#
# Mounted at .claude-host, NOT directly at .claude: the container's
# entrypoint.sh copies just the config items out of it into the writable
# /home/node/.claude (part of the persisted $Volume) on every start, so
# Claude's login/session state there survives across runs instead of being
# shadowed by this read-only mount. See entrypoint.sh for details.
$ClaudeConfigMount = $null
$hostClaudeDir = Join-Path $HOME '.claude'
if (Test-Path -LiteralPath $hostClaudeDir -PathType Container) {
    $ClaudeConfigMount = "--volume=${hostClaudeDir}:/home/node/.claude-host:ro"
}

$Mode = 'yolo'
$claudeArgs = $remaining
if ($remaining.Count -ge 1 -and $remaining[0] -in @('rebuild', 'nuke', 'run', 'yolo')) {
    $Mode = $remaining[0]
    if ($remaining.Count -gt 1) {
        $claudeArgs = $remaining[1..($remaining.Count - 1)]
    } else {
        $claudeArgs = @()
    }
}

switch ($Mode) {
    'rebuild' {
        Invoke-SandboxImageBuild
    }
    'nuke' {
        $preserveToken = ($claudeArgs.Count -ge 1 -and $claudeArgs[0] -eq '--preserve-token')

        if ($preserveToken) {
            $prompt = "This removes the $Image image and clears the $Volume volume, but keeps your Claude login token (~/.claude/.credentials.json). Continue? [y/N]"
        } else {
            $prompt = "This removes the $Image image and the $Volume volume (your Claude login). Continue? [y/N]"
        }
        $reply = Read-Host -Prompt $prompt

        if ($reply -match '^[yY]([eE][sS])?$') {
            if ($preserveToken) {
                # Gut the volume in place instead of removing it, so the
                # login token survives. Copy .credentials.json out to the
                # helper container's own /tmp (NOT under /home/node, so
                # it isn't wiped by the same command), delete everything
                # else in the volume, then copy the token back in.
                #
                # Needs a container with sh/find/cp/chmod to do the
                # gutting; reuse $Image while it still exists (about to
                # be rmi'd below) rather than pulling something extra.
                # Falls back to busybox if $Image was never built (e.g.
                # nuke called before any run) but the volume somehow
                # exists.
                docker volume inspect $Volume *> $null
                if ($LASTEXITCODE -eq 0) {
                    $helperImage = $Image
                    if (-not (Test-SandboxImage)) {
                        $helperImage = 'busybox'
                    }

                    $innerScript = @'
set -e
SRC=/home/node/.claude/.credentials.json
TMP=/tmp/preserved-credentials.json
[ -f "$SRC" ] && cp "$SRC" "$TMP"
find /home/node -mindepth 1 -maxdepth 1 -exec rm -rf {} +
if [ -f "$TMP" ]; then
    mkdir -p /home/node/.claude
    cp "$TMP" "$SRC"
    chmod 600 "$SRC"
fi
'@
                    docker run --rm -v "${Volume}:/home/node" $helperImage sh -c $innerScript
                    Assert-Success
                }
                docker rmi $Image
            } else {
                docker rmi $Image
                docker volume rm $Volume
            }
        } else {
            Write-Host 'Aborted.'
        }
    }
    'run' {
        Initialize-SandboxImage
        Invoke-SandboxContainer -ClaudeArgs (@('claude') + $claudeArgs)
    }
    default {
        # yolo (explicit or default)
        Initialize-SandboxImage
        Invoke-SandboxContainer -ClaudeArgs (@('claude', '--dangerously-skip-permissions') + $claudeArgs)
    }
}
