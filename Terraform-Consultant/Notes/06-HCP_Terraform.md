# HCP Terraform

## 1. What is HCP Terraform?

### Definition
**HCP Terraform** (formerly **Terraform Cloud**) is HashiCorp's **managed SaaS platform** for running Terraform. Runs, state, variables, secrets and policies live in **one shared, central place**, instead of each engineer running `terraform apply` from their own laptop with their own state.

| Product | Hosting |
|---|---|
| **HCP Terraform** | SaaS, hosted by HashiCorp (`app.terraform.io`) |
| **Terraform Enterprise** | **Self-hosted** version of the same product (for air-gapped or regulated companies) |

### The Problem It Solves
| Problem with local CLI | How HCP Terraform fixes it |
|---|---|
| Everyone has their own state, or the remote backend is set up by hand | **Remote state** built in: encrypted, versioned, **locked automatically** |
| "Works on my machine": different Terraform/provider versions and credentials | **Remote runs** in a consistent, HashiCorp-managed environment |
| Secrets sit in `.tfvars` files on laptops | **Workspace variables**, which can be marked **sensitive** (write-only, hidden in the UI and logs) |
| Nobody reviews changes before apply | **VCS integration**: a PR triggers a **speculative plan**, a merge triggers the apply |
| No guardrails on what gets deployed | **Policy as code** (**Sentinel** / **OPA**) checked between plan and apply |
| Anyone can apply to prod | **Teams and RBAC** permissions per workspace / project |
| Modules shared by copy-paste | **Private Registry** for the org's modules and providers |
| No idea what changed outside Terraform | **Drift detection / health assessments** |
| No audit trail | Run history and audit logs |

---

## 2. The 4 Primary Capabilities
| # | Capability | What it gives you |
|---|---|---|
| 1 | **Secure Remote State Storage** | State stored centrally, **encrypted at rest**, **versioned** (roll back / compare), **automatic locking**. No backend (S3 + DynamoDB etc.) to set up yourself |
| 2 | **Team Collaboration** | Shared workspaces, **teams and RBAC permissions**, run history, comments/approvals, Private Registry for sharing modules |
| 3 | **Remote Execution** | `plan` / `apply` run on **HashiCorp-managed workers** (or self-hosted **Agents**), so every run uses the same environment, Terraform version and credentials. Logs stream back to the CLI/UI |
| 4 | **Governance & Policy** | **Policy as code** (**Sentinel** / **OPA**) enforced **after plan, before apply**. Also cost estimation, run tasks, audit logs |

> **Memory trick:** **S-T-R-G** → **S**tate, **T**eam, **R**emote runs, **G**overnance

---

## 3. Terraform Community vs HCP Terraform
HCP Terraform **does not replace** Terraform. It runs the **same Terraform** and **adds** platform features on top.

| Terraform Community (CLI) gives you | ➕ HCP Terraform adds |
|---|---|
| Define infrastructure as code (HCL) | **Managed remote state storage** |
| Free and **"code-available"** (BSL licence, not open source) | **Consistent execution environments** (remote runs) |
| Rich set of integrations (**providers**) | **Built-in team collaboration** |
| Reusable modules (**public registry**) | **Role-based access control (RBAC)** |
| Ability to **plan** out your changes | **Policy enforcement** (**Sentinel / OPA**) |
| **Local** execution and control | **Cost estimation** before apply |
| | **Audit logs** and compliance |
| | **Private module registry** |

> **Exam trap:** the **public** registry comes with Terraform Community. The **private** registry is an HCP Terraform feature.

---

## 4. Key Use Cases
1. **Team collaboration**: shared state, locking and run history, so only one apply runs at a time
2. **GitOps workflow**: connect a GitHub/GitLab repo so that push → plan → approve → apply
3. **Governance and compliance**: Sentinel/OPA policies (e.g. "no public S3 buckets", "only approved instance sizes") plus cost estimation
4. **Secure secret handling**: sensitive variables, and **dynamic provider credentials (OIDC)** instead of static keys
5. **Self-service**: **no-code provisioning** lets non-Terraform users deploy approved modules
6. **Private infrastructure**: **HCP Terraform Agents** run plans/applies inside your private network

---

## 5. Structure (Exam Favourite)
```
Organization  →  Projects  →  Workspaces
```
### What is an HCP Terraform Workspace?
> **A workspace is everything Terraform needs to manage a collection of infrastructure.**

| Component | Details |
|---|---|
| **Terraform configuration** | **Linked via VCS** or **uploaded via CLI** |
| **State file** | With **version history** and **rollback** capability |
| **Variables** | **Terraform variables** + **environment variables**, with **sensitive** marking |
| **Run history** | **Full audit trail** of every plan/apply |
| **Execution settings** | **Mode** (remote/local/agent), **Terraform version**, **auto-apply** |
| **Team access** | Permissions per team |

### How Workspaces Are Organized
One organization holds **many workspaces**. Each workspace maps to **one Terraform configuration** (one component of the infra):
```
                          ┌── networking-prod  ──►  Terraform config (networking)
                          │
HCP Terraform  ───────────┼── app1-prod        ──►  Terraform config (app1)
Organization              │
                          ├── monitoring-prod  ──►  Terraform config (monitoring)
                          │
                          └── db1-prod         ──►  Terraform config (db1)
```
- Split infra by **component + environment** (e.g. `networking-prod`, `networking-dev`), not one giant workspace
- Smaller workspaces = **smaller blast radius**, faster runs, separate permissions per team

### Inside a Workspace (VCS-connected example)
```
┌──────────────── Networking Workspace ────────────────┐
│  Variables           Terraform Configuration ────────┼── VCS Connection ──►  Git Repository
│  Terraform Version                                    │                       (GitHub, Bitbucket, etc.)
│  Run History                                          │                              ▲
│  Permissions         State File (Encrypted-at-Rest)   │                              │ Commits /
└───────────────────────────────────────────────────────┘                              │ Pull Requests
                                                                               Developer / DevOps Engineer
```
- The developer **never runs Terraform locally**. They **commit / open PRs** to the Git repo
- The workspace's **VCS connection** pulls the configuration and triggers runs (PR → speculative plan, merge → plan + apply)
- **State file is encrypted at rest** inside the workspace

