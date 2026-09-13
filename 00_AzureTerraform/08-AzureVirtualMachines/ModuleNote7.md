# Why a Public IP for a VM?

A NIC only gets a private VNet IP by default. To reach a VM from the internet, attach an `azurerm_public_ip` to the NIC's `ip_configuration.public_ip_address_id`.

**Need it for:**
- Direct RDP/SSH access (no bastion/VPN)
- Hosting a public-facing service (web server, API, etc.)

**Don't need it for:**
- Outbound-only traffic — Azure gives default outbound access without a public IP (use NAT Gateway for production outbound instead)
- VM behind a Load Balancer/App Gateway — the LB holds the public IP, not the VM
- Access via Bastion, VPN Gateway, or ExpressRoute — private IP is enough
- Internal/backend tier in a multi-tier setup

**Lab tip:** make it optional with a variable, e.g. `enable_public_ip = false` for private-only VMs.

---

# VM Provisioning Flow (Order & Why)

Each step exists because of a real dependency — skipping or reordering these either breaks `terraform apply` or leaves the VM unreachable:

| Step | Component | Why it's needed |
|---|---|---|
| 1 | **Resource Group** | Container everything else lives in |
| 2 | **VNet + Subnet** | The private network the VM's NIC will join |
| 3 | **NSG + Association** | Firewall rules controlling what can reach the VM |
| 4 | **Public IP** *(optional)* | Only if the VM needs internet reachability |
| 5 | **NIC** | The "network card" that holds the IP(s) and links VM ↔ subnet |
| 6 | **SSH key / credentials** | How you'll authenticate once network access is allowed |
| 7 | **VM resource itself** | References NIC + image + disk + size + credentials |
| 8 | **Outputs** | Surface the IP/connection info after apply |

---

# Public IP on NIC — How the Connection Actually Flows

**Chain:** `Your laptop → Internet → Public IP → NIC → VM`

- The Public IP is a **separate Azure resource**, not something literally "inside" the VM or NIC — it gets *associated* with the NIC's IP configuration.
- The **NIC** is the actual network interface attached to the VM (a VM can have multiple NICs). It always has a **private IP**, and *optionally* a public IP linked to it.
- Once associated, Azure's network fabric does **1:1 NAT**:
  - Inbound: traffic hitting the public IP gets translated to the NIC's private IP and delivered to the VM.
  - Outbound: traffic leaving the VM's private IP gets translated back to the public IP.

**RDP/SSH connection walkthrough:**
1. You RDP/SSH to the VM's public IP from your laptop.
2. Azure's edge network sees that public IP is mapped to a specific NIC (via its IP configuration).
3. Traffic is NAT'd to the NIC's private IP and delivered toward the VM.
4. The NSG (attached at the NIC and/or subnet level) checks its rules — enforced *before* the packet reaches the VM's OS.
5. If allowed, the VM's RDP/SSH service (listening on the private IP) accepts the connection.

**Two independent requirements for remote access to work — both must be true:**
- **Reachability**: Public IP (or Bastion/VPN/ExpressRoute) — gives a path into Azure's network at all.
- **Permission**: NSG rule allowing the port (22/3389) — permits the traffic once it arrives.

Opening the NSG port without a public IP (and no Bastion/VPN) does nothing — there's no route in yet. Attaching a public IP without an NSG rule also does nothing — the NAT'd packet just gets dropped at the firewall.

**Nuance:** NSGs can be attached at the **NIC level** and/or the **subnet level**. Traffic must pass both if both exist — a common "why is this still blocked" gotcha is a subnet-level NSG denying traffic even though the NIC-level NSG allows it.

---

# Locking Down Source IP on NSG Rules (`data "http" "myip"`)

```hcl
data "http" "myip" {
  url = "https://ifconfig.me/ip"
}

security_rule {
  ...
  source_address_prefix = chomp(data.http.myip.body)
}
```

