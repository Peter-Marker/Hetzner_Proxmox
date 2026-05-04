# Hetzner_Proxmox

Infrastructure provisioning project for Hetzner Dedicated Server with Proxmox VE. This project handles the base virtualization layer, VM creation, and network configuration.

## Overview

This project provides automated provisioning of:
- Proxmox VE hypervisor base configuration
- Ubuntu VM template creation from cloud images
- VM deployment with automated networking (NAT, port forwarding, IPv6 routing)
- SSL/TLS certificate management via Let's Encrypt

## Architecture

### Infrastructure Components

1. **Proxmox VE Host**: The base hypervisor running on Hetzner hardware
2. **Ubuntu Template**: Reusable VM template (ID: 8001) created from Ubuntu 24.04 cloud image
3. **AI Ops Center VM**: The main management virtual machine cloned from the template with:
   - 4 CPU cores, 16GB RAM, 50GB disk
   - Internal IP: 10.72.72.10/24
   - IPv6 connectivity via Hetzner routed setup
   - Cloud-init based user configuration
4. **Web Server VM**: Web services virtual machine cloned from the template with:
   - 2 CPU cores, 4GB RAM, 20GB disk
   - Internal IP: 10.72.72.50/24
   - IPv6 connectivity via Hetzner routed setup
   - Cloud-init based user configuration
5. **Nextcloud VM**: Cloud storage virtual machine cloned from the template with:
   - 2 CPU cores, 6GB RAM, 40GB disk
   - Internal IP: 10.72.72.60/24
   - IPv6 connectivity via Hetzner routed setup
   - Cloud-init based user configuration
6. **Work Station VM**: Remote workstation with GUI for browser-based work cloned from the template with:
    - 4 CPU cores, 8GB RAM, 40GB disk
    - Internal IP: 10.72.72.40/24
    - IPv6 connectivity via Hetzner routed setup
    - Cloud-init based user configuration
    - **GUI**: xfce4 + xfce4-goodies desktop environment (LightDM display manager)
    - **Browser**: Google Chrome Stable
    - **Remote Access**: Chrome Remote Desktop (permanent sessions via Google Relay, no inbound ports needed)
    - **Auto-launch**: Two Chrome windows on login — Gemini (`gemini.google.com`) and Deep Research (`gemini.google.com/app/deep-research`)
    - **24/7 session**: Sleep mode, screen lock, and DPMS disabled
    - **Security**: UFW firewall (SSH only from trusted networks), non-root worker user (`VAR_user_worker`) with sudo
    - **Users**: CI user (`TF_VAR_ci_user`) for SSH access (key-only), worker user for GUI/CRD

### Network Configuration

The project implements a dual-stack networking setup:

- **IPv4 NAT**: The Proxmox host performs DNAT (port forwarding) to expose VM services:
  - ai-ops-center (10.72.72.10):
    - `TF_VAR_vm1_ssh_port` → SSH access
    - Port 8000 → Web services (Open WebUI, ai-brain)
    - Port 9000 → Mobile API gateway (ai-gateway)
  - web-server (10.72.72.50):
    - `TF_VAR_vm2_ssh_port` → SSH access
    - Port 80 → HTTP
    - Port 443 → HTTPS
  - nextcloud (10.72.72.60):
    - `TF_VAR_vm3_ssh_port` → SSH access
    - Port 5050 → Nextcloud service
  - work-station (10.72.72.40):
    - `TF_VAR_vm4_ssh_port` → SSH access
    - Chrome Remote Desktop uses outbound HTTPS to Google Relay (no inbound ports required)

- **IPv6 Routing**: Direct routing via Proxy NDP for each VM's public IPv6 address