> 📌 **Workspaces can be connected to GitHub** (also GitLab, Bitbucket, Azure DevOps). Org **Settings → VCS Providers** → add GitHub, then in the workspace pick **Version Control Workflow** → select the repo (+ branch / working directory). After that, **every push/PR triggers a run automatically**, with no CLI needed.

### CLI Workspaces vs HCP Terraform Workspaces
**Same name, fundamentally different concept.**

| CLI Workspaces | HCP Terraform Workspaces |
|---|---|
| **Same configuration, multiple state files** | **Complete working environments** |
| Managed **locally** with `terraform workspace` | Managed through **HCP Terraform (UI, CLI, or API)** |
| **Lightweight state isolation** only | **Config + state + variables + settings + credentials + run history** |

⚠️ **Exam trap:** a CLI workspace only gives a **separate state file** in the same backend. An HCP Terraform workspace is a **full, independent environment** (usually one per environment/component, e.g. `networking-dev`, `networking-prod`)

### Workspace Sprawl (the problem)
As your organization grows, you end up with a flat pile of workspaces (`networking-dev`, `web-prod`, `hr-dev`, `monitoring-qa`, `db1-dev`...):
- **Workspaces become unmanageable**
- **Making changes one workspace at a time**
- **No clean way to separate team boundaries**
- **Duplicating efforts** (same variables/permissions set again and again)

**Fix → group workspaces into Projects:**
```
Development Project          Quality Assurance Project      Production Project
├── cache-dev                ├── monitoring-qa              ├── processing-prod
├── networking-dev           └── call-center-qa             ├── customer-data-prod
├── hr-dev                                                  ├── web-prod
├── db1-dev                                                 ├── app21-prod
└── security-dev                                            └── app1-prod
```

### Projects – The Organizational Layer
| Layer | What it is |
|---|---|
| **Organization** | **Top-level account** in HCP Terraform. Holds all **teams, projects and workspaces**. Where you set **org-wide settings** |
| **Project** | **Groups related workspaces**. Lets you scope **team permissions**, **variable sets** and **execution modes** to a collection of workspaces |
| **Workspace** | The **individual unit** that manages a specific set of infrastructure. Has its own **config, state, variables and run history** |

### Project Rules (Exam Favourite)
- **Every workspace belongs to exactly ONE project**. Can't belong to two, can't belong to none
- **Default Project**: every org gets one **automatically**. You **can rename it but can't delete it**
- **Scoped team permissions**: grant a team access to an **entire project** instead of workspace-by-workspace (**least privilege**)
- **Project-level variable sets**: apply variables (like **cloud credentials**) to **all current AND future workspaces** in the project automatically
- **Execution mode inheritance**: set it at the **project** level. **Workspace inherits from project → project inherits from org** (`Org → Project → Workspace`, each level can override)
- **Move workspaces** between projects anytime, and **specify a project in the `cloud` block** (`workspaces { project = "..." }`, **Terraform 1.6+**)
- **Only EMPTY projects can be deleted** (move or delete its workspaces first)

### Variable Sets
> A **variable set** is a **reusable group of variables** defined **once** and applied to **many workspaces** (instead of re-entering them in every workspace).

**Can contain both variable categories:**
| Category | Example | Used as |
|---|---|---|
| **Terraform variable** | `region = "centralindia"` | `var.region` in config |
| **Environment variable** | `ARM_CLIENT_SECRET`, `AWS_ACCESS_KEY_ID`, `TF_LOG` | Env var on the run worker (provider credentials) |

Any variable can be marked **sensitive** → **write-only**: hidden in UI, API and logs, can't be read back, only replaced.

**Variable Set Scopes: where a variable set applies**
| Scope | Applies to | New workspaces covered automatically? | Typical use |
|---|---|---|---|
| **Global** | **Every workspace in the org** | ✅ Yes | Org-wide values: default tags, `TF_LOG`, a shared monitoring API key |
| **Project** | **All workspaces in the selected project(s)**. One set can be scoped to **multiple projects** | ✅ Yes (when created in / moved into that project) | **Per-environment cloud credentials** (prod creds → Production project) |
| **Workspace** | Only the **specific workspaces you select** | ❌ No, you must add each new workspace | One-off or shared values for a few unrelated workspaces |

```
Organization ─────────── Global set  (applies to ALL workspaces)
   ├── Project: Dev ──── Project set (applies to all Dev workspaces)
   │     ├── cache-dev
   │     └── db1-dev ─── Workspace set (applies only to selected workspaces)
   └── Project: Prod ─── Project set (applies to all Prod workspaces)
         ├── web-prod
         └── app1-prod
```

**Scope rules:**
- A workspace can receive **many** variable sets at once (global + project + workspace-scoped)
- When the same key appears at different scopes, the **more specific scope wins**: **Workspace-scoped > Project-scoped > Global**
- Moving a workspace to another project → it **drops** the old project's sets and **picks up** the new project's sets
- Scope can be **changed later** (e.g. switch a set from Global to a single Project)
- **Best practice:** use **Project** scope for credentials (least privilege). Avoid putting secrets in **Global** sets, since every workspace gets them

**Example:**
```
Variable set "azure-prod-creds"  (ARM_CLIENT_ID, ARM_CLIENT_SECRET🔒, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID)
        │  scoped to
        ▼
Production Project ──► web-prod, app1-prod, db1-prod ... + any NEW prod workspace automatically
```

### Variable Precedence in HCP Terraform
When the **same variable** is set in multiple places, the **highest** one wins:

