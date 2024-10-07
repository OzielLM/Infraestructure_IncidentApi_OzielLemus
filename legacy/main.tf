terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {

  }
}

# Construir grupo de recursos con terraform
resource "azurerm_resource_group" "IN_RG" {
  name     = var.resource_group
  location = var.location_resource_group

  tags = {
    "environment" = var.environment
  }
}

# Construir virtual network
resource "azurerm_virtual_network" "IN_VNET" {
  resource_group_name = azurerm_resource_group.IN_RG.name
  location            = azurerm_resource_group.IN_RG.location
  name                = var.vnet_name
  address_space       = ["10.123.0.0/16"]

  tags = {
    "enviroment" = var.environment
  }
}

# Construir subnet
resource "azurerm_subnet" "IN_SUBNET" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.IN_RG.name
  virtual_network_name = azurerm_virtual_network.IN_VNET.name
  address_prefixes     = ["10.123.1.0/24"]
}

# Construir security groups
resource "azurerm_network_security_group" "IN_SG" {
  name                = var.security_group_name
  location            = azurerm_resource_group.IN_RG.location
  resource_group_name = azurerm_resource_group.IN_RG.name

  tags = {
    "enviroment" = var.environment
  }

  security_rule {
    name                       = "allow-all"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Crear asociacion entre subnet y security groups
resource "azurerm_subnet_network_security_group_association" "IN_SGA" {
  subnet_id                 = azurerm_subnet.IN_SUBNET.id
  network_security_group_id = azurerm_network_security_group.IN_SG.id
}

# Crear IP publica
resource "azurerm_public_ip" "IN_IP" {
  name                = var.ip_name
  resource_group_name = azurerm_resource_group.IN_RG.name
  location            = azurerm_resource_group.IN_RG.location
  allocation_method   = "Dynamic"
}

# Crear network interface
resource "azurerm_network_interface" "IN_NIC" {
  name                = var.nic_name
  location            = azurerm_resource_group.IN_RG.location
  resource_group_name = azurerm_resource_group.IN_RG.name

  ip_configuration {
    name                          = "IN-IP-Config"
    subnet_id                     = azurerm_subnet.IN_SUBNET.id
    public_ip_address_id          = azurerm_public_ip.IN_IP.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    "enviroment" = var.environment
  }
}

# Crear la maquina virtual
resource "azurerm_linux_virtual_machine" "IN_VM" {
  name                  = var.server_name
  resource_group_name   = azurerm_resource_group.IN_RG.name
  location              = azurerm_resource_group.IN_RG.location
  size                  = "Standard_B2s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.IN_NIC.id]
  custom_data           = filebase64("./scripts/docker-install.tpl")

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    version   = "latest"
    sku       = "22_04-lts"
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
  }

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("./keys/712incident_server.pub")
  }

  provisioner "file" {
    source      = "./containers/docker-compose.yml"
    destination = "/home/adminuser/docker-compose.yml"

    connection {
      type        = "ssh"
      user        = "adminuser"
      private_key = file("./keys/712incident_server")
      host        = self.public_ip_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo su -c 'mkdir -p /home/adminuser'",
      "sudo su -c 'mkdir -p /volumes/nginx/html'",
      "sudo su -c 'mkdir -p /volumes/nginx/certs'",
      "sudo su -c 'mkdir -p /volumes/nginx/vhostd'",
      "sudo su -c 'mkdir -p /volumes/mongo/data'",
      "sudo su -c 'chmod -R 770 /volumes/mongo/data'",
      "sudo su -c 'touch /home/adminuser/.env'",
      "sudo su -c 'echo \"DOMAIN=oziellemusincident.ddns.net\" >> /home/adminuser/.env'",
      "sudo su -c 'echo \"MONGO_URL_DOCKER=mongodb://root:example@mongo/\" >> /home/adminuser/.env'",
      "sudo su -c 'echo \"PORT=3000\" >> /home/adminuser/.env'",
      "sudo su -c 'echo \"MAIL_SECRET_KEY=dqsuobwhjcvkzedc\" >> /home/adminuser/.env'",
      "sudo su -c 'echo \"MAIL_SERVICE=gmail\" >> /home/adminuser/.env'",
      "sudo su -c 'echo \"MAIL_USER=oziel.comics@gmail.com\" >> /home/adminuser/.env'",
      "sudo su -c 'echo \"MAPBOX_ACCESS_TOKEN=pk.eyJ1IjoianVhbmZyOTciLCJhIjoiY2x4cnhqZGZpMWUzdTJrb2Qxd2k5Z3huYSJ9.Kp99lB1snn3xzzi26jKy4w\" >> /home/adminuser/.env'",
      "sudo su -c 'echo \"MONGO_INITDB_ROOT_USERNAME=root\" >> /home/adminuser/.env'",
      "sudo su -c 'echo \"MONGO_INITDB_ROOT_PASSWORD=example\" >> /home/adminuser/.env'",
    ]

    connection {
      type        = "ssh"
      user        = "adminuser"
      private_key = file("./keys/712incident_server")
      host        = self.public_ip_address
    }
  }
}

resource "time_sleep" "wait_2_minutes" {
  depends_on      = [azurerm_linux_virtual_machine.IN_VM]
  create_duration = "120s"
}

resource "null_resource" "init_docker" {
  depends_on = [time_sleep.wait_2_minutes]

  connection {
    type        = "ssh"
    user        = "adminuser"
    private_key = file("./keys/712incident_server")
    host        = azurerm_linux_virtual_machine.IN_VM.public_ip_address
  }

  provisioner "remote-exec" {
    inline = ["sudo su -c 'docker-compose up -d'"]
  }
}

output "IN_IP_Output" {
  value = "${var.environment}: ${azurerm_linux_virtual_machine.IN_VM.public_ip_address}"
}
