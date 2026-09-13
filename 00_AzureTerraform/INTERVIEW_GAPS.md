# Terraform Interview Readiness — Gaps to Close

> Companion to [LEARNING_PROGRESSION.md](LEARNING_PROGRESSION.md). That file tracks
> what's been *learned*; this one tracks what's *missing* before this repo's knowledge
> is enough to clear a mid/senior Terraform interview.

## Where things stand

Strong on core workflow, state/backends, variables, modules, and especially
`count` vs `for_each`. Labs 01–06 are narrow in scope: `random_string`, resource
groups, storage accounts, log analytics, and Key Vault only. Enough for a
junior/associate-level screening, not yet enough for mid/senior DevOps/Platform roles.

## Gaps

- [ ] **Networking** — no VNet/subnet/NSG lab built. Add one that provisions a VNet
      with subnets and NSG rules end to end.
- [ ] **Compute** — no VM or AKS or App Service actually deployed, only mentioned in
      docs. Add a lab deploying at least one (VM or AKS).
- [ ] **CI/CD pipeline** — YAML examples exist in the docs but nothing is wired up.
      Build a real GitHub Actions (or Azure DevOps) plan/apply pipeline against this
      repo's remote backend.
- [ ] **Policy-as-code / testing** — no tfsec/Checkov/Terratest/`terraform test` runs
      anywhere in the repo. Add at least one automated check.
- [ ] **`terraform_remote_state` data source** — not used anywhere; needed to explain
      cross-module/cross-environment state referencing.
- [ ] **Provider aliasing / multi-region or multi-subscription** — no example of
      `provider "azurerm" { alias = ... }` or deploying to two regions/subscriptions
      from one config.
- [ ] **`moved` blocks / native `import` blocks** (Terraform 1.5+) — only the older
      `terraform import` CLI command is covered.
- [ ] **Sentinel / OPA governance** — not covered; common in enterprise-Terraform
      interviews.
- [ ] **Multi-module composition (module reusing another module)** — no example of a
      module calling another module (e.g. an `app-stack` module reusing a shared
      `networking` module). Covered conceptually in this conversation, not yet built.

## Suggested order to close them

1. VNet + subnet + NSG (+ optionally a VM or AKS) lab — closes networking and compute
   gaps together, and is a natural place to also build the shared `networking` module
   reused by an `app-stack` module, closing the multi-module composition gap.
2. GitHub Actions plan/apply pipeline against the existing `05-Lab-RemoteState-backend`
   backend — closes the CI/CD gap.
3. `terraform_remote_state` data source example reading outputs from
   `04-AzTerraform`/`05-Lab-RemoteState-backend` into a new config.
4. `moved`/`import` blocks — small addition to an existing lab.
5. tfsec or Checkov run added to the CI/CD pipeline from step 2 — closes policy/testing
   gap in the same pass.
6. Provider aliasing / multi-region — optional, lower priority unless targeting
   platform/infra-at-scale roles.
7. Sentinel/OPA — only if targeting Terraform Enterprise/Cloud-heavy roles.