| # | Source | Group |
|---|---|---|
| 1 | **Priority global** variable sets | 🔒 Priority (enforced) |
| 2 | **Priority project-scoped** variable sets | 🔒 Priority |
| 3 | **Priority workspace-scoped** variable sets | 🔒 Priority |
| 4 | **Command-line** `-var` / `-var-file` (run-specific) | Run |
| 5 | **Local env vars** `TF_VAR_*` | Run |
| 6 | **Workspace-specific variables** (set on the workspace itself) | Workspace |
| 7 | **Workspace-scoped** variable sets | Variable sets |
| 8 | **Project-scoped** variable sets | Variable sets |
| 9 | **Global** variable sets | Variable sets |
| 10 | `*.auto.tfvars` files in the config | Files |
| 11 | `terraform.tfvars` file in the config | Files (lowest) |

**How to remember it:**
```
PRIORITY sets  >  CLI (-var, TF_VAR_)  >  Workspace variable  >  Normal sets (workspace > project > global)  >  .tfvars files
```
- **Normal variable sets:** **more specific wins** (workspace-scoped > project > global)
- **Priority variable sets:** the order is **reversed**, so **global wins** (the admin's enforced org-wide value can't be overridden lower down)
- A **workspace's own variable** overrides any **normal** variable set
- **Priority sets override everything**, even workspace variables and `-var`. Admins use them to **enforce** values (e.g. mandatory region or tags)
- `.tfvars` files committed in the repo are the **lowest**. Anything set in HCP Terraform beats them

**Compare: Terraform Community (CLI) precedence**, highest first (see Notes 01):
```
-var / -var-file (last one wins)  >  *.auto.tfvars (alphabetical)  >  terraform.tfvars.json  >  terraform.tfvars  >  TF_VAR_*  >  default
```
⚠️ **Exam traps:**
- In plain CLI, `TF_VAR_*` is **near the bottom**. In HCP Terraform it ranks **above** workspace variables
- **Priority** is the only way to stop `-var` from overriding a value

**Advantages**
| Advantage | Why it matters |
|---|---|
| **DRY / no duplication** | Define credentials once, not in 50 workspaces (fixes the "duplicating efforts" sprawl problem) |
| **Centralized secret rotation** | Rotate a cloud key in **one place** → every workspace gets the new value on its next run |
| **Auto-applies to new workspaces** | Global / project-scoped sets cover workspaces created **later**, so nothing gets missed |
| **Security & separation of duties** | Platform/admin team owns the credentials. App teams **use** them without **seeing** them (sensitive) |
| **Consistency** | Same region, tags, provider settings across an environment |
| **Enforcement** | **Priority** sets stop workspaces from overriding critical values |

⚠️ **Exam traps:**
- Variable sets (and workspace variables) are **NOT evaluated in Local execution mode**
- Sensitive variables are **write-only**. Nobody can view them after saving, including admins
- Workspace variable **beats** a normal variable set. Only a **priority** set beats the workspace variable

---

## 6. The HCP Terraform Workflow

### Core flow: Write → Plan → Apply (now run by the platform)
```
Write code  →  Push / trigger  →  Plan (remote)  →  Cost estimate  →  Policy check  →  Approve  →  Apply (remote)  →  State saved in HCP
```

### Run stages (in order)
| # | Stage | What happens |
|---|---|---|
| 1 | **Pending** | Run is queued. **Only one run applies per workspace at a time** (built-in locking) |
| 2 | **Plan** | `terraform plan` runs on remote workers using the workspace's variables and credentials |
| 3 | **Cost Estimation** | Shows the estimated monthly cost change (if enabled) |
| 4 | **Policy Check** | **Sentinel / OPA** policies evaluated against the plan. A failed **mandatory** policy blocks the apply |
| 5 | **Confirm** | **Manual approval** (default) or **auto-apply** (workspace setting) |
| 6 | **Apply** | `terraform apply` runs remotely. The new state is stored and versioned in the workspace |

- **Run tasks** can hook in third-party tools (security scanners etc.) at pre-plan / post-plan / pre-apply
- A plan can be **Discarded** instead of applied

### Workspace Workflow Types (how a run gets triggered)
Every workspace uses **one of 3 workflows**:

| Workflow | Triggers runs... | Best for |
|---|---|---|
| **Version Control (VCS)** | Based on **changes to configuration in repositories**. **PR → speculative plan**, **merge → plan + apply** | Those who need **traceability and transparency** (GitOps) |
| **CLI-Driven** | In a workspace **using the Terraform CLI** (`terraform plan` / `apply` with the **`cloud` block**). Runs execute **remotely**, logs stream back to your terminal | Those **comfortable with the Terraform CLI** |
| **API-Driven** | Using the **HCP Terraform API** (upload a configuration version, then create a run) | Those with **custom integrations and pipelines** |

### Speculative Plans
- **Plan-only** runs that **can never be applied**
- Triggered by **pull requests** (VCS) or `terraform plan` from the CLI
- Used to preview the impact of a change during code review
- ⚠️ On a **VCS-connected workspace**, you **can't run `terraform apply` from the CLI**. Applies only come from VCS merges (or the UI)

### Remote Operations
> **Terraform runs managed by HCP Terraform are called _remote operations_.**

- Your **plans and applies occur on HCP Terraform's infrastructure**
- You and your team can **review and collaborate on runs** within the app (UI)
- **Full feature access**: **Sentinel**, **cost estimation**, **notifications**

⚠️ **Exam keyword:** "remote operations" = runs executed **by HCP Terraform** (Remote execution mode). Local execution mode = **no** remote operations (HCP only stores state)

### Where Does Code Execution Happen? (Execution Modes)
It depends on the workspace's **execution mode**.

> 📌 **Execution mode is configured PER WORKSPACE** (Workspace → Settings → General → Execution Mode). One org can have some workspaces on Remote, some on Local, some on Agent. Defaults are **inherited: Org → Project → Workspace**, and each level can override (see Section 5, Project Rules).

