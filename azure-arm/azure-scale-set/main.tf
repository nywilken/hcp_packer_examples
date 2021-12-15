terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "2.88.1"
    }
    hcp = {
      source = "hashicorp/hcp"
      version = "0.20.0"
    }
  }
}

variable "resource_group" {
 type = string
}

provider "azurerm" {
  features {}
}

provider "hcp" {
}

data "hcp_packer_iteration" "hardened_source" {
  bucket_name = "windows-server"
  channel     = "development"
}

data "hcp_packer_image" "foo" {
  bucket_name    = "windows-server"
  iteration_id   = data.hcp_packer_iteration.hardened_source.id
  cloud_provider = "azure"
  region         = "westus"
}

resource "azurerm_virtual_network" "example" {
  name                = "acctvn"
  address_space       = ["10.0.0.0/16"]
  location            = "westus"
  resource_group_name = "${var.resource_group}"
}

resource "azurerm_subnet" "example" {
  name                 = "acctsub"
  resource_group_name = "${var.resource_group}"
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.2.0/24"]
}


resource "azurerm_virtual_machine_scale_set" "example" {
  name                = "mytestscaleset-1"
  location            = "westus"
  resource_group_name = "${var.resource_group}"

  upgrade_policy_mode  = "Manual"


  sku {
    name = "Standard_D1_v2"
    tier = "Standard"
    capacity = 2
  }

  storage_profile_image_reference {
		id = data.hcp_packer_image.foo.cloud_image_id
  }

  storage_profile_os_disk {
    caching       = "ReadWrite"
    create_option = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name_prefix = "packerset"
    admin_username = "Packer"
    admin_password = "Passwword1234"
  }
network_profile {
    name    = "terraformnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "TestIPConfiguration"
      primary                                = true
      subnet_id                              = azurerm_subnet.example.id
    }
  }
  tags = {
    environment = "staging"
  }
}
