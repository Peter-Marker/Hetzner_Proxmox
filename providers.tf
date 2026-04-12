# Terraform configuration block to define required providers
terraform {
  required_providers {
    # Proxmox provider by bpg
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.40"
    }
  }
}

# Proxmox provider configuration
provider "proxmox" {
  insecure  = true # Skip TLS certificate verification
  endpoint  = var.pm_api_url
  api_token = "${var.pm_api_id}=${var.pm_api_secret}"

  # SSH configuration for the Proxmox node
  ssh {
    agent       = false
    username    = "root"
    private_key = file("~/.ssh/id_ed25519")

    node {
      name    = "prox"
      address = var.pm_ip
      port    = var.pm_ssh_port
    }
  }
}
