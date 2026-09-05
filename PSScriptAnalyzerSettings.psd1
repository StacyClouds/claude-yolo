@{
    ExcludeRules = @(
        # claude-yolo.ps1's nuke flow prints a plain "Aborted." line to the
        # console on decline, mirroring the sh script's `echo "Aborted." >&2`.
        # Write-Output/Write-Information would add stream semantics that
        # aren't wanted for a direct, unconditional interactive message.
        'PSAvoidUsingWriteHost'
    )
}
