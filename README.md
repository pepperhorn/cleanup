<img src="assets/icon.svg" width="64" height="64" alt="">

# Cleanup

Disk housekeeping for the WSL dev box.

## Schedule

| Time  | What | Where |
|-------|------|-------|
| 04:30 | `t3-wt-clean --apply`: remove T3 worktrees that are clean, fully pushed, idle 12h+, not in use | systemd user timer `t3-wt-clean.timer` |
| 05:00 | Docker builder and image prune (older than 48h) and uv cache prune | user crontab |
| 05:30 | `wsl-compact.ps1`: if `ext4.vhdx` is 50 GB+ larger than used space, shut down WSL, compact it with diskpart, restart via the `Start WSL Ubuntu` task | Windows Task Scheduler `WSL Compact` |

## Files

- `bin/t3-wt-clean`: safe, unattended worktree cleanup (dry run unless `--apply`). Installed at `~/.local/bin`.
- `bin/t3-wt-sweep`: interactive, aggressive sweep (auto-commits WIP, backs up `.env*`). Manual only.
- `bin/wsl-slim`: manual Docker/uv prune and `fstrim`.
- `systemd/`: units for `~/.config/systemd/user/`.
- `windows/wsl-compact.ps1`: installed at `%USERPROFILE%\scripts\`. Supports `-DryRun`, `-Force`, `-ThresholdGB N`. Logs to `wsl-compact.log` next to it.
- `windows/register-wsl-compact.ps1`: run once from an Admin PowerShell to register the task.

## Install

```bash
cp bin/* ~/.local/bin/
cp systemd/* ~/.config/systemd/user/ && systemctl --user daemon-reload && systemctl --user enable --now t3-wt-clean.timer
cp windows/*.ps1 /mnt/c/Users/<you>/scripts/
```

Then, in an Admin PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File $env:USERPROFILE\scripts\register-wsl-compact.ps1
```

Logs: `journalctl --user -u t3-wt-clean`, `~/.local/state/docker-prune.log`, `%USERPROFILE%\scripts\wsl-compact.log`.
