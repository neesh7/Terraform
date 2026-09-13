# Cerating resource group
resource "azurerm_resource_group" "main" {
  name = "rg-${var.application_name}-${var.environment_name}" # environment name will flow here from env/dev.tfvars or env/prod.tfvars
  location = var.primary_location
}

# Step -1 Creating vnet
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.application_name}-${var.environment_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.base_address_space] # CIDR Notation - A range of ip addresses
  # IPAM - IP Address management solutions
}

# CIDR: 10.39.0.0/22 -> we are using ipv4 means it have 4 octates with 32 bit
# to calculate the actual range is 32-n and 'n' comes after '/' which is 22 here
# range = 32-22=10 means 2^10=1024 means the effective range of vnet is 10.39.0.0 to 10.0.0.1023
# we want to make 4 slices in this vnet means 4 subnet 

# My 4 subnet address range

# Step 2: Prepare address ranges for subnets using cidr functions
locals {
  # here our base addr range is 22 and subnet range is 22 hence n=24-22=2-bits and 0,1,2,3 is index means slicing that address range
  snet1_address_space = cidrsubnet(var.base_address_space, 2, 0)
  snet2_address_space = cidrsubnet(var.base_address_space, 2, 1)
  snet3_address_space = cidrsubnet(var.base_address_space, 2, 2)
  snet4_address_space = cidrsubnet(var.base_address_space, 2, 3)

  # snet-1's /24 is oversized for Bastion (needs /26) - slice it further into two /26 blocks
  bastion_address_space = cidrsubnet(local.snet1_address_space, 2, 0) # first /26 in snet-1's /24  -> 10.39.0.0/26
  snet5_address_space   = cidrsubnet(local.snet1_address_space, 2, 1) # second /26 in snet-1's /24 -> 10.39.0.64/26
}
# use terraform console to confirm if the values is valid local.snet1_address_space
# Step 2 : Slicing vnet into subnets

# snet-1's /24 space is now sliced into two /26 blocks: AzureBastionSubnet + snet-5
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet" # exact name required by Azure for Bastion to use this subnet
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.bastion_address_space]
}
resource "azurerm_subnet" "subnet-5" {
  name                 = "snet-5"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.snet5_address_space]
  depends_on = [ azurerm_subnet.bastion ] # keeps subnet creation serialized to avoid NetcfgSubnetRangesOverlap race

# 10.39.1.0/24
}
resource "azurerm_subnet" "subnet-2" {
  name                 = "snet-2"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  # address_prefixes     = ["10.39.1.0/24"]
  address_prefixes     = [local.snet2_address_space]
  depends_on = [ azurerm_subnet.subnet-5 ] # forces serial order so a future base_address_space/split change modifies subnets one at a time, not all in parallel (avoids NetcfgSubnetRangesOverlap race)
# 10.39.2.0/24
}
resource "azurerm_subnet" "subnet-3" {
  name                 = "snet-3"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  # address_prefixes     = ["10.39.2.0/24"]
  address_prefixes = [local.snet3_address_space]
  depends_on = [ azurerm_subnet.subnet-2 ] # same reason as subnet-2: keeps the chain serialized end to end
# 10.39.3.0/24
}
resource "azurerm_subnet" "subnet-4" {
  name                 = "snet-4"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  # address_prefixes     = ["10.39.3.0/24"]
  address_prefixes = [local.snet4_address_space]
  depends_on = [ azurerm_subnet.subnet-3 ] # last link in the chain: subnet-4 always applies after subnet-3 is fully settled
}

# Get my local ip to make it work dynamically : only allow SSH traffic that originates from my laptop's IP
data "http" "myip" {
  url = "https://ipv4.icanhazip.com" # forced IPv4 - ifconfig.me can return IPv6, which won't match an IPv4-only VM public IP
}

# Step 3: Setting up NSG
resource "azurerm_network_security_group" "Remote_access" {
  # NSG is going to show up directly in RG that's why we name it like this
  name                = "nsg-${var.application_name}-${var.environment_name}-remote-access"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "ssh"
    priority                   = 100 # Lower number higher priority
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22" # This is to open ssh port
    # source_address_prefix      = "*" # This is not a ideal setup as anyone over internet can access our vm conncected with this nsg
     # By locking down source ip address we are allowing the individual with this ip only to access the nsg or vm
    source_address_prefix = chomp(data.http.myip.body)
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-bastion-ssh"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = local.bastion_address_space # Bastion connects to the VM's private IP from this subnet range, not from our laptop's IP
    destination_address_prefix = "*"
  }

# debugging network issues due to nsg
# az network nsg rule list --nsg-name nsg-network-dev-remote-access --resource-group rg-network-dev -o table

  # tags = {
  #   environment = "Production"
  # }
}
# Step 4: After creating NSG we have to associate it with a subnet to make it effective.

# Associating NSG with subnet-1
# resource "azurerm_subnet_network_security_group_association" "subnet1_remote_access" {
#   subnet_id                 = azurerm_subnet.subnet-1.id
#   network_security_group_id = azurerm_network_security_group.Remote_access.id
# }

# This step is done to leave snet1 for azure bastion and to do so we are moving our
# NSG association on snet2
resource "azurerm_subnet_network_security_group_association" "subnet2_remote_access" {
  subnet_id                 = azurerm_subnet.subnet-2.id
  network_security_group_id = azurerm_network_security_group.Remote_access.id
}