| Mode | Where plan/apply runs | State stored in HCP? |
|---|---|---|
| **Remote** (default) | On **HashiCorp-managed, disposable (ephemeral) VMs** in HCP Terraform. A fresh worker per run, destroyed afterwards | ✅ |
| **Agent** | On **HCP Terraform Agents** that **you host** in your own network (on-prem / private VPC). Used when targets aren't reachable from the internet | ✅ |
| **Local** | On **your own machine** (or CI runner). HCP Terraform is used **only for state** storage and locking | ✅ |

#### Remote vs Local Execution
| Remote Execution | Local Execution |
|---|---|
| Plans and applies run **in HCP Terraform** | Plans and applies run **on your machine** |
| **Recommended for teams** | State **still stored remotely** in HCP Terraform |
| **Most HCP features available** (policies, cost estimation, run history) | **Limited access** to HCP features |
| Results **streamed back** to the local CLI | Uses your local credentials / env vars |

**What happens in Remote mode (even with CLI-driven runs):**
1. You run `terraform plan` / `apply` locally
2. The CLI **uploads your configuration** (working directory) to HCP Terraform
3. The run executes on the **remote worker**, not on your laptop
4. Output is **streamed back** to your terminal (and shown in the UI)

⚠️ **Exam traps:**
- In Remote mode, your **local environment variables and cloud credentials are NOT used**. Set provider credentials as **workspace variables** (env vars marked sensitive) or use dynamic credentials (OIDC)
- Remote workers **can't reach private resources** → use **Agent** mode
- **Local** mode = remote state only. No remote runs, so no Sentinel/OPA policy checks or cost estimation

#### Local Execution Mode
> **You can disable remote operations for any workspace by changing its Execution Mode to `Local`.**

- **Plan and apply run on your machine** (`terraform plan` / `terraform apply` locally)
- HCP Terraform is **ONLY** used to **store and synchronize state**
- **Workspace variables and variable sets are NOT evaluated** → you must supply variables and credentials locally (`.tfvars`, env vars)

⚠️ **Exam trap:** variables set in the HCP Terraform UI are **ignored** in Local mode

#### Agent Mode
> **Run your own lightweight HCP Terraform agents to run Terraform in isolated, private, or on-premises infrastructure.**

- **Plan and apply run on a self-hosted agent**
- For **private / on-premises infrastructure HCP Terraform can't reach directly**
- **HCP Terraform and Terraform Enterprise use the same agent** to evaluate policies and run Terraform operations
- Agent makes an **outbound-only** connection to HCP Terraform (polls for work), so **no inbound firewall ports** need opening
- Agents are grouped into **agent pools**, and a workspace is assigned to a pool

⚠️ **Exam trap:** "HCP Terraform needs to manage resources in a private data center / private VPC" → answer is **Agent** execution mode

---

## 7. Connecting to HCP Terraform (`cloud` block)
```hcl
terraform {
  cloud {                                   # ← tells Terraform to use HCP Terraform
    organization = "my-org"                 # ← your organization (auth required)
    hostname     = "app.terraform.io"       # ← default; change only for Terraform Enterprise

    workspaces {                            # ← which workspace/project to use
      project = "networking-development"

      tags = {
        layer  = "networking"
        source = "cli"
      }
    }
  }
}
```

| Argument | Meaning |
|---|---|
| `cloud {}` | Tells Terraform to use **HCP Terraform** for state (and runs) |
| `organization` | Your HCP Terraform org. **Authentication required** (`terraform login`) |
| `hostname` | Defaults to `app.terraform.io`. Set your own host for **Terraform Enterprise** |
| `workspaces.name` / `project` | Target a **specific** workspace / project |
| `workspaces.tags` | Use **all workspaces matching these tags**. Switch with `terraform workspace select` |
| `workspaces.project` | Project the workspace(s) belong to / get created in |

### Steps to Connect
**Step 1: Add the `cloud` block** to your configuration
- `organization` = your org name
- `workspaces` block, **two approaches**:
  - `name` / `project` → target a **specific** workspace / project
  - `tags` → target **all workspaces matching** the tag(s)

**Step 2: Authenticate with `terraform login`**
```
$ terraform login
Terraform will request an API token for app.terraform.io using your browser.

If login is successful, Terraform will store the token in plain text in
the following file for use by subsequent commands:
    /Users/bk/.terraform.d/credentials.tfrc.json

Do you want to proceed?
  Only 'yes' will be accepted to confirm.
```
- Opens the **browser** to generate a token, then you paste it back
- Token stored in **plain text** in `~/.terraform.d/credentials.tfrc.json` (Windows: `%APPDATA%\terraform.d\credentials.tfrc.json`)
- Only `yes` confirms

**Step 3: `terraform init`** → connects to HCP Terraform (and offers to **migrate existing state**)

### Environment Variable Alternative (CI/CD)
Instead of `terraform login`, set the token as an env var:
```bash
export TF_TOKEN_app_terraform_io="<token>"
```
- Format: `TF_TOKEN_<hostname>` with **dots replaced by underscores** (`app.terraform.io` → `app_terraform_io`)
- **Why it matters:** CI/CD pipelines and automation **can't do interactive browser login**

### API Token Types
| Token | Scope / Use | Can run plan/apply? |
|---|---|---|
| **Organization** | Manage **teams, membership and workspaces** (org-level admin automation) | ❌ **No** |
| **Team** | Used by **automated services like CI/CD pipelines** | ✅ Yes |
| **User** | **Same permissions as your user account**. **Only token type that can access multiple organizations** | ✅ Yes (if your user can) |
| **Audit** | **Read-only** access to the **audit trail API** | ❌ No |

⚠️ **Exam traps:**
- `terraform login` creates a **User token**
- Org token **can't run plans/applies**. Use a **Team** token for pipelines
- Need access across **multiple orgs** → **User** token

⚠️ **Exam traps:**
- `name` and `tags` are **mutually exclusive**. Use one or the other
- You **can't** use a `cloud` block and a `backend` block together
- The `cloud` block **can't use variables** (same rule as `backend`). Use env vars like `TF_CLOUD_ORGANIZATION`, `TF_WORKSPACE` instead
- `cloud` block is the **modern** way. The older way was `backend "remote" {}`

