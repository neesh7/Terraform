# Virtual Network Lab — Module Notes

## 1. Creating Virtual Network

Azure virtual network resource is multi-modal, meaning you can provision some resources like subnet as nested blocks or independent resources. at this time it is mutually exclusive to maintain a standalone or inline resource and the recommendation is to use standalone resource cause it gives us flexibility to:
- manage each subnet's lifecycle independently (add/modify/destroy one subnet without touching the vnet resource or other subnets)
- attach subnet-specific resources cleanly (NSG associations, route table associations, service endpoints, delegations) by referencing the subnet's own resource ID
- avoid forcing whole-list replacement/noisy diffs across all subnets when only one changes
- scale better with for_each/count when generating many subnets dynamically, or when splitting vnet and subnet creation across modules

inline (nested) subnet block example:
```hcl
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-example"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  subnet {
    name             = "subnet1"
    address_prefixes = ["10.0.1.0/24"]
  }
}
```

standalone subnet resource example (recommended):
```hcl
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-example"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet1" {
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}
```

## 2. Default Network Watcher

When we create a VNet using terraform, azure creates a default Network Watcher for us, which doesn't even get deleted on `terraform destroy`.

when a vnet is created in a region (via portal, CLI, or terraform), azure's platform automatically provisions a Network Watcher in a resource group it auto-creates named `NetworkWatcherRG` for that region - if Network Watcher isn't already enabled there. this is a side effect of the azure platform itself, not something declared in our .tf config.

why `terraform destroy` doesn't remove it:
- terraform only tracks resources present in its state file
- since `NetworkWatcherRG` and the Network Watcher inside it were created by azure, not by a resource block we wrote, terraform has no record of them in state
- so `terraform destroy` cleans up everything we defined (vnet, subnets, etc.) but leaves `NetworkWatcherRG` behind - an orphaned resource group

how to handle it:
- import it into state if we want terraform to manage/destroy it: `terraform import` or reference via `azurerm_network_watcher` / `data "azurerm_network_watcher"`
- or disable the auto-creation at the subscription level via `Microsoft.Network` resource provider registration settings
- otherwise, manual cleanup of `NetworkWatcherRG` is needed after destroy if we want a fully clean subscription

## 3. Subnet Reserved Addresses

Subnetting a /24 gives 256 addresses on paper, but azure reserves 5 of them (network address, gateway, 2x DNS, broadcast) for its own use - so a /24 subnet actually yields only 251 usable addresses, not 256.

## 4. Using CIDR Function to Slice IP Addresses for Subnet

## 5. Switchbacking / Drop-Create Approach

To get somewhere we sometimes have to destroy and create — the manual, staged approach needed when changing a vnet's `address_space` that already has subnets carved out of it (e.g. `10.39.*/22` -> `10.40.*/22`).

why we can't just change it in one apply:
- terraform's dependency graph only tracks explicit references (vnet -> subnet), it has no idea that "shrink/move the vnet's address space" and "update subnet cidrs to match" are related operations that must happen in strict order
- if both changes are applied together, terraform may try to update/create subnets in parallel with the vnet's address_space change, and azure will reject subnets that fall outside (or briefly conflict with) the vnet's current range mid-apply - the same class of race condition as the `NetcfgSubnetRangesOverlap` error we hit earlier when resizing subnet-1 while creating subnet-2

the switchback pattern (step back before stepping forward, like a switchback road):
- step 1: delete/remove the existing subnets first (comment out the blocks or `terraform destroy -target=azurerm_subnet.x` for each) so nothing depends on the old vnet range
- step 2: update the vnet's `address_space` to the new range and apply on its own
- step 3: re-create the subnets with cidrs that fall inside the new range

doing all three in a single apply is exactly what causes the race - terraform can't guarantee the vnet's address space change fully commits in azure before the new subnet creation fires.

## 6. Setting up NSG

**What an NSG actually does**: it's a network-level packet filter, not a user authentication/authorization mechanism. It has no concept of "users" — it only evaluates source/destination IP, port, and protocol before a packet is allowed to arrive at the VM's network interface at all.

**Two-step sequence for something like SSH access** (NSG is step 1, SSH itself is step 2 — they're independent layers):

```
Connection attempt
   → NSG rule evaluated (network layer — "can this traffic even arrive at port 22?")
       → if denied → dropped here, SSH daemon never sees it
       → if allowed → reaches the VM's SSH daemon
           → SSH key authentication (application layer — "are you who you claim to be?")
               → if valid private key matches → shell access granted
               → if invalid → rejected, but the NSG already let this attempt through
```

Key takeaway: an open NSG rule (`source_address_prefix = "*"`) only controls **who can knock on the door** — it says nothing about who can actually log in. That's entirely down to SSH key/password auth on the VM. Don't confuse "port is open" with "anyone can get in."

**NSG association — attaching an NSG to a subnet**

An `azurerm_network_security_group` resource by itself does nothing until it's *associated* with something — either a subnet (applies to every NIC in that subnet) or a single NIC (applies to just that one resource). Association is a **separate resource**, not an inline property of the NSG or the subnet:

```hcl
resource "azurerm_subnet_network_security_group_association" "remote_access" {
  subnet_id                 = azurerm_subnet.subnet-1.id
  network_security_group_id = azurerm_network_security_group.Remote_access.id
}
```

Why it's a separate resource instead of a nested block (same reasoning as standalone subnets in point 1):
- one NSG can be reused across multiple subnets — the association is the thing that varies, not the NSG itself
- lets you swap/remove the association independently without touching the NSG's rules or the subnet's address space
- avoids forcing a replace/diff on the subnet or NSG whenever the *pairing* between them changes

**Note on rule evaluation order (ties back to §4 of Azure-VNet-Concepts.md)**: when an NSG is subnet-associated, its rules apply to every NIC in that subnet — evaluated by `priority` (lowest number first, first match wins), before Azure's own implicit default rules at priority 65000+.

## 7. Lookup My IP Address
