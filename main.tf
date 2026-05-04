# Download Ubuntu Cloud Image to Proxmox local datastore
resource "proxmox_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "prox"
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

# Generate cloud-init configuration from template
resource "proxmox_virtual_environment_file" "cloud_config_ai_ops" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "prox"
  source_raw {
    data = templatefile("${path.module}/cloud-init.tftpl", {
      ssh_user     = var.ci_user
      ssh_password = var.ci_password
      ssh_key      = var.ci_ssh_key
      ssh_port     = var.vm1_ssh_port
    })
    file_name = "cloud-config-ai-ops.yaml"
  }
}

# Generate cloud-init configuration for web-server
resource "proxmox_virtual_environment_file" "cloud_config_web_server" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "prox"
  source_raw {
    data = templatefile("${path.module}/cloud-init.tftpl", {
      ssh_user     = var.ci_user
      ssh_password = var.ci_password
      ssh_key      = var.ci_ssh_key
      ssh_port     = var.vm2_ssh_port
    })
    file_name = "cloud-config-web-server.yaml"
  }
}

# Generate cloud-init configuration for nextcloud
resource "proxmox_virtual_environment_file" "cloud_config_nextcloud" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "prox"
  source_raw {
    data = templatefile("${path.module}/cloud-init.tftpl", {
      ssh_user     = var.ci_user
      ssh_password = var.ci_password
      ssh_key      = var.ci_ssh_key
      ssh_port     = var.vm3_ssh_port
    })
    file_name = "cloud-config-nextcloud.yaml"
  }
}

# Generate cloud-init configuration for work-station
resource "proxmox_virtual_environment_file" "cloud_config_work_station" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "prox"
  source_raw {
    data = templatefile("${path.module}/cloud-init.tftpl", {
      ssh_user     = var.ci_user
      ssh_password = var.ci_password
      ssh_key      = var.ci_ssh_key
      ssh_port     = var.vm4_ssh_port
    })
    file_name = "cloud-config-work-station.yaml"
  }
}

# Create a VM template from the downloaded cloud image
resource "proxmox_virtual_environment_vm" "ubuntu_template_8001" {
  name          = "ubuntu-2404-template"
  node_name     = "prox"
  vm_id         = 8001
  template      = true
  scsi_hardware = "virtio-scsi-single"
  machine       = "q35"
  agent {
    enabled = true
  }
  initialization {
    datastore_id = "local-zfs"
    interface    = "ide2"
  }
  cpu {
    cores = 1
    type  = "host"
  }
  memory {
    dedicated = 2048
  }
  disk {
    datastore_id = "local-zfs"
    interface    = "scsi0"
    file_id      = proxmox_download_file.ubuntu_cloud_image.id
    iothread     = true
    discard      = "on"
    file_format  = "raw"
    size         = 5
  }
  network_device {
    bridge = "vmbr1"
  }
  lifecycle {
    # Suppress spurious changes from the Proxmox provider for computed attributes
    ignore_changes = [ipv4_addresses, ipv6_addresses, network_interface_names]
  }
}

# Deploy the main VM by cloning the template
resource "proxmox_virtual_environment_vm" "ai_ops_center" {
  name      = "ai-ops-center"
  node_name = "prox"
  cpu {
    cores = 4
    type  = "host"
    units = 1000
  }
  memory {
    dedicated = 16384
  }
  agent {
    enabled = true
  }
  clone {
    vm_id = 8001
    full  = true
  }
  disk {
    datastore_id = "local-zfs"
    interface    = "scsi0"
    size         = 50
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }
  network_device {
    bridge = "vmbr1"
  }
  initialization {
    datastore_id = "local-zfs"
    interface    = "ide2"
    ip_config {
      ipv4 {
        address = "10.72.72.10/24"
        gateway = "10.72.72.1"
      }
      ipv6 {
        address = "${var.vm1_ipv6}/128"
        gateway = "fe80::1"
      }
    }
    user_data_file_id = proxmox_virtual_environment_file.cloud_config_ai_ops.id
  }
  depends_on = [proxmox_virtual_environment_vm.ubuntu_template_8001]
}