---

## 8. Users, Teams & RBAC (Permissions)

### The Access Control Hierarchy
| | What it is | Key facts |
|---|---|---|
| **Users** | Individuals with HCP Terraform accounts | Can belong to **multiple teams** AND **multiple organizations** |
| **Teams** | Groups of users within an organization | Granted permissions at the **organization, project and workspace** levels |
| **Permissions** | What a team can do | **Additive**: the **highest permission always wins**. Follow **least privilege** |

```
User  ──member of──►  Team  ──granted──►  Permissions (Org / Project / Workspace)
```
⚠️ **Permissions are given to TEAMS, not directly to users.** A user gets access by being in a team.

> 💰 **Key point: Teams are a PAID feature.** On the Free tier you only get the built-in **owners** team. Custom teams + RBAC need a paid tier.

### The Owners Team
> **Every organization has a default `owners` team with full admin access to everything.**

Owners can:
| Manage policies | Manage policy overrides | Manage workspaces |
|---|---|---|
| **Manage private registry** | **Manage VCS settings** | **Manage run tasks** |

- The org creator is automatically in **owners**
- Owners can see **all** teams (including secret ones) and manage org settings, teams and billing
- **Best practice:** keep owners **small**. Give everyone else a scoped team

### Team Settings
**Team Visibility**
| Setting | Who can see the team |
|---|---|
| **Visible** | **Every member** of the organization |
| **Secret** | **Only team members and organization owners** |

**Team Tokens**
- **Team API tokens** are designed for **performing API operations on workspaces**
- They have the **same access level** to workspaces **as the team** has
- Typical use: **CI/CD pipelines** (not tied to a person, so nothing breaks when someone leaves)

### Permission Levels (RBAC)
```
     ┌────────────────────┐
     │ Organization Level │  Broad: Manage all workspaces, Manage policies,
     └────────┬───────────┘         Manage VCS settings, View all workspaces
       ┌──────┴──────┐
       │Project Level│     Scoped to a project + ALL workspaces in it:
       └──────┬──────┘         Read, Write, Maintain, Admin, Custom
        ┌─────┴─────┐
        │ Workspace │      One specific workspace:
        │   Level   │          Read, Plan, Write, Admin, Custom
        └───────────┘
```

**Workspace permission levels** (lowest → highest)
| Level | Can do |
|---|---|
| **Read** | View runs, state versions, variables (non-sensitive) |
| **Plan** | Read + **queue plans** (speculative), but **can't apply** |
| **Write** | Plan + **approve/apply runs**, edit variables, lock/unlock workspace |
| **Admin** | Write + **workspace settings**, manage team access, **delete** workspace |
| **Custom** | Pick individual permissions |

**Project permission levels:** **Read**, **Write**, **Maintain** (manage workspaces in the project), **Admin** (also project settings + team access), **Custom**. These apply to **every workspace in the project** (current + future).

> 📌 **Permissions are additive.** HCP Terraform **always grants the highest permission level**. If a user's team has **Read** on a project but **Write** on one workspace inside it, they get **Write** on that workspace. There are **no "deny" rules**.

⚠️ **Exam traps:**
- Permissions are **additive**, so you **can't restrict** something a higher grant already allows
- Need someone to **plan but not apply** → workspace **Plan** permission
- One team for many workspaces → grant at **Project** level (least privilege, less sprawl)
- 💰 **Teams are a PAID feature.** The Free tier only has the default **owners** team. Creating custom teams and team-based RBAC needs a **paid tier** (Essentials / Standard / Premium)

---

## 9. Private Registry

### What is it?
> The **Private Registry** is a **module (and provider) registry built into your HCP Terraform organization**. It works like the public registry, but **only members of your org** can see and use it.

**Why use it?**
- **Share approved, internal modules** across teams (e.g. a company-standard `vnet` or `webapp` module with security baked in)
- **Versioning**: consumers pin `version = "1.2.0"`, the same way as with public modules
- **Governance**: teams use **vetted** modules instead of copy-pasting code or pulling random community modules
- **Curated public modules**: you can add selected public modules so teams use only approved ones
- **Discoverability**: auto-generated docs (inputs, outputs, README) in the UI
- Foundation for **no-code provisioning** (non-Terraform users deploy approved modules from the UI)

### What's Inside the Private Registry?
| Content | Details |
|---|---|
| 🧩 **Private Modules & Providers** | **Published from your organization's VCS repos**, **only accessible to organization members** |
| ☁️ **Curated Public Modules** | **Public registry modules/providers you've added** to your private registry as **"approved"** for your org |

### Public vs Private Registry
| | **Public Registry** | **Private Registry** |
|---|---|---|
| **Hosted at** | `registry.terraform.io` | **Inside your HCP Terraform organization** |
| **Visibility** | **Anyone on the internet** | **Only members of your organization** |
| **Who publishes content** | **Anyone** | **Your team, from your connected VCS repos** |
| **Content** | **Community** modules & providers | **Your private modules + curated public modules** |
| **Source format** | `terraform-aws-modules/iam/aws` (3 parts) | `app.terraform.io/krausen-hcp/webapp/gcp` (**4 parts, includes hostname**) |
| **Authentication** | Not needed | `terraform login` / API token |

### Using Private Modules (The Source Format)
Modules from the private registry are referenced using a **registry source address** of the form:
```
app.terraform.io/<ORGANIZATION-NAME>/<NAME>/<PROVIDER>
└── hostname ──┘ └──── org ────────┘ └name┘ └provider┘
```
```hcl
module "webapp" {
  source  = "app.terraform.io/krausen-hcp/webapp/gcp"   # hostname/org/name/provider
  name    = var.name
  prefix  = var.prefix
  version = "1.0.0"                                     # pin a version (works for registry modules)
}
```

