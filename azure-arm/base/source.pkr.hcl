/* Creates a reusable managed image from an existing market place image.
The created image will be stored in the HCP Packer registry.
*/

packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = ">=1.0.2"
    }
  }
}

variable "client_id" {
  default = env("ARM_CLIENT_ID")
}
variable "client_secret" {
  default = env("ARM_CLIENT_SECRET")
}
variable "resource_group" {
  default = env("ARM_RESOURCE_GROUP_NAME")
}
variable "subscription_id" {
  default = env("ARM_SUBSCRIPTION_ID")
}

source "azure-arm" "windows-server" {
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret

  image_publisher = "MicrosoftWindowsServer"
  image_offer     = "WindowsServer"
  image_sku       = "2012-R2-Datacenter"


  os_type                           = "windows"
  managed_image_name                = "CustomWindowsServer{{timestamp}}"
  managed_image_resource_group_name = var.resource_group
  vm_size                           = "Standard_DS1_V2"
  communicator                      = "winrm"
  winrm_insecure                    = true
  winrm_timeout                     = "8m"
  winrm_use_ntlm                    = true
  winrm_use_ssl                     = true
  winrm_username                    = "packer"

  location = "westus"
}

build {

  sources = ["source.azure-arm.windows-server"]

  provisioner "powershell" {
    inline = [
      "Add-WindowsFeature Web-Server",
      "while ((Get-Service RdAgent).Status -ne 'Running') { Start-Sleep -s 5 }",
      "while ((Get-Service WindowsAzureGuestAgent).Status -ne 'Running') { Start-Sleep -s 5 }",
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit",
      "while($true) { $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select ImageState; if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { Write-Output $imageState.ImageState; Start-Sleep -s 10  } else { break } }"
    ]
  }

  hcp_packer_registry {
    bucket_name = "windows-server"
    bucket_labels = {
      "team" = "development"
    }
    build_labels = {
      "version" = "2021-RS-Datacenter"
    }
  }
}