# Deploy the web-server VM by cloning the template
resource "proxmox_virtual_environment_vm" "web_server" {
  name      = "web-server"
  node_name = "prox"
  cpu {
    cores = 2
    type  = "host"
  }
  memory {
    dedicated = 4096
  }
  agent {
    enabled = true
  }
  clone {
    vm_id = 8001
    full  = true
  }
  disk {
    datastore_id = "local-zfs"
    interface    = "scsi0"
    size         = 20
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }
  network_device {
    bridge = "vmbr1"
  }
  initialization {
    datastore_id = "local-zfs"
    interface    = "ide2"
    ip_config {
      ipv4 {
        address = "10.72.72.50/24"
        gateway = "10.72.72.1"
      }
      ipv6 {
        address = "${var.vm2_ipv6}/128"
        gateway = "fe80::1"
      }
    }
    user_data_file_id = proxmox_virtual_environment_file.cloud_config_web_server.id
  }
  depends_on = [proxmox_virtual_environment_vm.ubuntu_template_8001]
}

# Deploy the nextcloud VM by cloning the template
resource "proxmox_virtual_environment_vm" "nextcloud" {
  name      = "nextcloud"
  node_name = "prox"
  cpu {
    cores = 2
    type  = "host"
  }
  memory {
    dedicated = 6144
  }
  agent {
    enabled = true
  }
  clone {
    vm_id = 8001
    full  = true
  }
  disk {
    datastore_id = "local-zfs"
    interface    = "scsi0"
    size         = 40
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }
  network_device {
    bridge = "vmbr1"
  }
  initialization {
    datastore_id = "local-zfs"
    interface    = "ide2"
    ip_config {
      ipv4 {
        address = "10.72.72.60/24"
        gateway = "10.72.72.1"
      }
      ipv6 {
        address = "${var.vm3_ipv6}/128"
        gateway = "fe80::1"
      }
    }
    user_data_file_id = proxmox_virtual_environment_file.cloud_config_nextcloud.id
  }
  depends_on = [proxmox_virtual_environment_vm.ubuntu_template_8001]
}

# Deploy the work-station VM by cloning the template
resource "proxmox_virtual_environment_vm" "work_station" {
  name      = "work-station"
  node_name = "prox"
  cpu {
    cores = 4
    type  = "host"
  }
  memory {
    dedicated = 8192
  }
  agent {
    enabled = true
  }
  clone {
    vm_id = 8001
    full  = true
  }
  disk {
    datastore_id = "local-zfs"
    interface    = "scsi0"
    size         = 40
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }
  network_device {
    bridge = "vmbr1"
  }
  initialization {
    datastore_id = "local-zfs"
    interface    = "ide2"
    ip_config {
      ipv4 {
        address = "10.72.72.40/24"
        gateway = "10.72.72.1"
      }
      ipv6 {
        address = "${var.vm4_ipv6}/128"
        gateway = "fe80::1"
      }
    }
    user_data_file_id = proxmox_virtual_environment_file.cloud_config_work_station.id
  }
  depends_on = [proxmox_virtual_environment_vm.ubuntu_template_8001]
}