| | Format | Example |
|---|---|---|
| **Public** | `<NAMESPACE>/<NAME>/<PROVIDER>` (3 parts) | `terraform-aws-modules/iam/aws` |
| **Private** | `<HOSTNAME>/<ORGANIZATION>/<NAME>/<PROVIDER>` (4 parts) | `app.terraform.io/krausen-hcp/webapp/gcp` |

- Module inputs (`name`, `prefix`) are passed as arguments, the same as any module
- `version` pins the module to a Git-tag release (`1.0.0`). Supports constraints like `~> 1.0`
- Terraform Enterprise → replace `app.terraform.io` with **your own hostname**

> ℹ️ The slide writes the form as `app.terraform.io/<ORG>/terraform/<NAME>/<PROVIDER>`, but its own example (and HashiCorp docs) use **no `/terraform/` segment**: `app.terraform.io/krausen-hcp/webapp/gcp`. Go with the **4-part** format.

### Publishing Private Modules
```
 01 VCS REPO  ──────►  02 HCP TERRAFORM  ──────►  03 ORG MEMBERS
 (module code)          (private registry)         (consume modules)
```
| Step | What happens |
|---|---|
| **01 VCS Repo** | Module code lives in **GitHub, GitLab, Bitbucket, etc.** Must follow the **standard module structure** (`main.tf`, `variables.tf`, `outputs.tf`, `README.md`) |
| **02 HCP Terraform** | **Publish to your private registry.** **New versions are auto-created from Git tags** (`v1.0.0`, `v1.1.0`) |
| **03 Org Members** | Organization members **browse, search and reference** modules in their configurations |

**How to publish (hands-on):**
1. Connect a **VCS provider** (GitHub etc.) to the org
2. Repo named **`terraform-<PROVIDER>-<NAME>`** (e.g. `terraform-gcp-webapp`)
3. HCP UI → **Registry → Publish → Module** → pick the repo
4. Push **SemVer Git tags** (`git tag v1.0.0 && git push --tags`). **Each new tag = a new module version, automatically**

### 🎯 Key Takeaways: Private Registry
- The private registry lets you **share modules and providers privately within your organization**
- You can also **curate approved public modules/providers** alongside your private ones
- Private modules are **published from VCS repositories** and **versioned with Git tags**
- The source format **includes the hostname**: `app.terraform.io/<ORG>/<MODULE>/<PROVIDER>`
- **All org members can view and use** the registry. **Publishing requires "Manage Private Registry" permission** (owners have it by default)

⚠️ **Exam traps:**
- Private registry source has **4 parts**: the extra part is the **hostname** (`app.terraform.io`)
- `terraform init` needs **authentication** (`terraform login` / `TF_TOKEN_app_terraform_io`) to download private modules
- The private registry is an **HCP Terraform feature**. The **public** registry comes with Terraform Community
- More on modules and the public registry → [04 › Using a Private Registry module](04-Terraform_Modules.md)

---

## 10. Policy Enforcement (Sentinel & OPA)

### Why Policy Enforcement?
```
DEVELOP ──terraform apply──► DEPLOY (e.g. public S3 bucket) ──wrong policy──► BREACH 💥
```
> **What if we could catch misconfigurations and policy violations BEFORE resources ever get deployed?**

### Policy as Code
| Principle | Meaning |
|---|---|
| **Codified Rules** | **Security, compliance and operational** requirements **written as code** |
| **Version Controlled** | **Stored in VCS**, reviewed through **pull requests**, just like infrastructure code |
| **Automatically Enforced** | **Evaluated on every run**, **no manual review** required |

### Terraform Run With Policies
```
Infrastructure ──►  ┌─ Plan ✅ ──► Policy Checks ✅ ──► Apply ─┐ ──►  Managed
   as Code          └──────────────────┬─────────────────────┘      Infrastructure
                                       │
                      ┌────────────────┼────────────────┐
                 Operational ✅    Security ✅      Financial ✅
```
Policies typically check **3 categories**:
| Category | Example rule |
|---|---|
| **Operational** | Mandatory tags (`owner`, `env`), allowed regions, naming conventions |
| **Security** | No public storage/buckets, encryption on, no `0.0.0.0/0` on SSH |
| **Financial** | Allowed VM sizes only, monthly cost increase < $X |

### Policy Check: Key Rules
- Policies **evaluate the plan data before any infrastructure is created** (run order: **Plan → Cost Estimation → Policy Check → Apply**)
- **Failed policies can block the apply entirely**
- **Sentinel** policy checks also have **access to cost estimation data** (e.g. "block if monthly cost > $500")
- **If the plan itself fails, policies are never evaluated**

### Two Frameworks: Same Goal
| | **Sentinel** | **Open Policy Agent (OPA)** |
|---|---|---|
| **Created & maintained by** | **HashiCorp** | **CNCF** (Cloud Native Computing Foundation) |
| **Policy language** | **Sentinel** | **Rego** |
| **Ecosystem** | **HashiCorp stack** (Terraform, Vault, Consul, Nomad) | **Cloud-native** (Kubernetes, Envoy, CI/CD...) |
| **Pre-written policies** | **Yes, from HashiCorp** (policy libraries) | **Community-driven** |
| **Enforcement levels** | `advisory`, `soft-mandatory`, `hard-mandatory` | `advisory`, `mandatory` |
| **Cost estimation data** | ✅ Yes | ❌ No |

