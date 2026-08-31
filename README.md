# Scripts Toolkit

[![Shell](https://img.shields.io/badge/shell-Bash-121011?logo=gnubash&logoColor=white)](toolkit.sh)
[![Linux](https://img.shields.io/badge/platform-Linux-fcc624?logo=linux&logoColor=black)](https://kernel.org/)
[![License](https://img.shields.io/badge/license-MIT-22c55e)](LICENSE)

An interactive Bash toolkit for Linux configuration backups, restoration, and setup of a local security-research toolchain.

> **Read the script before execution.** Options use `sudo`, install packages, change files under `$HOME` and `/etc`, and may overwrite the toolkit's previous backup archive. Run security tools only against systems you own or are explicitly authorized to test.

## Features

- Creates a compressed archive of selected shell and system configuration paths
- Restores supported paths from the toolkit archive
- Detects Arch-based, Debian/Ubuntu-based, and RHEL-based distributions
- Installs development prerequisites and an optional Go toolchain
- Sets up selected Go, Python, and Git-based security-research utilities
- Optionally installs Zsh and Oh My Zsh

## Requirements

- Linux distribution supported by the script: Arch, Debian/Ubuntu, or RHEL-compatible
- Bash
- Internet access for package and source downloads
- `sudo` access
- Sufficient disk space for packages, repositories, and the backup archive

## Run

Clone the repository, inspect the script, then make it executable:

```bash
git clone https://github.com/siimsek/Scripts.git
cd Scripts
less toolkit.sh
chmod +x toolkit.sh
./toolkit.sh
```

Choose one of the interactive menu options:

1. **Backup** — creates `$HOME/config_backup.tar.gz`.
2. **Restore** — restores paths from that archive.
3. **Install tools** — updates the package manager, downloads dependencies, and installs selected tools.

## Backup scope

The script targets selected user shell files and directories plus `/etc` and `/var`, while excluding volatile, cache, log, and package-cache paths. The exact lists are defined at the top of `toolkit.sh`:

```bash
CONFIG_ITEMS=(...)
EXCLUDE_ITEMS=(...)
```

Before using backup or restore, adapt these arrays to your machine. Do not use the restore option as a system migration solution without independently verified backups.

## Tool installation

The installer fetches software from operating-system repositories, PyPI, Go module sources, and Git repositories. Versions can change upstream, and some installed utilities are intended for active security testing.

Use the installation option only in a disposable lab or a machine you administer. Confirm each project's license, maintenance state, and documented usage before using it.

## Project structure

```text
.
└── toolkit.sh  # Interactive backup, restore, and installation script
```

## License

Licensed under the [MIT License](LICENSE). Third-party tools installed by this script remain subject to their own licenses.
