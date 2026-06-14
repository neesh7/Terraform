# 5. Terraform State — *14:14*

| # | Topic | Duration |
|---|-------|----------|
| 1 | Introduction to Terraform State | 05:28 |
| 2 | Purpose of State | 06:06 |
| 3 | Lab: Terraform State | — |
| 4 | Terraform State Considerations | 02:40 |

## Notes

### 1. Usual Terraform Workflow

```
Write .tf files  →  terraform init  →  terraform plan  →  terraform apply  →  terraform destroy
```

| Step | Command | What happens |
|------|---------|-------------|
| Write config | *(edit .tf files)* | Define resources in HCL |
| Initialize | `terraform init` | Downloads providers, sets up backend |
| Preview | `terraform plan` | Shows what will be created/changed/destroyed |
| Apply | `terraform apply` | Creates/updates real infrastructure, writes state |
| Destroy | `terraform destroy` | Tears down all managed resources, updates state |

---

### 2. What is Terraform State (`terraform.tfstate`)?

After `terraform apply`, Terraform creates a file called **`terraform.tfstate`** in the working directory. This is a JSON file that records the **current state of all managed resources**.

```json
{
  "resources": [
    {
      "type": "local_file",
      "name": "my-pet",
      "instances": [
        {
          "attributes": {
            "filename": "/root/pets.txt",
            "content":  "My favourite pet is MR.happy-tiger"
          }
        }
      ]
    }
  ]
}
```

---

### 3. Why is State Important?

**1. Tracks real-world infrastructure**
Terraform doesn't query the cloud on every run — it reads `.tfstate` to know what already exists. This makes operations fast and avoids unnecessary API calls.

**2. Detects drift (plan = desired vs state = actual)**
On `terraform plan`, Terraform compares:
```
.tf files (desired state)  vs  .tfstate (actual state)
```
Any difference = a change that needs to be applied.

**3. Tracks dependencies**
State records the relationship between resources so Terraform knows the correct order to create or destroy them.

**4. Performance**
For large infrastructures with hundreds of resources, reading state locally is far faster than querying every resource from the cloud provider each time.

---

### 4. Purpose of Terraform State

**1. Single source of truth for infrastructure**
State is the record of what Terraform actually created. It maps each resource block in your `.tf` files to the real resource in the cloud/system — including its ID, attributes, and metadata.

**2. Mapping configuration to real-world resources**
When you write:
```hcl
resource "local_file" "my-pet" {
    filename = "/root/pets.txt"
}
```
Terraform uses state to remember that *this block* corresponds to *that specific file* on disk. Without state, Terraform wouldn't know whether to create a new file or update the existing one.

**3. Calculating the diff on every plan**
```
Desired state (.tf files)  −  Current state (.tfstate)  =  Changes to apply
```
`terraform plan` computes this diff — state is what makes incremental updates possible instead of recreating everything from scratch on every run.

**4. Tracking metadata and dependencies**
State stores dependency ordering and resource metadata that isn't available from the provider API alone — e.g. which resources must be destroyed first.

**5. Performance — avoid querying all resources every time**
In large setups Terraform reads state locally instead of making API calls to inspect every resource. Only changed resources trigger provider calls.

#### How State Boosts Performance in Large Infrastructure

In a large setup with hundreds or thousands of resources (EC2 instances, S3 buckets, IAM roles, VPCs etc.), querying every single resource from the cloud provider on every `terraform plan` would be extremely slow — each resource requires a separate API call.

**Without state:**
```
terraform plan  →  query 500 resources via API  →  slow, rate-limited, expensive
```

**With state:**
```
terraform plan  →  read .tfstate locally  →  compare diff  →  only query resources that changed
```

Terraform uses the state file as a **cache** — it already knows the last known attributes of every resource, so it only needs to call the provider API for resources where a change is detected.

#### `terraform plan --refresh=false`

By default, `terraform plan` **refreshes** state — it calls the provider API to check the real current state of every resource and updates `.tfstate` before computing the diff. This ensures accuracy but is slow for large infra.

```bash
terraform plan --refresh=false
```

- **Skips the refresh step entirely** — Terraform trusts the existing `.tfstate` as-is without making any provider API calls.
- The diff is computed purely from `.tf` files vs the last known state in `.tfstate`.
- **Much faster** for large infra where you know nothing has changed outside of Terraform.

| | Default `terraform plan` | `terraform plan --refresh=false` |
|--|--------------------------|----------------------------------|
| Queries provider API | Yes — for every resource | No |
| Speed | Slower (scales with resource count) | Fast (reads local state only) |
| Accuracy | Always up to date | May miss out-of-band changes |
| When to use | When drift is possible | When you trust state is current |

