# Terraform for Infosys SRE (QLTY): F2F Final Round Question Bank

**Interview:** 6 Oct 2026 · Bangalore · Job ID INFSYS-EXTERNAL-249469 · Service line: Quality
**Round 1:** ✅ cleared. **This round:** scenario-based, resume-anchored, judgment and trade-offs.

> These are questions only. Answer each one **out loud** using the Bridge format below.
> ⭐ = high probability · 🎯 = anchored to your resume or project (expect follow-ups) · 🔗 = JD-linked

---

## 0. How to Answer: The Bridge Format

Every Terraform answer should follow these four steps, not stop at theory:

1. **Direct answer:** 2–3 sentences.
2. **Your experience:** "In my AKS GitOps platform…" or "At TCS on the Microsoft engagement…"
3. **Judgment:** why X over Y, the trade-off you accepted, and what you'd change.
4. **Connect to them:** reliability, SLO, toil, postmortem, or quality.

**Your Terraform evidence bank** (pull from these; don't invent new examples):

| Evidence | Where it lives |
|---|---|
| Modular IaC: `resource-group`, `acr`, `aks` modules + `envs/dev` root | `voting-platform-infra/` |
| Remote state on Azure Storage; backend values injected via `-backend-config` (not hardcoded) | `envs/dev/backend.tf` |
| PR pipeline: pinned TF 1.5.7 → `fmt -check` → **Checkov** (fail-closed) → init → validate → plan (plan-only, never touches Azure) | `.pipelines/PR-infra-pipelines.yml` |
| Separate Publish pipeline for apply | `.pipelines/Publish-infra-pipelines.yml` |
| **Workload Identity Federation (OIDC)** service connection: no client secret (`ARM_USE_OIDC`, `ARM_OIDC_TOKEN`) | commit `94c7c46` |
| Checkov `--skip-check` list with a **documented reason per exception** (cost or access-model trade-offs) | PR pipeline comments |
| Started **manual (portal/az CLI)** → moved to Terraform | `Manualconfigurations.md` → `automated_infra.md` |
| Helm provider deploys Argo CD from the same root module, using AKS outputs | `envs/dev/argocd.tf` |
| Managed Prometheus + Grafana (observability) | `voting-platform-observability/` |

---

## ⚠️ Pre-Interview Integrity Check (do this tonight)

The interviewer will probe the claims on your resume. Make sure you can defend each of these exactly:

- [ ] Resume says Terraform provisioned **"VNet/NSG, Key Vault"**. In the current code the AKS module uses `network_plugin = "azure"` and the **Key Vault Secrets Provider add-on**, but there is no standalone `azurerm_virtual_network`, NSG, or `azurerm_key_vault` resource. Decide how you'll describe it accurately (e.g., "AKS-managed networking + KV CSI add-on; standalone VNet/KV modules were next") or add them tonight.
- [ ] Resume says **"OIDC-based Workload Identity for secretless Azure access"**. In code, the *pipeline* uses WIF/OIDC, but the AKS `workload_identity_enabled` variable defaults to **off**. Know which one you mean.
- [ ] The observability stack is deployed via **PowerShell** (`deploy.ps1`), not Terraform. Expect "why not Terraform?"
- [ ] You pinned `azurerm ~> 3.0` while 4.x is current. Expect "why not 4.x?"
- [ ] There is only a `dev` environment. Expect "how would you add stage/prod?"

> Honest framing beats bluffing in a final round. "Here's what I built, here's the gap, here's how I'd close it" **is** SRE judgment.

---

## 0.5 Fundamentals Warm-Up (expect 2–3 of these quickly)

> These come from the course chapter list. Answer each one in under 30 seconds, then bridge to your project.

**History, trends and comparisons**
- F1. What is Terraform? Who makes it, and what changed with the **BSL license (2023)**, **OpenTofu**, and the **IBM acquisition**?
- F2. Which recent Terraform features have you used or would use? (`import` / `moved` / `removed` / `check` blocks, `terraform test`, ephemeral values)
- F3. Why does IaC matter for an **SRE** specifically? (reproducibility, drift, MTTR, auditability)
- F4. Terraform vs **Ansible**: when would you use both together?
- F5. Terraform vs **CloudFormation** vs **ARM/Bicep**: why Terraform for an Azure-only shop?

**Setup and HCL**
- F6. How do you install Terraform and manage versions across developers and pipeline agents?
- F7. Block vs argument vs attribute. Name all top-level **block types**.
- F8. String interpolation (`"${var.prefix}-rg"`): when is it needed and when not?
- F9. `variable` vs `locals` vs `output`. What is the **variable precedence order**?
- F10. Variable types (`object`, `map`, `list`, `set`, `tuple`), `validation`, and `sensitive`.

**Workflow and providers**
- F11. Write → Plan → Apply: what happens internally in `init`, `plan` and `apply`?
- F12. What is a provider? How does Terraform download it, pin it, and use `alias` for multi-region or multi-subscription?

**Provisioners, user data and workspaces**
- F13. `local-exec` vs `remote-exec` vs `file` provisioners. Why are they a last resort?
- F14. Azure `custom_data` / AWS `user_data` with cloud-init. What happens to the VM if you change it?
- F15. What is a workspace? Create, list, and switch between them. Where does `terraform.workspace` show up in code?
- F16. Workspaces isolate **state**, not **config**. Why does that make them risky for prod separation?

**Modules and state backends**
- F17. Using a prebuilt **Registry module** (e.g., Azure Verified Modules): how do you vet and pin it?
- F18. AWS: S3 + **DynamoDB** locking. Azure: blob lease. How do they compare, and what changed with S3 native locking?

---

## 1. 🎯 Resume and Project Deep-Dive (most likely opener)

1. "Walk me through the Terraform layout of your AKS platform. Why did you split it into these modules?"
2. "Why is the backend config empty in `backend.tf`? How do values get in, and why?"
3. "You **started manually** (portal/`az`) and moved to Terraform. How did you bring existing resources under Terraform without recreating them?" (import, `import` blocks, drift)
4. "Your Checkov gate skips ~15 checks. Isn't that defeating the purpose? Who approves an exception, and when do you revisit it?"
5. "Explain the WIF/OIDC fix you made. What was failing before, and why is OIDC better than a client secret?"
6. "Your Helm provider reads `client_certificate` / `client_key` from AKS outputs. Where do those credentials end up, and is that a risk?" (hint: state)
7. "You deploy Argo CD with Terraform **and** let Argo CD manage apps. Where is the boundary between Terraform and GitOps? What breaks if both manage the same resource?"
8. "Why is the PR pipeline plan-only? How does the Publish pipeline guarantee it applies **the same plan** that was reviewed?"
9. "You pinned Terraform 1.5.7 and Checkov 3.2.0. Why pin? How do you upgrade safely?"
10. "Your resume says you resolved **Argo CD crash-looping from resource starvation**. Could Terraform have prevented it? (node size, node count, node pools)"
11. "Only `dev` exists. Design stage and prod for this repo: directories, backends, workspaces, approvals."
12. "Why `azurerm ~> 3.0` and not 4.x? What would a major provider upgrade involve?"

---

## 2. ⭐ State Management

13. What is the state file, why does Terraform need it, and what happens if it's deleted?
14. How does **state locking** work on the Azure Storage backend (blob lease)? What happens if two pipelines apply at once?
15. **Scenario:** a pipeline agent died mid-apply and the lock is stuck. Walk through a safe recovery. When is `force-unlock` dangerous?
16. State has secrets in plain text (including your AKS kube credentials). How do you protect it? (RBAC on the storage account, versioning, soft delete, encryption, private endpoint)
17. **Scenario:** state is corrupted or accidentally overwritten. How do you recover? What should already be in place?
18. **Scenario:** you renamed `module.aks` to `module.aks_cluster` and plan wants to destroy the cluster. Fix it two ways (`state mv` vs a `moved` block). Which is safer in a pipeline-only workflow?
19. When do you use `state list / show / rm / pull / push`? Give a real reason to `state rm` something.
20. One big state or many small states? What's the **blast radius** argument?

---

## 3. ⭐ Drift, Import and Change Safety

21. **Scenario:** someone scaled the AKS node pool in the portal during an incident. Next plan wants to revert it. What do you do, during and after the incident?
22. How do you **detect drift continuously**? Design a scheduled drift-detection pipeline. Where do the results go, and who gets alerted?
23. `terraform import` vs `import` blocks (v1.5+) vs `-generate-config-out`. Which would you use for 20 existing resources?
24. What does `plan -refresh-only` do? Why was `terraform refresh` deprecated?
25. **Scenario:** plan shows `-/+ destroy and then create replacement` on the **production AKS cluster**. How do you investigate before approving? Which attributes force replacement?
26. How do you prevent a destructive change from reaching prod? (plan review, `prevent_destroy`, policy checks, approvals, a "destroy count > 0 → block" gate)

---

## 4. ⭐ Meta-Arguments and Lifecycle

27. `count` vs `for_each`: what happens when you remove the middle item from a `count` list?
28. Implicit vs explicit dependencies. Why did you need `azurerm_role_assignment.aks_acr_pull` to depend on AKS, and did you need `depends_on`?
29. Give an SRE use case for each:
    - `create_before_destroy` (zero-downtime replacement)
    - `prevent_destroy` (state storage account, prod AKS)
    - `ignore_changes` (node count managed by the cluster autoscaler, or tags set by Azure Policy)
    - `replace_triggered_by`
30. `dynamic` blocks: write NSG rules from a list of objects.
31. Create a resource only in prod (conditional `count` / `for_each`).
32. Variable `validation` blocks: how would you enforce allowed VM SKUs or regions?

---

## 5. Modules and Environment Strategy

33. What makes a module **reusable** versus "a folder of resources"? Which inputs and outputs did you expose in your `aks` module, and why?
34. How do you version modules (Git tags, private registry) and roll out a breaking module change to 10 consuming teams?
35. `.terraform.lock.hcl`: what's in it, should you commit it, and how does it affect pipelines on different OSes?
36. Workspaces vs directory-per-env vs separate backends. Which would you choose for Infosys client projects, and why?
37. How do you share outputs across stacks? (`terraform_remote_state` vs data sources). What's the coupling risk?

---

## 6. ⭐ CI/CD, Security and Governance

38. Design an end-to-end Terraform pipeline: PR → fmt/validate/lint/scan → plan → **saved plan artifact** → manual approval → apply exactly that plan.
39. Authentication options: Service Principal + secret, Managed Identity, **OIDC/WIF**. Compare them, and say which one you used and why.
40. How do you handle secrets? (Key Vault data source, `sensitive = true`, variable groups, never committing tfvars). Does `sensitive = true` keep a value out of state?
41. Tooling: `tflint`, `tfsec`/`trivy config`, **Checkov**, Sentinel/OPA, Infracost. Where does each fit?
42. How do you control who can apply to prod? (environment approvals, branch policies, RBAC split between plan and apply identities)
43. How do you enforce **tagging/ownership** on every resource? (default tags, policy, validation)

---

## 7. 🔗 Terraform × SRE JD (Infosys will bridge here)

**Observability and SLOs** (JD: "Implementation of observability platform", "set SLI/SLOs")

44. Would you manage **alerts, action groups, dashboards and Log Analytics** in Terraform? Why or why not? Why is your Grafana setup in PowerShell today?
45. "Monitoring as code": how would you define an SLO-based alert (e.g., 99.9% availability, burn-rate alert) as Terraform resources?
46. How does a Terraform change affect your **SLO / error budget**? Should infra changes be frozen when the error budget is exhausted?

**Ownership data** (JD: "Review all ownership data and ensure it is current and complete")

47. How would you use Terraform to guarantee every resource has `owner`, `team`, `service` and `cost-center` tags? How would you **audit** resources that are missing them?

**CFBT / continuous testing** (JD: "CFBT", "Continuous Testing", Quality service line)

48. How would you spin up **ephemeral test environments** with Terraform for customer-flow tests, then tear them down reliably? How do you stop orphaned resources and cost leaks?
49. How do you **test Terraform itself**? (`terraform test`, Terratest, `validate`, plan assertions, policy tests)

**Incidents and postmortems** (JD: "Lead postmortems for P1+", "Emergency Incident Response")

50. **Scenario:** a Terraform apply caused a P1 outage (e.g., NSG rule removed, or AKS recreated). Walk through incident response → mitigation → **blameless postmortem** → action items.
51. **Scenario:** during a P1 you need to hotfix infra **right now**. Do you go through Terraform or the portal? How do you reconcile afterwards?
52. What **guardrails** would you put in place so the same Terraform-caused incident never recurs?

**Toil reduction** (JD: "Driving continuous improvement through toil reduction and automation")

53. You moved from manual portal setup to Terraform. **Quantify** the toil removed: time to rebuild an environment, errors avoided, consistency.
54. Your BuildFixer / self-healing build system fixes CI failures. Would you let an LLM agent **propose Terraform changes**? What guardrails would you need (you already used confidence thresholds, allowlists and diff caps)?

**Design consultation** (JD: "Operations and Design Consultation for driving high reliability")

55. A team asks you to review their Terraform for reliability. What do you check? (zones, redundancy, state setup, lifecycle protection, pinning, blast radius)
56. How would you make your AKS Terraform **highly available** for a 99.95% SLO? (availability zones, system and user node pools, autoscaler, SKU tier)

---

## 8. ⭐⭐ Troubleshooting and Failure Scenarios

57. Apply failed halfway: some resources created, some not. What's in state, and what's next?
58. A provider upgrade broke the plan. What steps do you take?
59. Perpetual diff: plan shows a change every run. Common causes?
60. Plan on a large state is very slow. How do you speed it up? (splitting state, `-parallelism`, `-refresh=false`; why `-target` is a smell)
61. `Error acquiring the state lock` in the pipeline at 2 AM. What do you do?
62. `AuthorizationFailed` / 403 in apply but not in plan. Why could that happen?
63. Debugging: `TF_LOG`, `TF_LOG_PATH`, `TF_LOG_PROVIDER`.
64. Force-recreate one resource: `taint` vs `apply -replace`.
65. Someone ran `terraform destroy` on prod. Which safeguards should have stopped it, and how do you recover?

---

## 9. Quick-Fire Round

66. `fmt` vs `validate`
67. Provisioners (`local-exec` / `remote-exec`): why are they a last resort?
68. `null_resource` vs `terraform_data`
69. `terraform console`, `output -json`, `graph`
70. Functions: `lookup`, `merge`, `try`, `coalesce`, `flatten`, `toset`, `cidrsubnet`
71. `data` source vs `resource`
72. What does HCP Terraform / Terraform Cloud add? (remote runs, policy, private registry)
73. Terraform vs Bicep for an Azure-only shop

---

## 10. Whiteboard / Hands-On (possible in F2F)

74. RG + VNet + 2 subnets + NSG associated with a subnet.
75. Multiple VMs or node pools with `for_each` from a map.
76. An `azurerm` backend block plus the `init -backend-config` command.
77. A module call that passes variables and uses an output.
78. A `dynamic` NSG-rule block from a list of objects.
79. An Azure Monitor metric alert + action group in Terraform (ties to the JD).

---

## Revision Priority (tonight)

| Priority | Sections | Why |
|---|---|---|
| 🔴 Must | 1 (Resume deep-dive), the ⚠️ integrity check, 7 (JD bridge) | Final round = resume-anchored + "what will you deliver" |
| 🔴 Must | 2 (State), 8 (Troubleshooting) | Classic SRE Terraform depth |
| 🟠 High | 3 (Drift/Import), 6 (CI/CD and Security) | Ties directly to your pipeline work |
| 🟡 Medium | 0.5 (Fundamentals), 4 (Lifecycle), 5 (Modules) | Quick warm-ups and follow-ups |
| 🟢 Skim | 9, 10 | Quick recall only |

**Rule for tonight:** no new learning. Rehearse sections 1 and 7 out loud using the Bridge format, then sleep.
