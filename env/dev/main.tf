module "dev_vm" {
  source                     = "../../modules/vm"
  environment                = "dev"
  mail_secret_key            = var.mail_secret_key
  mail_service               = "gmail"
  mail_user                  = var.mail_user
  admin_username             = "adminuser"
  domain                     = var.domain
  resource_group             = "IN-RG-72634"
  nic_name                   = "IN-NIC-72634"
  security_group_name        = "IN-SG-72634"
  ssh_key_path               = "./keys/712incident_server"
  port                       = "300"
  server_name                = "IN-Server-72634"
  location_resource_group    = "eastus2"
  mapbox_access_token        = var.mapbox_access_token
  mongo_url_docker           = var.mongo_url_docker
  mongo_initdb_root_password = var.mongo_initdb_root_username
  mongo_initdb_root_username = var.mongo_initdb_root_password
  ip_name                    = "IN-IP-72634"
  vnet_name                  = "IN-VNET-72634"
  subnet_name                = "IN-SUBNET-72634"
}

