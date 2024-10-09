terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }

  backend "azurerm"{
    resource_group_name = "Blob-RG-OzielLemus"
    storage_account_name = "blobsaoziellemus"
    container_name = "bloboziellemus"
    key = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {

  }
}