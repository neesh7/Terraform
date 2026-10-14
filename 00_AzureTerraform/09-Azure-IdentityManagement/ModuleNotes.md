## 
In last module, we've provided access to terraform user but better practice is to provide access to a group instead of individual as per identity standpoint.

Special Entra ID Provider -> Azure Actionve Directory Provider (AAD)

---

## Microsoft Entra vs Azure

- **Microsoft Entra ID** (formerly Azure Active Directory, renamed in 2023) is the identity service. It manages users, groups, apps, service principals, MFA, conditional access, and SSO.
- **Azure** is the cloud platform. It runs resources such as VMs, VNets, storage, and Key Vault, and it is managed through Azure Resource Manager.
- An Azure subscription trusts one Entra tenant. Azure logins and resource access are both backed by Entra identities.
- **Two separate permission systems:**
  - Entra directory roles (e.g., Global Administrator, User Administrator) control the directory.
  - Azure RBAC roles (e.g., Owner, Contributor, Reader) control Azure resources.
  - Owner on a subscription does not make someone a Global Administrator, and vice versa.

## Login methods for VMs

| Method | How it works | When to use |
|---|---|---|
| SSH key + Key Vault + Bastion | VM trusts a public key. Private key is stored in Key Vault. Bastion provides the network path. | Labs, quick setups. Key is a shared secret, so no individual audit trail. |
| Entra ID + VM extension + RBAC | `AADSSHLoginForLinux` (Linux) or `AADLoginForWindows` (Windows) lets the VM accept Entra tokens. RBAC decides who can log in. | Production. Per-user identity, audit logs, MFA, offboarding by group membership. |
| Entra ID + security group | Security group in Entra is the set of users. It gets an RBAC role on the VM. | Production pattern, combined with the row above. |

RBAC roles for VM login:
- **Virtual Machine User Login**: standard login.
- **Virtual Machine Administrator Login**: login with sudo / admin rights.

Connect with `ssh user@domain.com@<ip>` or through Bastion.

Bastion is a transport, not an auth method. It works with either SSH keys or Entra login.

## Why security groups instead of individual users

- Access changes happen in one place: add or remove group membership.
- Role assignments go to the group, not to each user, so VMs and subscriptions stay clean.
- Offboarding is a single membership removal.
- Matches how teams are organised.

## The AzureAD provider (`azuread`)

- The "Azure Active Directory provider" in older notes is the **`azuread` provider** (`hashicorp/azuread`) in Terraform. Entra was renamed, the provider name was not changed to match.
- It manages Entra objects as code:
  - `azuread_user`, `azuread_group`, `azuread_group_member`
  - `azuread_application`, `azuread_service_principal`
- It needs Entra directory permissions (Microsoft Graph API permissions such as `Group.ReadWrite.All`, or a directory role). These are separate from Azure subscription roles, so the identity running Terraform may need both.
- **Why use it:** identity is version-controlled, reviewed, and deployed the same way as infrastructure. Groups and their memberships don't have to be created by hand in the portal, and dependencies (group -> role assignment -> VM) are expressed in code.

Example:
```hcl
resource "azuread_group" "vm_admins" {
  display_name     = "grp-vm-admins"
  security_enabled = true
}

resource "azurerm_role_assignment" "vm_admin_login" {
  scope                = azurerm_linux_virtual_machine.vm1.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = azuread_group.vm_admins.object_id
}
```

## Best practices

- **Assign roles to groups, not users.**
- **Least privilege:** give User Login by default, Administrator Login only where needed.
- **Use PIM (Privileged Identity Management)** for just-in-time admin roles instead of standing access.
- **Enforce MFA and conditional access** on VM login and on the Azure portal.
- **Keep a break-glass account** that is excluded from conditional access, in case Entra or policies fail.
- **Use managed identities** for VMs and services that need to call Azure, instead of stored credentials.
- **Don't store long-lived secrets** in code or state. Use Key Vault, and mark outputs sensitive.
- **Use a dedicated Terraform identity** (service principal or workload identity) with the minimum Graph and Azure roles it needs.
- **Review access regularly** with Entra access reviews.
- **Secure remote state**, since it can contain sensitive values.