- **Host Firewall**: Proxmox built-in firewall managed via Ansible (`proxmox_firewall` role) using the Proxmox API:
  - **VM isolation** (blocks VMs from accessing Proxmox host services):
    - TCP `22,8006,3128,85,5900:5999,${TF_VAR_pm_ssh_port}` — DROP from `10.72.72.0/24` (IPv4), `${TF_VAR_pm_ipv6_prefix}` (IPv6 routed), and `fe80::/10` (IPv6 link-local)
  - **Allowed inbound** (both IPv4/IPv6):
    - TCP `22` (SSH) — always open for all. **Note:** Port 22 is fully blocked by the Hetzner Robot external firewall and serves only as a backup/rescue access if the custom SSH port becomes unavailable.
    - TCP `8006,${TF_VAR_pm_ssh_port}` (Web UI + SSH custom port) — merged into single rule, restricted to trusted subnets (`TF_FW_SRC_IP4`, `TF_FW_SRC_IP6`). If subnets are not set, open for all.
    - ICMPv6 (Neighbor Discovery) — open for all
  - **Default policy**: DROP inbound, ACCEPT outbound (via `policy_in: DROP` in cluster firewall options)
  - Rules managed via `community.proxmox.proxmox_firewall` module (visible in Proxmox web UI under **Datacenter → Firewall** and **Node → Firewall**)
  - **Safe enable sequence:**
    1. Pre-flight: validate SSH port matches firewall rules
    2. Configure cluster firewall options (disabled initially)
    3. Install `python3-proxmoxer` library
    4. Configure node firewall rules via API
    5. Pre-flight: verify SSH rules exist before enabling DROP
    6. Enable cluster firewall
    7. Check/enable node firewall via API
    8. Verify SSH connectivity (fail with recovery instructions if lost)
    9. Unmask + enable + start `pve-firewall` systemd service
    10. Verify firewall status
  - **Known issue:** `community.proxmox.proxmox_firewall` module may create duplicate rules on repeated runs due to Proxmox API not honoring `pos` parameter.

## Provisioning Tools

### Terraform (bpg/proxmox provider)

Automates the complete infrastructure lifecycle:

1. Downloads Ubuntu 24.04 cloud image
2. Creates VM template with cloud-init
3. Deploys VMs by cloning the template
4. Configures firewall rules, NAT, and IPv6 routing
5. Generates Ansible inventory file

### Ansible

Configures the Proxmox hypervisor base system:

- **proxmox_base**: Prepares the underlying Proxmox node (repositories, SSH port hardened to key-only, UI tweaks)
- **proxmox_firewall**: Manages Proxmox built-in firewall via API (rules visible in web UI, safe enable sequence)
- **proxmox_fail2ban**: Installs and configures fail2ban for brute-force protection (SSH + Proxmox web UI)
- **proxmox_acme**: Deploys ACME certificate renewal script and configures automatic daily cron job
- **work_station**: Configures the work-station VM (hostname, OS updates, timezone from `TIMEZONE` env var, UFW firewall with SSH port from `TF_VAR_vm4_ssh_port`, non-root worker user from `VAR_user_worker`, xfce4 GUI, Google Chrome, Chrome Remote Desktop, 24/7 session config, Chrome auto-launch for Gemini + Deep Research, LightDM manual login, CI user locked from GUI)

## Quick Start

### Prerequisites

- Proxmox VE installed on Hetzner server
- Terraform installed locally
- Proxmox API token configured
- SSH key pair for VM access

### Deployment

```bash
# Set required environment variables
export TF_VAR_pm_api_id="root@pam!token-name"       # Proxmox API token ID
export TF_VAR_pm_api_secret="your-token-secret"     # Proxmox API token secret
export TF_VAR_pm_api_url="https://host:8006/api2/json"  # Proxmox API URL
export TF_VAR_pm_ssh_port=<your_custom_ssh_port>
export TF_VAR_pm_ipv6_prefix="2a01:4f8:xxx:xxxx::/64"  # Hetzner IPv6 /64 prefix for VM isolation
export TF_FW_SRC_IP4="your.trusted.ipv4/24"   # Optional: restrict ports 8006 and pm_ssh_port
export TF_FW_SRC_IP6="your:trusted:ipv6/48"   # Optional: restrict ports 8006 and pm_ssh_port
export DEDYN_TOKEN=your_desec_token_here

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply infrastructure
terraform apply

# Install required Ansible collections
ansible-galaxy collection install -r requirements.yml

# Configure Proxmox host via Ansible
ansible-playbook site.yml
```

### Configuration

All sensitive variables (API tokens, passwords, SSH keys) should be stored in a `terraform.tfvars` file or passed via environment variables. See `variables.tf` for the complete list of required inputs.

## File Structure