# Configure networking on the Proxmox host (NAT, Port Forwarding, IPv6 Routing)
resource "null_resource" "network_setup" {
  triggers = {
    pm_ip       = var.pm_ip
    pm_ssh_port = var.pm_ssh_port
    vm_ip       = "10.72.72.10"
    vm_ipv6     = var.vm1_ipv6
    port        = var.vm1_ssh_port

    # VM2 (web-server) triggers
    vm2_ip       = "10.72.72.50"
    vm2_ipv6     = var.vm2_ipv6
    vm2_ssh_port = var.vm2_ssh_port
    pm_ip_var    = var.pm_ip

    # VM3 (nextcloud) triggers
    vm3_ip       = "10.72.72.60"
    vm3_ipv6     = var.vm3_ipv6
    vm3_ssh_port = var.vm3_ssh_port

    # VM4 (work-station) triggers
    vm4_ip       = "10.72.72.40"
    vm4_ipv6     = var.vm4_ipv6
    vm4_ssh_port = var.vm4_ssh_port

    # Migration trigger - forces re-run of provisioner with all VM rules
    migration_v2 = "2026-05-04-fix-idempotent"

    # Terraform will re-run the provisioner if the hash of this string changes
    script_hash = sha1(join("", [
      "iptables -t nat -A PREROUTING -d ${var.pm_ip}/32 -p tcp --dport ${var.vm1_ssh_port} -j DNAT --to-destination 10.72.72.10:${var.vm1_ssh_port}",
      "iptables -t nat -A PREROUTING -d ${var.pm_ip}/32 -p tcp --dport 8000 -j DNAT --to-destination 10.72.72.10:8000",
      "iptables -t nat -A PREROUTING -d ${var.pm_ip}/32 -p tcp --dport 9000 -j DNAT --to-destination 10.72.72.10:9000",
      "iptables -t nat -A PREROUTING -d ${var.pm_ip}/32 -p tcp --dport ${var.vm2_ssh_port} -j DNAT --to-destination 10.72.72.50:${var.vm2_ssh_port}",
      "iptables -t nat -A PREROUTING -d ${var.pm_ip}/32 -p tcp --dport 80 -j DNAT --to-destination 10.72.72.50:80",
      "iptables -t nat -A PREROUTING -d ${var.pm_ip}/32 -p tcp --dport 443 -j DNAT --to-destination 10.72.72.50:443",
      "iptables -t nat -A PREROUTING -d ${var.pm_ip}/32 -p tcp --dport ${var.vm3_ssh_port} -j DNAT --to-destination 10.72.72.60:${var.vm3_ssh_port}",
      "iptables -t nat -A PREROUTING -d ${var.pm_ip}/32 -p tcp --dport 5050 -j DNAT --to-destination 10.72.72.60:5050",
      "iptables -t nat -A PREROUTING -d ${var.pm_ip}/32 -p tcp --dport ${var.vm4_ssh_port} -j DNAT --to-destination 10.72.72.40:${var.vm4_ssh_port}",
      # Add future ports here to keep them tracked
    ]))
  }
  connection {
    type        = "ssh"
    user        = "root"
    host        = self.triggers.pm_ip
    port        = self.triggers.pm_ssh_port
    private_key = file("~/.ssh/id_ed25519")
  }
  # Port forwarding (DNAT) and IPv6 setup via remote-exec
  provisioner "remote-exec" {
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",
      # Install persistent storage for iptables rules
      "apt update && apt install -y iptables-persistent",
      # Enable IP forwarding for both IPv4 and IPv6
      "sysctl -w net.ipv4.ip_forward=1",
      "sysctl -w net.ipv6.conf.all.forwarding=1",
      "sysctl -w net.ipv6.conf.default.forwarding=1",
      "sysctl -w net.ipv6.conf.vmbr1.forwarding=1",
      "sysctl -w net.ipv6.conf.all.proxy_ndp=1",
      "sysctl -w net.ipv6.conf.vmbr0.proxy_ndp=1",
      # Configure Link-Local gateway for the internal bridge
      "ip -6 addr replace fe80::1/64 dev vmbr1",
      # IPv4 NAT: Port forwarding and Masquerade for internet access
      "iptables -t nat -F PREROUTING",
      "iptables -t nat -A PREROUTING -d ${self.triggers.pm_ip}/32 -p tcp --dport ${self.triggers.port} -j DNAT --to-destination ${self.triggers.vm_ip}:${self.triggers.port}",
      "iptables -t nat -A PREROUTING -d ${self.triggers.pm_ip}/32 -p tcp --dport 8000 -j DNAT --to-destination ${self.triggers.vm_ip}:8000",
      "iptables -t nat -A PREROUTING -d ${self.triggers.pm_ip}/32 -p tcp --dport 9000 -j DNAT --to-destination ${self.triggers.vm_ip}:9000",
      # VM2 (web-server) port forwarding
      "iptables -t nat -A PREROUTING -d ${self.triggers.pm_ip}/32 -p tcp --dport ${self.triggers.vm2_ssh_port} -j DNAT --to-destination ${self.triggers.vm2_ip}:${self.triggers.vm2_ssh_port}",
      "iptables -t nat -A PREROUTING -d ${self.triggers.pm_ip}/32 -p tcp --dport 80 -j DNAT --to-destination ${self.triggers.vm2_ip}:80",
      "iptables -t nat -A PREROUTING -d ${self.triggers.pm_ip}/32 -p tcp --dport 443 -j DNAT --to-destination ${self.triggers.vm2_ip}:443",
      # VM3 (nextcloud) port forwarding
      "iptables -t nat -A PREROUTING -d ${self.triggers.pm_ip}/32 -p tcp --dport ${self.triggers.vm3_ssh_port} -j DNAT --to-destination ${self.triggers.vm3_ip}:${self.triggers.vm3_ssh_port}",
      "iptables -t nat -A PREROUTING -d ${self.triggers.pm_ip}/32 -p tcp --dport 5050 -j DNAT --to-destination ${self.triggers.vm3_ip}:5050",
      # VM4 (work-station) port forwarding
      "iptables -t nat -A PREROUTING -d ${self.triggers.pm_ip}/32 -p tcp --dport ${self.triggers.vm4_ssh_port} -j DNAT --to-destination ${self.triggers.vm4_ip}:${self.triggers.vm4_ssh_port}",
      # MASQUERADE: delete existing then add (idempotent)
      "iptables -t nat -D POSTROUTING -s 10.72.72.0/24 -o vmbr0 -j MASQUERADE 2>/dev/null || true",
      "iptables -t nat -A POSTROUTING -s 10.72.72.0/24 -o vmbr0 -j MASQUERADE",
      # IPv6 Routing & Proxy NDP: Crucial for Hetzner routed setup
      "ip6tables -D FORWARD -j ACCEPT 2>/dev/null || true",
      "ip6tables -A FORWARD -j ACCEPT",
      "ip -6 neigh replace proxy ${self.triggers.vm_ipv6} dev vmbr0",
      "ip -6 route replace ${self.triggers.vm_ipv6}/128 dev vmbr1",
      "ip -6 neigh replace proxy ${self.triggers.vm2_ipv6} dev vmbr0",
      "ip -6 route replace ${self.triggers.vm2_ipv6}/128 dev vmbr1",
      "ip -6 neigh replace proxy ${self.triggers.vm3_ipv6} dev vmbr0",
      "ip -6 route replace ${self.triggers.vm3_ipv6}/128 dev vmbr1",
      # VM4 (work-station) IPv6 routing
      "ip -6 neigh replace proxy ${self.triggers.vm4_ipv6} dev vmbr0",
      "ip -6 route replace ${self.triggers.vm4_ipv6}/128 dev vmbr1",
      # Make rules persistent across reboots
      "netfilter-persistent save"
    ]
  }
  # Cleanup networking rules on resource destruction
  # NOTE: Only VM1 rules are cleaned up here due to Terraform's limitation on
  # destroy-time provisioner references. VM2/VM3/VM4 rules are cleaned up on
  # next full destroy/recreate cycle.
  provisioner "remote-exec" {
    when = destroy
    inline = [
      "iptables -t nat -D PREROUTING -d ${self.triggers.pm_ip}/32 -p tcp --dport ${self.triggers.port} -j DNAT --to-destination ${self.triggers.vm_ip}:${self.triggers.port} || true",
      "iptables -t nat -D PREROUTING -d ${self.triggers.pm_ip}/32 -p tcp --dport 8000 -j DNAT --to-destination ${self.triggers.vm_ip}:8000 || true",
      "iptables -t nat -D PREROUTING -d ${self.triggers.pm_ip}/32 -p tcp --dport 9000 -j DNAT --to-destination ${self.triggers.vm_ip}:9000 || true",
      "ip -6 neigh del proxy ${self.triggers.vm_ipv6} dev vmbr0 || true"
    ]
    on_failure = continue
  }
}

