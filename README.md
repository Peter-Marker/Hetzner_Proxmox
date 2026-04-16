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

- **IPv6 Routing**: Direct routing via Proxy NDP for each VM's public IPv6 address

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

- **proxmox_base**: Prepares the underlying Proxmox node (repositories, SSH port, UI tweaks)
- **proxmox_acme**: Deploys ACME certificate renewal script and configures automatic daily cron job

## Quick Start

### Prerequisites

- Proxmox VE installed on Hetzner server
- Terraform installed locally
- Proxmox API token configured
- SSH key pair for VM access

### Deployment

```bash
# Set required environment variables
export TF_VAR_pm_ssh_port=43030
export DEDYN_TOKEN=your_desec_token_here

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply infrastructure
terraform apply

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
│   ├── proxmox_base/       # Proxmox hypervisor configuration (repos, SSH, UI)
│   └── proxmox_acme/       # ACME certificate renewal script + cron job
├── renew_proxmox_cert.sh   # Legacy ACME certificate renewal script (reference)
└── README.md               # This file
```

## SSL Certificate Management

SSL certificates are managed via Let's Encrypt using DNS-01 challenge through deSEC. The `proxmox_acme` Ansible role deploys the renewal script to `/usr/local/bin/renew_proxmox_cert.sh` and configures a daily cron job for automatic renewal. Set the `DEDYN_TOKEN` environment variable before running the playbook.

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
