# Proxmox connection details
variable "pm_ip" {
  description = "Proxmox IP address"
  type        = string
}

variable "pm_ipv6" {
  description = "Proxmox IPv6 address"
  type        = string
}

# Proxmox API credentials
variable "pm_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "pm_api_id" {
  description = "Proxmox API Token ID"
  type        = string
}

variable "pm_api_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  sensitive   = true
}

# Cloud-init configuration for VMs
variable "ci_user" {
  description = "Cloud-init username"
  type        = string
}

variable "ci_password" {
  description = "Cloud-init password"
  type        = string
  sensitive   = true
}

variable "ci_ssh_key" {
  description = "Cloud-init SSH public key"
  type        = string
}

# SSH configuration
variable "pm_ssh_port" {
  description = "Proxmox SSH port"
  type        = number
}

# VM1 specific settings
variable "vm1_ipv6" {
  description = "IPv6 address for ai_ops_center"
  type        = string
}

variable "vm1_ssh_port" {
  description = "SSH port for VM ai_ops_center"
  type        = number
}

# VM2 specific settings
variable "vm2_ipv6" {
  description = "IPv6 address for web-server"
  type        = string
}

variable "vm2_ssh_port" {
  description = "SSH port for VM web-server"
  type        = number
}

# Firewall trusted source networks (for Proxmox web UI and custom SSH port)
variable "fw_src_ip4" {
  description = "Trusted IPv4 networks for restricted ports (comma-separated or CIDR)"
  type        = string
  default     = ""
}

variable "fw_src_ip6" {
  description = "Trusted IPv6 networks for restricted ports (comma-separated or CIDR)"
  type        = string
  default     = ""
}
