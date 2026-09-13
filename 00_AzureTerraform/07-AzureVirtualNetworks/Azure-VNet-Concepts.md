# Azure Virtual Networking — Concepts + Terraform (Plain Language)

> Goal: understand what each networking piece *actually does* in Azure, then see the matching Terraform block. Read top to bottom — each section builds on the last.

---

## 0. The Big Picture (mental model)

Think of Azure networking like a building:

```
Azure Subscription
└── Resource Group                      (the building)
    └── Virtual Network (VNet)          (the building's private address space)
        ├── Subnet "web"                (floor 1 — a section of that address space)
        │     └── NSG attached          (security guard at the floor entrance)
        ├── Subnet "app"                (floor 2)
        └── Subnet "db"                 (floor 3, no internet access)

VNet A  <---- Peering ---->  VNet B     (a private hallway connecting two buildings)
```

- A **VNet** is your own private, isolated network inside Azure. Nothing outside it can reach in unless you explicitly allow it.
- A **Subnet** is a smaller slice of the VNet's address space, used to group and isolate resources (web tier vs db tier).
- An **NSG (Network Security Group)** is a firewall — a list of allow/deny rules — attached to a subnet or NIC.
- A **Public IP** lets a resource be reached from (or reach out to) the internet.
- A **Private IP** is the internal address a resource uses to talk to other resources inside the VNet.
- **VNet Peering** connects two VNets so resources in each can talk to each other privately, without going over the public internet.

Everything below is one of these five pieces.

---

## 1. Virtual Network (VNet)

**What it is**: A logically isolated network in Azure, scoped to a region. It's just an address range (CIDR block) — it has no compute in it by default.

**Key facts**:
- You define it with a CIDR block, e.g. `10.0.0.0/16` → gives you 65,536 addresses.
- A VNet lives in **one region only**. To span regions, you peer two VNets.
- By default, all subnets inside the same VNet can talk to each other (no firewall needed) — Azure routes between them automatically.
- Nothing outside the VNet (internet, other VNets, on-prem) can reach in unless you explicitly enable it (public IP, peering, VPN/ExpressRoute).

**Terraform**:
```hcl
resource "azurerm_virtual_network" "main" {
  name                = "vnet-prod-eastus"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}
```