> **Out-of-band change** — a change made directly in the AWS console, CLI, or by another tool outside Terraform. `--refresh=false` won't detect these. Use with caution in shared environments.

---

### 5. Team Collaboration with Remote State

By default, `terraform.tfstate` is stored **locally** on the machine that ran `terraform apply`. This works fine for solo work but breaks down in teams:

**Problems with local state in teams:**
- Team member A applies → state saved on A's machine.
- Team member B runs plan → B has no state → Terraform thinks nothing exists → tries to recreate everything.
- Two people apply at the same time → **state corruption**.

#### Solution — Remote Backend

Store state in a shared remote location so the whole team reads and writes the same state file.

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket = "my-terraform-state-bucket"
    key    = "project/terraform.tfstate"
    region = "us-east-1"
  }
}
```

Popular remote backends:

| Backend | Provider |
|---------|----------|
| S3 + DynamoDB | AWS |
| GCS | Google Cloud |
| Azure Blob Storage | Azure |
| Terraform Cloud / HCP Terraform | HashiCorp |

#### State Locking

When a remote backend is configured, Terraform **locks** the state file during `apply` — no one else can run apply at the same time, preventing concurrent writes and corruption.

```
Team member A runs apply  →  state locked  →  Team member B tries apply  →  blocked until A finishes
```

- AWS S3 backend uses **DynamoDB** for locking.
- Terraform Cloud handles locking automatically.

#### Benefits of Remote State in Teams

| Benefit | Detail |
|---------|--------|
| **Shared single source of truth** | Everyone works from the same state |
| **State locking** | Prevents concurrent apply conflicts |
| **Access control** | IAM / bucket policies control who can read/write state |
| **Versioning** | S3 versioning lets you roll back to a previous state |
| **Sensitive data protection** | State stays off developer laptops, reducing exposure |

> Never store `terraform.tfstate` in git — it can contain secrets and causes merge conflicts. Always use a remote backend for team projects.

---

### 6. State Considerations

#### State is Non-Optional

Terraform state is **not a feature you can turn off** — it is a core part of how Terraform works. Every `terraform apply` reads and writes state. Without it, Terraform has no way to know what infrastructure already exists or what needs to change.

#### State Contains Sensitive Data

State files store the full attributes of every managed resource — this often includes:
- Database passwords
- API keys and tokens
- Private IP addresses
- TLS certificates

Because of this, state must always be stored in **secure storage** with proper access controls, not left on a developer's local machine.

#### Configuration Files vs State File

| | Configuration Files (`.tf`) | State File (`terraform.tfstate`) |
|--|---------------------------|----------------------------------|
| **Stored in** | Version control (GitHub, Bitbucket etc.) | Remote backend (S3, GCS, Terraform Cloud) |
| **Shared via** | Git commits and PRs | Backend access (IAM, bucket policies) |
| **Contains** | Desired infrastructure definition | Actual current state + sensitive attributes |
| **Safe to commit?** | Yes | **Never** |

In a team setup, `.tf` configuration files live in a shared repo so everyone can collaborate on infrastructure code. The state file is kept separately in a remote backend — never in version control — due to its sensitive nature.

#### State is for Terraform's Internal Use Only

The state file is a **JSON data structure maintained by Terraform** — it is not designed to be read or edited by humans directly. Manually editing `terraform.tfstate` can:
- Break resource mappings
- Cause Terraform to recreate or destroy resources unexpectedly
- Corrupt the state entirely

#### Making Changes to State — Use Terraform Commands

There are situations where you legitimately need to modify state (renaming a resource, moving it to a module, removing a resource from management etc.). In these cases, **always use Terraform's built-in commands** rather than editing the file directly:

```bash
terraform state list                        # list all resources in state
terraform state show <resource>             # inspect a specific resource
terraform state mv <source> <destination>   # rename or move a resource in state
terraform state rm <resource>               # remove a resource from state without destroying it
terraform import <resource> <id>            # import an existing resource into state
```

> The golden rule: **never touch `terraform.tfstate` with a text editor.** Let Terraform manage it — use `terraform state` commands for any manual interventions.

| Consideration | Detail |
|---------------|--------|
| **Do not edit manually** | State is managed by Terraform — manual edits corrupt it |
| **Store remotely in teams** | Use S3, GCS, or Terraform Cloud so the whole team shares one state |
| **State locking** | Remote backends lock state during apply to prevent concurrent writes |
| **Sensitive data** | State may contain secrets (passwords, keys) — treat it like a secret file |
| **Gitignore it** | Never commit `terraform.tfstate` to version control — add to `.gitignore` |

> The `.gitignore` in this repo already excludes `*.tfstate` and `*.tfstate.*`.
