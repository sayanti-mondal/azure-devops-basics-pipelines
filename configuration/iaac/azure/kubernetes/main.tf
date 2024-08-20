# creation of the resource group
resource "azurerm_resource_group" "resource_group" {
  name     = "${var.resource_group}_${var.environment}"
  location = var.location
}

provider "azurerm" {
  //version = "~>2.0.0"
  features {}
}

# creation of a resouce - azure kubernetes cluster
resource "azurerm_kubernetes_cluster" "terraform-k8s" {
  name                = "${var.cluster_name}_${var.environment}" # would create a different cluster for each enironment
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  dns_prefix          = var.dns_prefix

  linux_profile {
    admin_username = "ubuntu"

    ssh_key {
      key_data = file(var.ssh_public_key)  # ssh key associated with the cluster
    }
  }

  default_node_pool { # as we know multiple nodes are there in a cluster
    name            = "agentpool"
    node_count      = var.node_count
    vm_size         = "standard_b2ms" # 1 cpu and 1 gb memory 
    # vm_size         = "standard_d2as_v5"      CHANGE IF AN ERROR ARISES 
  }

  service_principal {           # service_principal is required to talk to the cluster
    client_id     = var.client_id
    client_secret = var.client_secret
  }

  tags = {
    Environment = var.environment
  }
}

# Creation of backend
terraform {
  backend "azurerm" {
    # storage_account_name="<<storage_account_name>>" #OVERRIDE in TERRAFORM init
    # access_key="<<storage_account_key>>" #OVERRIDE in TERRAFORM init
    # key="<<env_name.k8s.tfstate>>" #OVERRIDE in TERRAFORM init
    # container_name="<<storage_account_container_name>>" #OVERRIDE in TERRAFORM init
  }
}
