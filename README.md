# LXC Maintenance & Update Toolkit for Proxmox

A set of scripts to centrally manage, update, and maintain multiple LXC containers from the Proxmox host — with full support for community scripts and Docker containers running inside LXCs.

### Quick Installation

```bash
bash -c "$(wget -qLO - https://github.com/cridan7/lxc_maintenance/raw/refs/heads/main/install.sh)"
```

## Usage – Step-by-Step Guide

All scripts are designed to run from the host and target all LXCs by default.
Optional flags:
`-c CTID1,CTID2 `→ run only on specific containers
`-s CTID1,CTID2 `→ skip specific containers

### Step 1 – Push system upgrade scripts to all LXCs

#### Step 1 – Push system upgrade scripts to all LXCs

```bash
./push-update-scripts-to-lxc.sh
```

→ Places the distribution-specific upgrade script (`upgrade_system_release.sh`) into` /opt/update/ `inside each LXC.

Log: `/opt/scripts/update/log/lxc_system_summary_log`



### Step 2 – Pull current `/bin/update` commands from all LXCs

```bash
./pull-all-lxc-update-commands.sh
```

→ Saves the existing `/bin/update` from every LXC into `/opt/scripts/update/bin/` on the host.

Log: `/opt/scripts/update/log/lxc_pull_log`

### Step 3

No longer required. This step is now handled automatically by Step 2.

### Step 4

```bash
./push-update-command.sh
```

→ Overwrites` /bin/update` inside each LXC and automatically backs up the old version to `/opt/update/backup/` inside the container.

Log: `/opt/scripts/update/log/lxc_push_log`

### Step 5

```bash
./generate-installed_services.sh
```

This script scans all containers and compares running services to `community_services`. It also detects Docker services running inside LXCs.

Notes:

* Scans all containers for running services
* Compares them against community_services (list of known community LXC scripts/addons)
* Detects Docker containers and their services
* Generates installed_services.md (used in the next step)
* The script can detect multiple services running inside the same LXC.

Important: `installed_services.md `must be manually pruned/reviewed. Not all services match 100% automatically (check examples).

### Step 6

```bash
./generate-update-menus.sh
```

Creates a custom `update-menu.sh` for every container based on the pruned `installed_services.md`

Log: `/opt/scripts/update/log/generate_update_menu_log`

### Step 7

```bash
./push-update-menu.sh
```

Will push the auto generated update menus into the LXCs.

Log: `/opt/scripts/update/log/lxc_push_log`

### Step 8

```bash
./push-additional-files.sh
```

Pushes the following modified scripts into `/opt/update/` inside each LXC

- `clean.sh` 
- `fstrim.sh`
- `update_system.sh`
- `update_docker_container.sh`

`clean.sh`, `fstrim.sh`, `update_system.sh` are adapted from the official community repository to run inside the container (not from the host)

* https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/clean-lxcs.sh
* https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/fstrim.sh
* https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/update-lxcs.sh

Log: `/opt/scripts/update/log/lxc_push_log`

### Step 8

Enter the LXC CLI and simply run:

```bash
update
```

or from the host CLI

```bash
pct exec <CTID> update
```

Behavior:

- LXC services using community scripts will fetch their installers and update normally.
- LXCs running Docker services will update containers by pulling the latest image based on the `docker.io` tag.

## Additional Information

Scripts run on all LXCs by default but accept custom filters:

- `-c CTID1,CTID2` run only on specific containers  
- `-s CTID1,CTID2` skip specific containers  

### Notes

- System upgrades are **non-interactiv**e and **non-silent** by design.
- For unprivileged Docker LXCs, add to your `/etc/pve/lxc/<CTID>.conf` file:

```
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
```

- Proxmox 2025 upgrades will break Docker because of AppArmor changes.

## Cleanup (remove all pushed files from LXCs)

```bash
rm-file.sh --all
```

## Custom Flags (available on most scripts)

```textile
-c 100,101,102 # only these containers

-s 200,201 # skip these containers

```

## Credits

Based on the work of the Proxmox VE Community Scripts repository: [GitHub - community-scripts/ProxmoxVE: Proxmox VE Helper-Scripts (Community Edition)](https://github.com/community-scripts/ProxmoxVE)

This toolkit aims to extended and give more control and customization to the original community update mechanism.

Enjoy your customizable LXC updates!