# Generate Ansible inventory file
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/inventory.ini"

  content = <<-EOT
    [proxmox]
    # The hypervisor node
    proxmox_node ansible_host=${var.pm_ip} ansible_port=${var.pm_ssh_port} ansible_user=root

    [ai_ops]
    # The managed VM
    ai-ops-center ansible_host=${var.pm_ip} ansible_port=${var.vm1_ssh_port} ansible_user=${var.ci_user}

    [web_server]
    # The web server VM
    web-server ansible_host=${var.pm_ip} ansible_port=${var.vm2_ssh_port} ansible_user=${var.ci_user}

    [nextcloud_vms]
    # The nextcloud VM
    nextcloud ansible_host=${var.pm_ip} ansible_port=${var.vm3_ssh_port} ansible_user=${var.ci_user}

    [work_station]
    # The work-station VM
    work-station ansible_host=${var.pm_ip} ansible_port=${var.vm4_ssh_port} ansible_user=${var.ci_user}

    [work_station:vars]
    # Worker user for the work-station VM
    worker_user=${var.user_worker}

    [all:vars]
    # Global settings: skip SSH key confirmation for new automated nodes
    ansible_ssh_common_args='-o StrictHostKeyChecking=no'
    ansible_python_interpreter=/usr/bin/python3
  EOT
}

# NOTE: Proxmox firewall configuration is handled by Ansible (proxmox_firewall role)
# after terraform apply. See site.yml for the Ansible workflow.
