# Instructions for `install/`

## Purpose and execution order

This directory is the reinstall pipeline for Arch Linux + Niri:

1. `.archinstall`: live-environment base installation, partition selection, filesystems, pacstrap, user setup, networking, and initial GRUB installation.
2. `.installdriver`: post-install hardware and system configuration, including packages, services, GRUB, Secure Boot, NVIDIA, initramfs, and Windows/NTFS integration.
3. `.installconfigtheme`: dotfile, theme, Quickshell, environment, workspace, and optional feature installation.

Treat these files as one pipeline. Check assumptions passed from one stage to the next.

## Shell editing rules

- Preserve the declared interpreter and Bash-specific behavior.
- Read the entire affected function and all call sites before changing it.
- Prefer small changes over reorganizing the whole script.
- Quote variable expansions unless splitting or globbing is intentional.
- Use arrays for package lists and multi-argument commands when practical.
- Keep package installation idempotent with `--needed` where the existing design supports it.
- Avoid duplicate lines in `fstab`, locale files, GRUB defaults, shell startup files, and other persistent configuration.
- Do not add `set -e`, `set -u`, or `pipefail` blindly; first check traps, optional commands, conditionals, pipelines, and commands intentionally allowed to fail.
- Preserve interactive confirmations around disk, partition, boot, Secure Boot, and destructive operations.
- Do not remove a safety check merely to make a command shorter.

## Pipeline consistency

For changes involving packages, paths, services, repositories, or themes:

- identify which stage owns the action;
- avoid installing or configuring the same thing in multiple stages without a documented reason;
- verify reboot boundaries do not skip required steps;
- verify `dotf/` and `quickshell/` paths still match the local workspace layout;
- check dual-boot, GRUB, Secure Boot, NVIDIA, initramfs, Niri, display manager, and Windows mount implications when relevant.

## Execution safety

Never execute the following merely to test an edit:

- `.archinstall`, `.installdriver`, or `.installconfigtheme --all`;
- `cfdisk`, `fdisk`, `parted`, `mkfs*`, `mkswap`, `swapon`, `mount`, `umount`, or `dd`;
- `grub-install`, `grub-mkconfig`, `mkinitcpio -P`, `sbctl enroll-keys`, or signing commands;
- commands that edit `/etc`, `/usr`, `/boot`, firmware, partitions, or the active package database;
- `reboot`, `poweroff`, or service enable/disable commands.

The scripts may contain these commands and may be edited when requested. Editing permission is not execution permission.

## Safe validation

After editing Bash scripts, prefer:

```bash
bash -n .archinstall
bash -n .installdriver
bash -n .installconfigtheme
```

Run `shellcheck` only when installed, and explain intentional suppressions instead of hiding warnings broadly.

`INSTALLER_DRY_RUN=1` is not a universal sandbox. Only use a documented narrow mode after verifying that every invoked function honors dry-run behavior. Never assume `--dots`, `--env`, `--grub`, `--sddm`, `--waylandflag`, or `--all` is non-mutating.

## Review output

For installer reviews, prioritize findings as:

1. Data-loss, boot, or lockout risk.
2. Commands targeting the wrong disk, partition, path, user, or device.
3. Broken stage ordering or reboot boundaries.
4. Non-idempotent behavior and duplicate persistent entries.
5. Package, service, NVIDIA, Secure Boot, GRUB, or Niri compatibility issues.
6. Maintainability improvements that do not change behavior.