> 📌 **You can use BOTH frameworks in the SAME workspace.** A workspace can have Sentinel policy sets **and** OPA policy sets attached at the same time, and both are evaluated during the policy check. Pick per team/use case (e.g. reuse existing OPA/Rego policies from Kubernetes alongside HashiCorp's Sentinel libraries).

### Sentinel Enforcement Levels (3)
| Level | On failure | When to use |
|---|---|---|
| ⚠️ **Advisory** | Produces a **warning**, but the **run continues** | **New policies** you're introducing but **not yet enforcing** |
| 🛑 **Soft Mandatory** | **Stops the run**, but **can be overridden**. Requires the **"Manage Policy Overrides"** permission. **All overrides are logged for auditing** | Important rules with approved exceptions |
| ❌ **Hard Mandatory** | **Stops the run** and **CANNOT be overridden**. The violation **must be fixed in the configuration** before the run can proceed | Non-negotiable rules. **⭐ The DEFAULT level for Sentinel policies** |

### OPA Enforcement Levels (2)
| Level | On failure | When to use |
|---|---|---|
| ⚠️ **Advisory** | Produces a **warning**, but the **run continues** | **New policies** you're introducing but **not yet enforcing** |
| ❌ **Mandatory** | **Stops the run**. **Can be overridden** (with "Manage Policy Overrides"), otherwise the violation must be fixed in the configuration before the run can proceed | Enforced rules (OPA's equivalent of soft-mandatory) |

```
Sentinel :  Advisory  →  Soft Mandatory  →  Hard Mandatory (default, no override)
OPA      :  Advisory  →  Mandatory (overridable)
```

### Develop Policies → Assign to Workspaces
Write individual policies once, then **assign them for enforcement** to the workspaces that need them:
```
Policies                                     Workspaces
├── stl-require-mandatory-tags   ──────►     Workspace  Workspace
├── stl-restrict-instance-types  ──────►     Workspace  Workspace
├── stl-enforce-s3-encryption                Workspace  Workspace
├── opa-block-public-ingress     ──────►
└── opa-limit-auto-apply         ──────►
```

### Policy Sets
Policies are **grouped into policy sets**, and the **set** is what gets attached to workspaces:
```
Policy Set: Sentinel-Security           Policy Set: OPA-Security
├── stl-require-mandatory-tags          ├── opa-block-public-ingress
└── stl-enforce-s3-encryption           └── opa-limit-auto-apply
```
| Rule | Detail |
|---|---|
| 📦 **Policies are grouped into policy sets** | You attach **sets**, not individual policies |
| ⚙️ **Each set is ONE framework only** | **All Sentinel OR all OPA**. Never mixed in one set |
| 🔍 **Scope** | **Globally**, to **projects**, or to **specific workspaces** |
| 🔌 **Exclusions** | You can **exclude workspaces** from a set (e.g. global set except `sandbox-dev`) |
| 💻 **3 management methods** | **UI**, **VCS** (recommended, policy as code), **API** |

> 📌 Each **set** is one framework, but a **workspace** can have **both** a Sentinel set **and** an OPA set attached.

### What Policies Can and Can't Do
| ✅ Policies CAN | ❌ Policies can NOT |
|---|---|
| **Block public S3 buckets** | **Continuously monitor after deployment** (that's drift detection / health checks) |
| **Restrict instance types** | **Remove existing violating resources** |
| **Enforce tagging** | **Validate that attribute values are valid** (e.g. a real AMI ID). That's the provider/API's job |
| **Limit regions** | **Analyze runtime behavior** |
| **Enforce cost measures** | |

> Policies only check the **plan** at **run time**. They don't watch or fix live infrastructure.

### 🎯 Key Takeaways: Policy Enforcement
- Policies evaluate **after the plan phase but before apply**, catching issues **before infrastructure is created**
- HCP Terraform supports **two policy frameworks**: **Sentinel** (HashiCorp) and **OPA** (open source, uses **Rego**)
- **Sentinel has 3 enforcement levels** (advisory, soft mandatory, hard mandatory). **OPA has 2** (advisory, mandatory)
- **Policy sets** can be scoped **globally**, to **specific projects**, or to **individual workspaces**
- **Overriding** a failed policy requires the **"Manage Policy Overrides"** permission

### Tiny Examples
**Sentinel**: allow only approved VM sizes
```sentinel
import "tfplan/v2" as tfplan

allowed_sizes = ["Standard_B1s", "Standard_B2s"]

vms = filter tfplan.resource_changes as _, rc {
  rc.type is "azurerm_linux_virtual_machine" and rc.mode is "managed"
}

main = rule {
  all vms as _, vm { vm.change.after.size in allowed_sizes }
}
```
**OPA (Rego)**: deny storage accounts without TLS 1.2
```rego
package terraform.policies.storage

import input.plan as tfplan

deny[msg] {
  r := tfplan.resource_changes[_]
  r.type == "azurerm_storage_account"
  r.change.after.min_tls_version != "TLS1_2"
  msg := sprintf("%v must use TLS1_2", [r.address])
}
```

⚠️ **Exam traps:**
- Policy checks run **after plan, before apply**. A **failed plan** means **no policy evaluation**
- **Hard-mandatory** = **no override**. **Soft-mandatory** = override with **"Manage Policy Overrides"** permission (owners have it). Overrides are **logged**
- **Default Sentinel level = Hard Mandatory**
- **One policy set = one framework** (all Sentinel or all OPA)
- Policies **can't** fix or remove existing resources, or monitor after deployment
- Only **Sentinel** can read **cost estimation** data
- Sentinel = **HashiCorp**, language **Sentinel**. OPA = **CNCF**, language **Rego**
- **Both** frameworks can be used in the **same workspace**
- Policy enforcement is a **paid-tier** feature (Standard / Premium)

---

## 11. Additional HCP Terraform Features

### 11.1 Health Assessments
**The problem:**
```
Terraform Configuration (Desired State)           Azure Subscription (Production)
  Resource Block  ──────────────────────────►       Virtual Machine
  Resource Block  ──────────────────────────►       Virtual Machine  ◄── someone "Makes Change
  Resource Block  ──────────────────────────►       Virtual Machine        in Azure Portal"
```
> **How do you know your infrastructure is still correct?**

Once enabled, HCP Terraform **automatically runs health assessments** on your workspaces **about once every 24 hours**. They have 2 parts:

| Drift Detection | Continuous Validation |
|---|---|
| **Compares real infrastructure against your state file** | **Evaluates `check` blocks, preconditions and postconditions** |
| "**Did something change outside Terraform?**" (e.g. manual portal edit) | "**Are your custom rules still passing?**" (e.g. cert not expired, endpoint returns 200) |

**The lifecycle:**
```
Provision ──► Check ──► Detect ──► Notify ──► Remediate
              (every ~24h)  (drift / failed    (alert     (run apply to fix,
                             assertions)        team)      or update code)
```

**Key facts:**
- If something's wrong, the workspace shows a **"Health warning"** status
- Available in **HCP Terraform Standard and Premium** editions
- Can be **enabled per-workspace** (Workspace → **Settings → Health → Enable**) or **enforced across the entire organization**
- Health assessments **don't change anything**. They **detect and notify** only. **You remediate** (apply to revert drift, or update config to accept it)
- Needs **Remote or Agent** execution mode (not Local)

> 🔗 This is what **policies can't do** (Section 10): policies check the **plan before apply**. Health assessments watch **live infrastructure after deployment**.

### 11.2 Run Triggers
**The problem: workspaces often depend on each other**
```
Networking Workspace ◄──── retrieves subnet list from state ──── Firewall Workspace
 (deploys & manages subnets)                                      (creates firewall rules per subnet)
```
If networking adds a subnet, the firewall workspace must re-run to create rules for it.

**The solution: Run Triggers**
```
HCP Terraform ──► Networking Workspace: Plan ──► Apply ──► Managed Infrastructure
                                                   │
                                            Run Trigger
                                                   ▼
                                          Firewall Workspace (run auto-queued)
```
| Benefit | Detail |
|---|---|
| **Connect workspaces** | A workspace connects to **one or more source workspaces** |
| **Automatic** | HCP Terraform **automatically queues a run** in the connected **downstream** workspace |
| **Limit** | Each workspace can connect to **up to 20 source workspaces** |
| **When it fires** | On **successful applies** in the **source** workspace |
| **Result** | **Workspace-to-workspace automation** |

- Configure on the **downstream** workspace: **Settings → Run Triggers** → pick source workspace(s)
- Downstream reads upstream outputs using `terraform_remote_state` or the `tfe_outputs` data source
- Trigger fires on **apply** only. A plan-only run in the source does **not** trigger

### 11.3 Explorer (Gaining Visibility)
> **Explorer** = an org-wide **query/report view** to **explore your data and analyze your organization's Terraform usage** across all workspaces. UI: left menu → **Visibility → Explorer**.

**Types** (what you can query):
| Type | Shows |
|---|---|
| **Modules** | Modules used across workspaces + versions |
| **Providers** | Providers in use + versions |
| **Workspaces** | All workspaces with their settings/status |
| **Terraform Versions** | Which Terraform version each workspace runs |

**Use cases** (pre-defined views):
| View | Answers |
|---|---|
| **Top module versions** | Which module versions are most used (find outdated ones) |
| **Top provider versions** | Who's still on an old provider version |
| **Latest Terraform versions** | Which workspaces need a Terraform upgrade |
| **Workspaces without VCS** | Workspaces not connected to Git (no GitOps / audit trail) |
| **Workspace VCS source** | Which repo/branch each workspace uses |
| **Workspaces with failed checks** | Workspaces with failing **health assessments / continuous validation** |

- **New query** → build custom filters. **Saved views** → reuse queries
- Results can be exported (CSV) for reporting
- **Change Requests** are created **from Explorer results** (e.g. select all workspaces on an old provider → raise a change request)

> 💡 Explorer = **read-only visibility** across the whole org. It answers "**where** is X used?" without opening each workspace.

### 11.4 Change Requests
- **Actionable "to-do" items** you can **attach to workspaces**
- You add the messages **directly from the Explorer**, and they get **tracked for each workspace**
- **Teams can be notified** when new change requests are created on their workspaces
- Available in **Standard and Premium** editions

> Use case: the platform team flags "upgrade provider to v4" or "fix health warning" on 30 workspaces, and each owning team sees it as a to-do.

⚠️ **Exam traps:**
- **Drift detection** = real infra vs **state**. **Continuous validation** = `check` blocks + pre/postconditions
- Health assessments run **~every 24h** and only **notify**. They **don't auto-fix**
- Health assessments & change requests = **Standard / Premium** only
- Run triggers fire on **successful apply** of the **source** workspace. **Max 20 sources** per workspace
- Run triggers are configured on the **downstream** (consumer) workspace
- **Explorer** = org-wide visibility of **modules, providers, workspaces, Terraform versions**. Change requests are raised **from** Explorer

---

## 12. HCP Terraform Tiers
*(Subject to change. Check HashiCorp's pricing page for updates)*

| Tier | Target | Key features |
|---|---|---|
| **Free** | Individuals / getting started | **State storage** and basic features. **500 managed resources at no charge** |
| **Essentials** | Access to more features | **Stacks**, **unlimited applies**, etc. |
| **Standard** | **Enterprises** | **Drift detection**, **golden patterns**, **audit events**, **policy enforcement** (Sentinel/OPA) |
| **Premium** | **Multi-cloud enterprise** | **Private VCS**, **run tasks**, **module revocation** |

- Billing is based on **managed resources** (resources tracked in state), not users
- Each tier **includes everything** from the tiers below it
- **Terraform Enterprise** = the **self-hosted** option (separate from these SaaS tiers)

---

## 13. Exam Quick Hits
- Log in with `terraform login`. The token is saved in `credentials.tfrc.json`
- Connect a config using the **`cloud` block** inside `terraform {}` (see Section 7)
- **3 workflows**: **CLI-driven**, **VCS-driven**, **API-driven**
- Sentinel/OPA policies run **after plan, before apply**
- **Free tier** = state storage + basics, up to **500 managed resources**. Policy enforcement and drift detection need **paid tiers** (see Section 12)

> **Interview one-liner:** "HCP Terraform turns Terraform from a single-user CLI tool into a team platform. It gives you centralized state, consistent remote runs, VCS-driven workflows, policy-as-code guardrails and RBAC, so infrastructure changes are reviewed, governed and auditable."
