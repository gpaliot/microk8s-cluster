# Trigger action
terraform {
  required_providers {
    proxmox = {
      source = "TheGameProfi/proxmox"
    }
  }
}

provider "proxmox" {
  pm_api_url = var.pm_api_url
  pm_user    = var.pm_user
  pm_password = var.pm_password
  pm_tls_insecure = true
}

variable "pm_api_url" {}
variable "pm_user" {}
variable "pm_password" {}
variable "ssh_public_key" {}
variable "ssh_private_key" {}
variable "vm_template" {
  default = "ubuntu-22.04-template"
}
variable "node_count" {
  default = 2
}
variable "network_bridge" {
  default = "vmbr0"
}

resource "proxmox_vm_qemu" "microk8s_node" {
  count       = var.node_count
  name        = "microk8s-node-${count.index + 1}"
  target_node = "pve"
  clone       = var.vm_template

  cores       = 2
  memory      = 4096
  scsihw      = "virtio-scsi-pci"
  boot        = "cdn"

  network {
    model  = "virtio"
    bridge = var.network_bridge
    firewall = true
  }

  os_type = "cloud-init"
  ciuser  = "ubuntu"
  sshkeys = var.ssh_public_key

  ipconfig0 = "ip=dhcp"

  provisioner "remote-exec" {
    inline = [
      "sudo snap install microk8s --classic",
      "sudo usermod -a -G microk8s ubuntu",
      "sudo chown -f -R ubuntu ~/.kube",
      "sudo ufw allow from 10.0.0.0/8 to any port 16443 proto tcp",
      "sudo ufw enable"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = var.ssh_private_key
      host        = self.ssh_host
    }
  }

  lifecycle {
    ignore_changes = [network]
  }
}

output "node_ips" {
  value = [for vm in proxmox_vm_qemu.microk8s_node : vm.ssh_host]
}