- `source_address_prefix = "*"` on an inbound SSH/RDP rule means **anyone on the internet** can attempt to connect — a wide-open attack surface (bots constantly scan cloud IP ranges for open 22/3389).
- This `data` block fetches your current public IP at `terraform apply` time from `ifconfig.me/ip` (a service that echoes back the caller's public IP as plain text), then uses it as the allowed source instead of `"*"` — locking the rule to only your laptop's IP.
- `chomp(...)` strips the trailing newline from the HTTP response body, since `source_address_prefix` needs a clean IP string.

**Caveat:** the IP is resolved at `apply` time. If your ISP assigns a dynamic IP and it changes, you must re-`apply` to refresh the rule or you'll get locked out. Fine for personal labs; in a real team setup, prefer a known office IP range, VPN, or Bastion over a single dynamically-fetched IP.

---

# No Public IP on NIC — Is the VM Reachable?

**No public IP ≠ unreachable. It means "not reachable from the public internet directly."** The VM is still fully reachable via private connectivity:

- **From your laptop (outside Azure) directly:** ❌ No route in — RDP/SSH/ping will simply time out.
- **From another VM in the same VNet:** ✅ Works (private IP to private IP, subject to NSG rules).
- **From a VM in a peered VNet:** ✅ Works, if VNet peering is configured (again, subject to NSG rules).
- **Via Azure Bastion:** ✅ Works — Bastion connects to the VM's private IP internally; you reach Bastion itself over HTTPS through the Azure Portal, so no public IP on the VM is ever needed.
- **Via VPN Gateway / ExpressRoute:** ✅ Works — extends your on-prem/laptop network into the VNet, making the private IP directly reachable as if you were on the same network.

**Good security practice for labs/prod:** don't attach a public IP to the VM at all. Rely on Bastion (or VPN) for management access, and keep the VM's attack surface limited to the private network.

---

# `tls_private_key` — SSH Key Generation

- Generates an SSH key pair at `apply` time (`algorithm = "RSA"`, `rsa_bits = 4096`) instead of requiring a pre-existing `~/.ssh/id_rsa.pub`. Public key (`public_key_openssh`) feeds into `admin_ssh_key.public_key` on the VM; private key (`private_key_pem`) is what you SSH in with.
- **Print/save it:**
  ```hcl
  output "vm1_public_key"  { value = tls_private_key.vm1.public_key_openssh }
  output "vm1_private_key" { value = tls_private_key.vm1.private_key_pem; sensitive = true }
  ```
  View with `terraform output -raw vm1_private_key`. Better: write it to a file so you keep a usable copy:
  ```hcl
  resource "local_file" "vm1_private_key" {
    content         = tls_private_key.vm1.private_key_pem
    filename        = "${path.module}/vm1_key.pem"
    file_permission = "0600"
  }
  ```
  Then `ssh -i vm1_key.pem azureuser@<public-ip>`.
- **You need the private key every time you SSH in** — it's not one-time setup, it's your ongoing credential (like a password, just asymmetric). Lose it → locked out (no password fallback unless configured).
- **Caveat:** private key ends up in Terraform state (plaintext unless backend is encrypted) — a real prod concern. Prefer bringing your own pre-generated public key via `file("~/.ssh/id_rsa.pub")` so Terraform never touches/stores the private key.
- **Bug fix:** `local_file.public_key` should write `public_key_openssh`, not `public_key_pem` — the `.pub` file needs OpenSSH format to be usable as an `authorized_keys`-style entry. `public_key_pem` is X.509/PEM format and isn't valid for that purpose.

---

# How to SSH Into the VM (after `terraform apply`)

1. **Get the public IP:**
   ```bash
   terraform output -raw public_ip_address
   ```
2. **SSH using the private key Terraform saved to `~/.ssh/vm1`:**
   ```bash
   ssh -i ~/.ssh/vm1 adminuser@<public-ip>
   ```
   (`adminuser` must match `admin_username` / `admin_ssh_key.username`.)
3. **On Windows (PowerShell/Git Bash)**, if `~` doesn't expand correctly, use the full path:
   ```powershell
   ssh -i C:\Users\Avaneesh\.ssh\vm1 adminuser@<public-ip>
   ```

**Checklist if it hangs/fails:** NSG must allow port 22 inbound from your current IP; private key file permissions may need tightening on some setups; public IP must actually be attached (see earlier section).


## Note:
Right now our vm1 is connected to snet1 and we are loging in using ssh key which is not a ideal way to do as per security practices. There are other ways to access the vm1 using secure way like azure bastion as it uses private ip of nic internally.

we want to allocate snet1 to azure bastion but to do so we have to disassosiate our snet1 from vm1 which can be done without even deleting vm. Basically we will update the referance of nsg or nic into snet2 leaving our snet1 available or bastion service.

---

# Azure Bastion — Subnet Requirements

- Needs a **dedicated subnet named exactly `AzureBastionSubnet`** — Azure looks for this specific name.
- Recommended size: **`/26`** (64 addresses) — current Microsoft recommendation to accommodate host scaling (`/27` was the old documented minimum).
- Cannot be shared with any other resource — no VMs, no other NICs in that subnet.
- NSG on that subnet must not block Bastion's required ports (443 inbound from Internet; outbound 3389/22 to target VNet; plus a few Azure-internal management ports).
