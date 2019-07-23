variable "subscription_id" {
  type = string
  description = "The ID of the subscription in which the resource group will be created"
}

variable "tenant_id" {
  type = string
  description = "The ID of the tenant in which all objects will be created"
}

variable "client_id" {
  type = string
  description = "The client ID of the app registration which will be used to authenticate"
}

variable "client_secret" {
  type = string
  description = "The client secret of the app registration which will be used to authenticate"
}

variable "resource_group_name" {
  type = string
  description = "The name of the resource group to create"
}

variable "location" {
  type = string
  description = "The Azure location to create resources in. e.g. 'East US'"
  default = "East US"
}

variable "starting_address" {
  type = string
  description = "The starting IP of a /16 CIDR range which will be used for the network. e.g. '10.2.0.0' or '10.47.0.0'."
  default = "10.0.0.0"
}

variable "dns_servers" {
  type = list(string)
  description = "The list of DNS servers to use by default for resources in the virtual network"
  default = ["1.1.1.1", "1.0.0.1"]
}

variable "ssh_keys" {
	type = list(string)
  description = "A list of SSH public keys to put in the authorized_keys file of the jumpbox"
}

variable "bastion_username" {
	type = string
  description = "The admin username for the bastion box to be created"
  default = "ubuntu"
}

provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  tenant_id       = "${var.tenant_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group_name}"
  location = "${var.location}"
}

resource "azurerm_virtual_network" "network" {
  name          = "${var.resource_group_name}-network"
  location      = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  address_space = ["${var.starting_address}/16"]
  dns_servers   = var.dns_servers
}

resource "azurerm_network_security_group" "controlplane" {
  name                = "${var.resource_group_name}-sg"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

resource "azurerm_subnet" "controlplane" {
  name                 = "${var.resource_group_name}-controlplane-subnet"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  virtual_network_name = "${azurerm_virtual_network.network.name}"
  address_prefix       = "${var.starting_address}/24"
  network_security_group_id = "${azurerm_network_security_group.controlplane.id}"
}

resource "azurerm_subnet_network_security_group_association" "controlplane" {
  subnet_id   = "${azurerm_subnet.controlplane.id}"
  network_security_group_id = "${azurerm_network_security_group.controlplane.id}"  
}

resource "azurerm_public_ip" "bastion" {
  name                = "${var.resource_group_name}-bastion-public-ip"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  allocation_method   = "Static"
}

locals {
  bastion-ip-configuration-name = "ipconfig1"
}

resource "azurerm_network_interface" "bastion" {
  name                = "${var.resource_group_name}-bastion"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  network_security_group_id = "${azurerm_network_security_group.controlplane.id}"
  
  ip_configuration {
    name                 = "${local.bastion-ip-configuration-name}"
    subnet_id            = "${azurerm_subnet.controlplane.id}"
    private_ip_address_allocation = "Static"
    private_ip_address   = join(".", concat(slice(split(".", "${var.starting_address}"), 0, 3), ["4"]))
    public_ip_address_id = "${azurerm_public_ip.bastion.id}"
  }
}

resource "azurerm_application_security_group" "bastion" {
  name                = "${var.resource_group_name}-bastion-asg"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"
}

resource "azurerm_network_interface_application_security_group_association" "bastion-asg-nic" {
  network_interface_id          = "${azurerm_network_interface.bastion.id}"
  ip_configuration_name         = "${local.bastion-ip-configuration-name}"
  application_security_group_id = "${azurerm_application_security_group.bastion.id}"
}

resource "azurerm_network_security_rule" "allow-bastion-access" {
  name                       = "allow-bastion-access"
  resource_group_name        = "${azurerm_resource_group.rg.name}"
  network_security_group_name = "${azurerm_network_security_group.controlplane.name}"

  priority                   = 100
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "TCP"
  source_port_range          = "*"
  destination_port_range     = "22"
  source_address_prefix      = "*"
  destination_application_security_group_ids = ["${azurerm_application_security_group.bastion.id}"]
}

resource "azurerm_managed_disk" "bastion-data" {
  name                 = "${var.resource_group_name}-bastion-data-disk"
  location             = "${azurerm_resource_group.rg.location}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  disk_size_gb         = "50"
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
}

resource "azurerm_virtual_machine" "bastion" {
  name                  = "${var.resource_group_name}-bastion"
  location              = "${azurerm_resource_group.rg.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"

  vm_size               = "Standard_A2_v2"
  network_interface_ids = ["${azurerm_network_interface.bastion.id}"]
  
  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.resource_group_name}-bastion-os-disk"
    create_option     = "FromImage"
    caching           = "ReadWrite"
    os_type           = "Linux"
    managed_disk_type = "Standard_LRS"
  }

  storage_data_disk {
    name            = "${azurerm_managed_disk.bastion-data.name}"
    lun             = 0
    create_option   = "Attach"
    disk_size_gb    = "${azurerm_managed_disk.bastion-data.disk_size_gb}"
    managed_disk_id = "${azurerm_managed_disk.bastion-data.id}"
  }

  os_profile {
    admin_username = "${var.bastion_username}"
    computer_name  = "bastion"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    dynamic "ssh_keys" {
			for_each = var.ssh_keys
      content {
				key_data = ssh_keys.value
        path     = "/home/${var.bastion_username}/.ssh/authorized_keys"
      }
		}   
  }
}

output "bastion-box-ip-address" {
  value = azurerm_public_ip.bastion.ip_address
}

output "bastion-box-username" {
	value = var.bastion_username
}

output "resource-group-name" {
	value = azurerm_resource_group.rg.name
}

output "network-security-group-name" {
	value = azurerm_network_security_group.controlplane.name
}

output "virtual-network-name" {
	value = azurerm_virtual_network.network.name
}

output "subnet-name" {
	value = azurerm_subnet.controlplane.name
}

output "subnet-CIDR" {
	value = azurerm_subnet.controlplane.address_prefix
}

output "subnet-gateway" {
	value = join(".", concat(slice(split(".", "${var.starting_address}"), 0, 3), ["1"]))
}

output "recommended-BOSH-director-IP" {
  value = join(".", concat(slice(split(".", "${var.starting_address}"), 0, 3), ["5"]))
}

output "dns-servers" {
	value = var.dns_servers
}