```
Hetzner_Proxmox/
├── main.tf                 # VM and infrastructure resources
├── providers.tf            # Terraform and Proxmox provider config
├── variables.tf            # Input variables
├── cloud-init.tftpl        # VM cloud-init template
├── ansible.cfg             # Ansible configuration
├── site.yml                # Ansible playbook (Proxmox host only)
├── inventory.ini           # Ansible inventory
├── host_vars/
│   └── proxmox_node.yml    # Proxmox node-specific variables (SSH port)
├── roles/
│   ├── proxmox_base/       # Proxmox hypervisor configuration (repos, SSH dual-port, UI)
│   ├── proxmox_firewall/   # Proxmox built-in firewall management via API (rules visible in web UI)
│   │   ├── tasks/main.yml  # Safe sequence: disable → install deps → add rules → enable → verify
│   │   └── handlers/       # Empty (API handles reload automatically)
│   ├── proxmox_fail2ban/   # fail2ban brute-force protection (SSH + Proxmox web UI)
│   │   ├── tasks/main.yml  # Install fail2ban, deploy jail config and custom filter
│   │   ├── handlers/       # Restart fail2ban service
│   │   └── templates/      # jail.local.j2 template
│   ├── proxmox_acme/       # ACME certificate renewal script + cron job + logrotate
│   └── work_station/       # Work-station VM full configuration (GUI, Chrome, CRD, 24/7 session)
│       ├── tasks/main.yml  # Hostname, apt upgrade, timezone, UFW, user, xfce4, Chrome, CRD, power management, autostart
│       └── handlers/       # Restart rsyslog, lightdm, chrome, crd, reload systemd
├── renew_proxmox_cert.sh   # Legacy ACME certificate renewal script (reference)
└── README.md               # This file
```

## SSL Certificate Management

SSL certificates are managed via Let's Encrypt using DNS-01 challenge through deSEC. The `proxmox_acme` Ansible role deploys the renewal script to `/usr/local/bin/renew_proxmox_cert.sh` and configures a daily cron job for automatic renewal. Set the `DEDYN_TOKEN` environment variable before running the playbook. Log rotation for `/var/log/proxmox_cert_renew.log` is configured via logrotate (weekly rotation, 4 rotations kept, compressed).

## Fail2ban Protection

Brute-force protection for SSH and Proxmox web UI is provided by the `proxmox_fail2ban` Ansible role:

| Service | Port | Max Retries | Ban Time | Log Source |
|---------|------|-------------|----------|------------|
| SSH | 22, custom | 3 | 2h | /var/log/auth.log |
| Proxmox web UI | 8006 | 5 | 2h | /var/log/daemon.log |

A custom filter (`/etc/fail2ban/filter.d/proxmox-web.conf`) matches authentication failures from both `pvedaemon` and `pveproxy`.

## Network Troubleshooting

If VMs lose network connectivity:

```bash
# Check IP forwarding on Proxmox
sysctl net.ipv4.ip_forward
sysctl net.ipv6.conf.all.forwarding

# Verify NAT rules
iptables -t nat -L -n

# Check IPv6 proxy NDP
ip -6 neigh show proxy

# Verify bridge configuration
ip addr show vmbr1
```

## Cleaning Up

To destroy all infrastructure:

```bash
terraform destroy
```

**Warning**: This will remove all VMs and networking configuration.

## Chrome Remote Desktop Registration

After deploying the work-station VM, CRD must be registered under the worker user:

```bash
# SSH as worker user
ssh -p $TF_VAR_vm4_ssh_port $VAR_user_worker@$PROXMOX_IP

# Stop CRD service
sudo systemctl stop chrome-remote-desktop

# Remove any existing host tokens
sudo rm -rf ~/.config/chrome-remote-desktop/host*.json

# Start CRD service
sudo systemctl start chrome-remote-desktop

# Run setup to get registration code
chrome-remote-desktop --setup
```

1. Open https://remotedesktop.google.com/headless in your browser
2. Click "Next" to generate a setup code
3. Copy the code and paste it into the terminal
4. Authorize the connection in your browser
5. Set a PIN for remote access

After registration, connecting via CRD will log in as the worker user with XFCE session (no session selection dialog).