**CIDR quick reference** (so `/16` vs `/24` isn't a mystery):

| CIDR | # of addresses | Typical use |
|------|----------------|-------------|
| `/16` | 65,536 | Whole VNet |
| `/24` | 256 | A subnet |
| `/28` | 16 | A small subnet (e.g. Azure Bastion needs exactly this) |

Rule of thumb: **smaller number after the `/` = bigger network**.

### 1.1 How CIDR Is Actually Computed (the math, not just the table)

An IPv4 address is 32 bits (4 octets, each 8 bits). `/n` means: **the first `n` bits are fixed (network part), the remaining `32 - n` bits are free (host part)**.

**Core formula**:
```
Total addresses in the block = 2^(32 - n)
```

**Worked example 1 — `10.0.1.0/24`**:
- host bits = `32 - 24 = 8`
- total addresses = `2^8 = 256`
- the last octet (8 bits) is entirely free → range = `10.0.1.0` → `10.0.1.255`

**Worked example 2 — a less round one, `10.0.0.0/20`**:
- host bits = `32 - 20 = 12`
- total addresses = `2^12 = 4096`
- 12 free bits = all 8 bits of octet 4 + last 4 bits of octet 3 → octet 3 ranges over `00000000`–`00001111` = `0`–`15` → range = `10.0.0.0` → `10.0.15.255`

**Subnet mask equivalents** (same idea, different notation):

| CIDR | Host bits | Addresses | Subnet mask |
|------|-----------|-----------|--------------|
| `/16` | 16 | 65,536 | `255.255.0.0` |
| `/20` | 12 | 4,096 | `255.255.240.0` |
| `/24` | 8 | 256 | `255.255.255.0` |
| `/28` | 4 | 16 | `255.255.255.240` |
| `/29` | 3 | 8 | `255.255.255.248` |

**Finding the network address by hand**: convert the IP to binary, zero out everything past bit `n` — that's the network (first) address. Set all host bits to `1` to get the last address in the range.

**Subnetting a VNet in practice**: you're just carving non-overlapping CIDR blocks out of the VNet's range. `10.0.0.0/16` (65,536 addresses) can be split into 256 separate `/24` blocks (`10.0.0.0/24`, `10.0.1.0/24`, … `10.0.255.0/24`). Azure will reject subnets whose ranges overlap.

**Azure's reservation on top of the math**: on-prem networking reserves 2 addresses per block (network + broadcast). Azure reserves **5 addresses in every subnet, no matter how big or small the subnet is** — 4 from the **start** of the range, 1 from the **end**:

```
10.0.1.0/24 example (256 total addresses):

  10.0.1.0   ─┐
  10.0.1.1    │  4 reserved from the START
  10.0.1.2    │
  10.0.1.3   ─┘
  10.0.1.4  ─┐
  10.0.1.5   │
  ...        │  251 usable addresses (assignable to NICs)
  10.0.1.254 ─┘
  10.0.1.255 ── 1 reserved from the END
```

| Address | Position | Purpose |
|---|---|---|
| `10.0.1.0` | 1st (start) | **Network address** — identifies the subnet itself, not assignable to any device |
| `10.0.1.1` | 2nd (start) | **Default gateway** — the address Azure uses as the subnet's router, for routing traffic in/out of the subnet |
| `10.0.1.2` | 3rd (start) | **Azure DNS** — reserved to map to Azure's internal DNS service |
| `10.0.1.3` | 4th (start) | **Azure DNS** — a second reserved address for the same DNS mapping (redundancy) |
| `10.0.1.255` | last (end) | **Broadcast address** — reserved for the subnet's broadcast, matching standard IP networking convention |

So it's **4 reserved at the front + 1 reserved at the very back = 5 total**, regardless of whether the subnet is a `/24`, `/26`, or `/28` — the count is always 5, only the percentage impact changes (a small `/28` subnet with only 16 addresses loses a much bigger *share* of its space to these 5 than a `/24` does).

So usable hosts = `2^(32-n) - 5`. A `/24` (256 total) → **251 usable**.

### 1.2 Naming the Pieces of a CIDR Block

Take `10.0.1.0/24` apart:

| Piece | Name | Fixed? |
|---|---|---|
| `10.0.1.0` | **Base address** (a.k.a. **network address** — the first address in the range) | The address as written is fixed, but *how many of its bits actually constrain the range* is decided entirely by the `/24` |
| `10` (1st octet) | Just the first octet of that address | Not fixed by CIDR itself — it's `10.x.x.x` here only because `10.0.0.0/8` is one of the three RFC 1918 ranges reserved for private networks (the others: `172.16.0.0/12`, `192.168.0.0/16`). Pure convention, not a CIDR rule. |
| `/24` | **Prefix length** (a.k.a. subnet mask length) | This is the number that decides everything — it locks the first 24 bits (`10.0.1`) as the network portion and leaves `32-24=8` bits (the last octet) free, giving `2^8=256` addresses |

**One-line summary**: the prefix length (`/24`) is what does the real work — it decides how much of the base address is "locked" vs "free to vary." The base address itself is just a starting point written in dotted-decimal.

---

## 2. Subnets

**What it is**: A subdivision of the VNet's address range. Every resource (VM, App Service with VNet integration, etc.) that needs a private IP lives inside a subnet, not directly in the VNet.

**Why subnets exist**:
- **Segmentation** — put web servers in one subnet, databases in another, and control traffic between them with NSGs.
- **Delegation** — some Azure services (e.g. Azure SQL Managed Instance, Container Instances) require their own **dedicated subnet**.
- **Granular security** — attach a different NSG to each subnet.

**Reminder**: Azure reserves 5 addresses in every subnet regardless of size — see §1.1 above for the math (a `/24` gives you 251 usable, not 256).

**Terraform**:
```hcl
resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "db" {
  name                 = "snet-db"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}
```

**Key rule**: subnet ranges must fall **inside** the VNet's range and must **not overlap** with each other.

---

## 3. IP Addresses — Private vs Public, Static vs Dynamic

There are two independent questions for any IP:
1. **Private or Public?** — who can see/reach this address.
2. **Static or Dynamic?** — does it change over time.

### 3.1 Private vs Public

| | Private IP | Public IP |
|---|---|---|
| Scope | Only reachable inside the VNet (or peered VNets / VPN) | Reachable from the internet |
| Comes from | The subnet's address range (e.g. `10.0.1.4`) | Azure's pool of public addresses |
| Cost | Free | Public IP resources have a small cost |
| Used for | VM-to-VM traffic, internal load balancers, DB servers | Web-facing VMs, load balancers, bastion hosts |
| Created as | Automatically assigned to every NIC | A separate `azurerm_public_ip` resource you attach |

**Golden rule**: don't attach a public IP unless the resource genuinely needs to be reached from (or reach) the internet directly. Databases and internal app servers should have **private IP only**.

### 3.2 Static vs Dynamic

| | Dynamic | Static |
|---|---|---|
| Meaning | Azure picks the address for you | You reserve one specific address yourself, from the subnet's range |
| Use for | Dev/test, anything where the exact address doesn't matter | Production — DNS records, firewall allow-lists, connection strings, anything referencing the IP by value |

**The common misconception (worth getting exactly right)**: "Dynamic means the IP changes on reboot." That's not accurate for private IPs, and only conditionally true for public IPs. Full breakdown:

#### Private IP — current behavior

The private IP lives on the **NIC** (Network Interface), not on the VM itself — this matters because the IP's lifecycle follows the NIC, not the VM's power state.

- **Dynamic** (default): Azure assigns an address from the subnet once, when the NIC is created. It is **sticky to the NIC** — it does **not** change on an OS-level reboot, and it does **not** change on an Azure **Stop (Deallocate) → Start** cycle either, as long as the NIC itself still exists.
- It only changes if: you delete and recreate the NIC, explicitly edit the `ip_configuration` block, or detach/reattach the NIC to a different subnet.
- **Static**: you pick one address yourself (must be inside the subnet's range and not already in use); fixed for the NIC's lifetime, no exceptions.

**So**: "reboot changes the private IP" is not expected behavior today. If you're seeing that, something else is going on — e.g. the NIC is being recreated by your Terraform/automation each run (check for unintended `create_before_destroy`/replacement in the plan), or you're actually observing the *public* IP.

#### Public IP — current behavior (this is where SKU matters)

| SKU | Allocation allowed | Behavior across Stop (Deallocate) → Start | Behavior across plain OS reboot |
|---|---|---|---|
| **Standard** (current default) | `Static` only — Azure does not allow `Dynamic` on Standard SKU | Never changes | Never changes |
| **Basic** (legacy) | `Dynamic` | **Released on deallocate; a new address is assigned on next start** | Unchanged |
| **Basic** (legacy) | `Static` | Unchanged | Unchanged |

**Current status note**: Basic SKU public IPs are being **retired by Microsoft on 30 September 2025** — new deployments should use `sku = "Standard"` exclusively, which also forces `allocation_method = "Static"`. In practice this means the classic "public IP changes after stop/start" problem is a Basic-SKU-only quirk that's going away as Basic is phased out.

#### Answering "if I attach a VM to a VNet and reboot it, does the IP change?"

- **Private IP**: No — not with current Azure behavior. It should stay identical across reboot and stop/start, as long as the NIC isn't deleted/recreated.
- **Public IP, Standard SKU + Static**: No — never changes.
- **Public IP, Basic SKU + Dynamic**: Only on a **Stop (Deallocate) → Start**, not on a plain in-OS reboot. This is the one legacy case where the old assumption is still technically correct.

**Nitty-gritty gotchas worth remembering**:
- "Restart" (soft reboot, OS stays allocated) vs "Stop → Deallocate" (compute resources released back to Azure) are different operations with different IP implications — only the latter can affect Basic dynamic public IPs.
- The IP is a property of the **NIC**, not the VM — if your Terraform code ever forces NIC replacement (e.g. changing `subnet_id`, which requires recreating the NIC), you will get a new private IP even with `Static` allocation pointed at the same address, because it's technically a new resource.
- A static private IP still has to be free within the subnet — Terraform apply fails if another resource already holds it.

### 3.3 Terraform — Private IP (on the NIC)

Private IP allocation is configured on the Network Interface (NIC):

```hcl
resource "azurerm_network_interface" "web" {
  name                = "nic-web-01"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"   # or "Static"
    # private_ip_address          = "10.0.1.10" # required only if Static
  }
}
```

### 3.4 Terraform — Public IP (its own resource)

```hcl
resource "azurerm_public_ip" "web" {
  name                = "pip-web-01"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"   # "Dynamic" also allowed
  sku                 = "Standard" # Standard is the modern default; Basic is legacy
}
```

**Important Azure-specific quirk**: with **Standard SKU** public IPs, `allocation_method` must be `Static` (Standard doesn't support Dynamic). Basic SKU supports both but is being phased out — default to Standard.

To actually use the public IP, attach it to the NIC's `ip_configuration`:
```hcl
resource "azurerm_network_interface" "web" {
  name                = "nic-web-01"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web.id   # ← links it
  }
}
```

---

## 4. Network Security Groups (NSG)

**What it is**: A stateful firewall — a set of allow/deny rules evaluated by **priority number** (lower number = evaluated first, wins).

**Where you attach an NSG** (two options, often both):
1. **To a subnet** → rule applies to everything in that subnet.
2. **To a NIC** → rule applies to just that one VM's network interface.

**How rule evaluation works**:
- Rules have a `priority` (100–4096). Azure checks rules in ascending priority order and **stops at the first match**.
- Every NSG has invisible default rules at the bottom (priority 65000+) that:
  - Allow all traffic within the VNet
  - Allow outbound internet traffic
  - Deny everything else inbound from the internet
- You only need to write rules for exceptions to that default behavior.

**Terraform**:
```hcl
resource "azurerm_network_security_group" "web" {
  name                = "nsg-web"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "Allow-HTTPS-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"           # anyone on the internet
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-SSH-From-Bastion-Only"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.99.0/24" # only from bastion subnet, not the internet
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-All-Other-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Attach it to the web subnet
resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}
```

**Security design pattern worth remembering**: never open SSH/RDP (`22`/`3389`) to `*` (the whole internet). Either restrict `source_address_prefix` to your own IP/office range, or route through **Azure Bastion** (a managed jump box) so no VM needs a public IP at all.

---

## 5. VNet Peering

**What it is**: A private, low-latency connection between two VNets so resources in each can talk using **private IPs**, as if they were on the same network — traffic never goes over the public internet.

**When you need it**:
- Hub-and-spoke architectures (one central "hub" VNet with shared services, multiple "spoke" VNets for workloads).
- Separate VNets per environment (dev/staging/prod) that occasionally need to talk (rare, usually avoided on purpose).
- Two teams/subscriptions whose resources must communicate privately.

**Key facts**:
- Peering is **not transitive**: if VNet A ↔ VNet B and B ↔ VNet C are peered, A **cannot** reach C automatically. You'd need to peer A ↔ C directly too.
- Address spaces of peered VNets **must not overlap**.
- Peering must be created **in both directions** (one block on each VNet side) — Terraform needs two `azurerm_virtual_network_peering` resources.
- It's free for traffic within the same region; cross-region peering ("Global VNet Peering") has a small data-transfer cost but no gateway needed.

**Terraform** (peering VNet A and VNet B):
```hcl
resource "azurerm_virtual_network" "vnet_a" {
  name                = "vnet-hub"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_virtual_network" "vnet_b" {
  name                = "vnet-spoke"
  address_space       = ["10.1.0.0/16"]   # must not overlap with vnet_a
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Peering: A → B
resource "azurerm_virtual_network_peering" "a_to_b" {
  name                      = "peer-hub-to-spoke"
  resource_group_name      = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.vnet_a.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_b.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  allow_gateway_transit        = false  # true only if vnet_a is the hub with a VPN/ExpressRoute gateway
}

# Peering: B → A (the other direction — required!)
resource "azurerm_virtual_network_peering" "b_to_a" {
  name                      = "peer-spoke-to-hub"
  resource_group_name      = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.vnet_b.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_a.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
  use_remote_gateways          = false  # true only if vnet_b should use vnet_a's gateway
}
```

---

## 6. How It All Fits Together (full mini example)

A realistic 2-tier app: web subnet with a public-facing VM, db subnet with no internet access, and an NSG locking down the db tier.

```hcl
resource "azurerm_resource_group" "main" {
  name     = "rg-networking-demo"
  location = "eastus"
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-demo"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "db" {
  name                 = "snet-db"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# --- Web tier: gets a public IP ---
resource "azurerm_public_ip" "web" {
  name                = "pip-web"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "web" {
  name                = "nic-web"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web.id
  }
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-web"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

# --- DB tier: private IP only, no public IP resource at all ---
resource "azurerm_network_interface" "db" {
  name                = "nic-db"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.db.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.2.10"
    # no public_ip_address_id → unreachable from the internet
  }
}

resource "azurerm_network_security_group" "db" {
  name                = "nsg-db"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "Allow-SQL-From-Web-Subnet-Only"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "10.0.1.0/24"  # only the web subnet, nothing else
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-All-Other-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "db" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db.id
}
```

**Why this design is "correct"**:
- Only the web tier has a public IP — the internet can only ever reach the web NIC.
- The db tier has a static private IP (stable for connection strings) and no public IP resource at all.
- The db NSG only allows traffic on port 1433 **from the web subnet's CIDR**, denying everyone else — this is the segmentation NSGs + subnets are for.

---

## 7. Terms Cheat Sheet

| Term | One-line meaning |
|------|-------------------|
| **VNet** | Your private network in Azure, defined by a CIDR block, scoped to one region |
| **Subnet** | A slice of the VNet's address space; resources live inside subnets |
| **NIC** | Network Interface — the virtual "network card" attached to a VM; holds the private (and optionally public) IP |
| **Private IP** | Internal address, only reachable inside the VNet (or peered/connected networks) |
| **Public IP** | Internet-reachable address; a separate billable resource you attach to a NIC or load balancer |
| **Static allocation** | The IP never changes for the resource's lifetime |
| **Dynamic allocation** | Azure may reassign the IP when the resource restarts |
| **NSG** | Stateful firewall — allow/deny rules by priority, attached to a subnet and/or NIC |
| **Security rule priority** | Lower number = evaluated first; first match wins |
| **VNet Peering** | Private connection between two VNets; not transitive; needs a peering resource on each side |
| **CIDR** | Notation for an address range, e.g. `/24` = 256 addresses, smaller `/number` = bigger range |
| **Azure Bastion** | Managed jump-box service so you never need to give a VM a public IP just for SSH/RDP |

---

## 8. Suggested Practice Order

1. Deploy a single VNet with one subnet — nothing else. `terraform apply`, inspect it in the Azure Portal.
2. Add a second subnet, confirm both subnets can reach each other without any NSG (Azure's default behavior).
3. Add an NSG to one subnet that blocks something (e.g. deny all inbound), verify a resource in that subnet becomes unreachable.
4. Add a public IP to a NIC, then remove it, and see the resource lose internet reachability.
5. Create two VNets with non-overlapping address spaces and peer them; verify a VM in one can ping a private IP in the other.

**Where to build this**: use this folder — `07-AzureVirtualNetworks/` — for your `main.tf` / `variables.tf` / `outputs.tf` as you work through the steps above.
