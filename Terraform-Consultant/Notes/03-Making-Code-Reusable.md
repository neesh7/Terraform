# Making Code Reusable

## 1. Built-in Functions

Terraform ships with a fixed set of **built-in functions** that you call inside expressions to transform and combine values.

```hcl
<FUNCTION_NAME>(<ARG1>, <ARG2>, ...)
```

## Important Points (Exam)
1. You **cannot write your own functions** in HCL. You only get the built-in ones (plus **provider-defined functions** from TF 1.8+, called as `provider::<provider>::<function>()`)
2. Test any function interactively with **`terraform console`**
3. Functions are evaluated during **plan**. Some, like `timestamp()` and `uuid()`, return a new value on every run, which causes a diff each time
4. Use the **expansion symbol `...`** to pass a list as separate arguments: `max(var.numbers...)`
5. Function names are always **lowercase**

```bash
$ terraform console
> max(5, 12, 9)
12
> join("-", ["rg", "app", "dev"])
"rg-app-dev"
```

---

### Numeric Functions
| Function | Example | Result |
|---|---|---|
| `min` | `min(5, 12, 9)` | `5` |
| `max` | `max(5, 12, 9)` | `12` |
| `ceil` | `ceil(4.1)` | `5` |
| `floor` | `floor(4.9)` | `4` |
| `abs` | `abs(-7)` | `7` |
| `pow` | `pow(2, 3)` | `8` |
| `signum` | `signum(-4)` | `-1` |
| `parseint` | `parseint("FF", 16)` | `255` |

```hcl
variable "disk_sizes" { default = [32, 128, 64] }

locals {
  largest_disk = max(var.disk_sizes...)   # 128, list expanded with ...
}
```
> **Gotcha:** `min`/`max` take **separate numbers, not a list**. `max([1, 2])` fails, `max([1, 2]...)` works.

---

### String Functions
| Function | Example | Result |
|---|---|---|
| `join` | `join(",", ["a", "b", "c"])` | `"a,b,c"` |
| `split` | `split(",", "a,b,c")` | `["a", "b", "c"]` |
| `upper` / `lower` | `upper("dev")` | `"DEV"` |
| `title` | `title("hello world")` | `"Hello World"` |
| `format` | `format("vm-%03d", 7)` | `"vm-007"` |
| `replace` | `replace("rg_app_dev", "_", "-")` | `"rg-app-dev"` |
| `substr` | `substr("terraform", 0, 4)` | `"terr"` |
| `trimspace` | `trimspace("  hi  ")` | `"hi"` |
| `trimprefix` / `trimsuffix` | `trimsuffix("app.tf", ".tf")` | `"app"` |
| `startswith` / `endswith` | `startswith("prod-vm", "prod")` | `true` |
| `strrev` | `strrev("abc")` | `"cba"` |

- **`join` = list → string**, **`split` = string → list**. They are opposites
- `format` uses printf-style verbs: `%s` string, `%d` number, `%03d` zero-padded
- `replace` also accepts a regex when the search string is wrapped in slashes: `replace("a1b2", "/[0-9]/", "")` → `"ab"`
- **String interpolation** `"${var.env}-rg"` is often simpler than `format`

```hcl
locals {
  name_prefix = lower(join("-", [var.project, var.env]))   # "myapp-dev"
  subnets     = split(",", var.subnet_csv)                 # "a,b,c" → ["a","b","c"]
}
```

---

### Collection Functions
| Function | Example | Result |
|---|---|---|
| `length` | `length(["a", "b"])` | `2` (also works on maps and strings) |
| `element` | `element(["a", "b", "c"], 3)` | `"a"` (**wraps around**) |
| `index` | `index(["a", "b"], "b")` | `1` |
| `contains` | `contains(["dev", "prod"], "dev")` | `true` |
| `concat` | `concat(["a"], ["b", "c"])` | `["a", "b", "c"]` |
| `flatten` | `flatten([["a"], ["b", ["c"]]])` | `["a", "b", "c"]` |
| `distinct` | `distinct(["a", "b", "a"])` | `["a", "b"]` |
| `slice` | `slice(["a", "b", "c", "d"], 1, 3)` | `["b", "c"]` (end is **exclusive**) |
| `sort` | `sort(["c", "a", "b"])` | `["a", "b", "c"]` |
| `keys` / `values` | `keys({b = 2, a = 1})` | `["a", "b"]` (sorted by key) |
| `lookup` | `lookup(var.sizes, "dev", "Standard_B1s")` | value, or the default if the key is missing |
| `merge` | `merge({a = 1}, {a = 2, b = 3})` | `{a = 2, b = 3}` (**last one wins**) |
| `zipmap` | `zipmap(["a", "b"], [1, 2])` | `{a = 1, b = 2}` |
| `coalesce` | `coalesce("", "default")` | `"default"` (first non-empty value) |

```hcl
locals {
  common_tags = { owner = "neesh", env = "dev" }
  # merge is the standard way to add resource-specific tags to common tags
  vm_tags     = merge(local.common_tags, { role = "web" })

  vm_size     = lookup(var.vm_sizes, var.env, "Standard_B1s")
}
```
> **Gotchas:** `element` wraps around (index 3 on a 3-item list gives item 0), while `list[3]` throws an error. With `merge`, keys in later maps **overwrite** earlier ones.

#### `merge()` in Detail
Combines two or more **maps/objects** into one: `merge(map1, map2, ...)`
```hcl
> merge({env = "dev", owner = "neesh"}, {env = "prod"})
{ env = "prod", owner = "neesh" }          # same key → the LAST map wins

> merge({tags = {a = 1}}, {tags = {b = 2}})
{ tags = { b = 2 } }                       # shallow merge: the nested map is replaced, a is lost
```
1. **If a key appears more than once, the last map wins.** Put defaults first and overrides last
2. **It's a shallow merge.** Only top-level keys are combined, and nested maps are **replaced, not merged**
3. It takes separate maps, not a list. Expand a list with `merge(var.list_of_maps...)`
4. `merge()` with no arguments returns `{}`

```hcl
# Default + override pattern
locals {
  default_settings = { sku = "Standard", replicas = 1 }
  settings         = merge(local.default_settings, var.overrides)   # caller can override any key
}
```

---

### Type Conversion Functions
| Function | Example | Result |
|---|---|---|
| `toset` | `toset(["a", "b", "a"])` | `toset(["a", "b"])` (duplicates removed, **no order**) |
| `tolist` | `tolist(toset(["b", "a"]))` | `["a", "b"]` |
| `tomap` | `tomap({a = 1, b = 2})` | `{a = 1, b = 2}` |
| `tostring` | `tostring(5)` | `"5"` |
| `tonumber` | `tonumber("5")` | `5` (`tonumber("abc")` → **error**) |
| `tobool` | `tobool("true")` | `true` |

**Why `toset` matters most:** `for_each` only accepts a **map or a set of strings**, never a list. So converting a list with `toset()` is very common:
```hcl
variable "rg_names" { default = ["rg-web", "rg-db", "rg-web"] }

resource "azurerm_resource_group" "rg" {
  for_each = toset(var.rg_names)    # duplicate "rg-web" dropped → 2 RGs
  name     = each.value
  location = "eastus"
}
```
- A **set has no index**, so `toset(var.x)[0]` fails. Convert back with `tolist()` if you need indexing
- Terraform does a lot of **automatic conversion** (e.g. `"5"` ↔ `5`), so explicit conversion is mainly needed for `for_each` and for making types clear in outputs and modules

---

### IP Network Functions
Use these to work out subnet ranges and IPs from one address space instead of hardcoding them.

| Function | Example | Result |
|---|---|---|
| `cidrsubnet(prefix, newbits, netnum)` | `cidrsubnet("10.0.0.0/16", 8, 2)` | `"10.0.2.0/24"` |
| `cidrsubnets(prefix, newbits...)` | `cidrsubnets("10.0.0.0/16", 8, 8, 4)` | `["10.0.0.0/24", "10.0.1.0/24", "10.0.16.0/20"]` |
| `cidrhost(prefix, hostnum)` | `cidrhost("10.0.1.0/24", 5)` | `"10.0.1.5"` |
| | `cidrhost("10.0.1.0/24", -2)` | `"10.0.1.254"` (negative numbers count from the end) |
| `cidrnetmask(prefix)` | `cidrnetmask("10.0.0.0/16")` | `"255.255.0.0"` (IPv4 only) |

**How `cidrsubnet` works:**
- `newbits` = how many bits to **add** to the prefix. `/16` + 8 = `/24`
- `netnum` = **which** subnet of that size to pick (starting at 0). `/16` + 8 bits gives 256 `/24` subnets, numbered 0–255
- `cidrsubnets` hands out several **consecutive, non-overlapping** subnets in one call. Each argument is the `newbits` for one subnet, so the sizes can be different

```hcl
variable "vnet_cidr" { default = "10.0.0.0/16" }
variable "subnets"   { default = ["web", "app", "db"] }

resource "azurerm_subnet" "snet" {
  count                = length(var.subnets)
  name                 = "snet-${var.subnets[count.index]}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, count.index)]   # 10.0.0.0/24, 10.0.1.0/24, 10.0.2.0/24
}

locals {
  # Static private IP: Azure reserves .0–.3 in every subnet, so .4 is the first usable one
  nic_private_ip = cidrhost(azurerm_subnet.snet[0].address_prefixes[0], 4)   # "10.0.0.4"
}
```
> **Gotchas:** You get an error if prefix + `newbits` goes past `/32` (IPv4), e.g. `cidrsubnet("10.0.0.0/28", 8, 0)`, or if `netnum` is bigger than `2^newbits - 1`, e.g. `cidrsubnet("10.0.0.0/16", 2, 4)` (only subnets 0–3 exist). These functions **only do the maths**. They don't check whether the IP is free or reserved in the cloud.

---

### Other Commonly Used Functions
| Category | Function | Use |
|---|---|---|
| Filesystem | `file("script.sh")` | Read a file as a string (e.g. VM `custom_data`) |
| | `templatefile("init.tpl", { name = "web" })` | Render a template with variables |
| | `fileexists("x.txt")` | Check if a file exists |
| Encoding | `jsonencode()` / `jsondecode()` | Map ↔ JSON string (IAM / Azure policies) |
| | `yamlencode()` / `yamldecode()` | Map ↔ YAML string |
| | `base64encode()` / `base64decode()` | e.g. Azure VM `custom_data` must be base64 |
| Date/Time | `timestamp()` | Current UTC time (**changes every run**) |
| | `formatdate("YYYY-MM-DD", timestamp())` | Format a timestamp |
| Hash/Crypto | `md5()`, `sha256()`, `uuid()` | Hashes / random ID |
| Error handling | `try(var.obj.key, "default")` | Return the first expression that doesn't error |
| | `can(regex("^rg-", var.name))` | `true`/`false`, mostly used in `validation` blocks |
| Sensitive | `sensitive()` / `nonsensitive()` | Mark or unmark a value as sensitive |

```hcl
resource "azurerm_linux_virtual_machine" "vm" {
  # ...
  custom_data = base64encode(templatefile("${path.module}/cloud-init.tpl", {
    hostname = "web01"
  }))
}

variable "rg_name" {
  type = string
  validation {
    condition     = can(regex("^rg-", var.rg_name))
    error_message = "Resource group name must start with 'rg-'."
  }
}
```

---

## 2. Enhancing Code with Dynamic Values
Hardcoded values make code good for one setup only. Work values out at runtime instead, so the **same code works for any env, region or team**.

| Source | Syntax | Example |
|---|---|---|
| Input variables | `var.<name>` | `var.location` |
| Locals (computed once, reused) | `local.<name>` | `local.name_prefix` |
| Resource attributes | `<type>.<name>.<attr>` | `azurerm_resource_group.rg.name` |
| Data sources (existing infra) | `data.<type>.<name>.<attr>` | `data.azurerm_client_config.current.tenant_id` |
| Interpolation | `"${...}"` | `"rg-${var.project}-${var.env}"` |
| Conditional expression | `cond ? true_val : false_val` | `var.env == "prod" ? "Standard_D2s_v5" : "Standard_B1s"` |
| `for` expression | `[for x in list : expr]` | `[for s in var.subnets : upper(s)]` |
| Built-in values | `path.module`, `terraform.workspace` | `"${path.module}/init.tpl"` |

```hcl
locals {
  name_prefix = "${var.project}-${terraform.workspace}"            # myapp-dev / myapp-prod
  is_prod     = terraform.workspace == "prod"
  tags        = merge(var.common_tags, { env = terraform.workspace })
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_linux_virtual_machine" "vm" {
  count               = local.is_prod ? 2 : 1                          # conditional resource count
  name                = "vm-${local.name_prefix}-${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg.name                 # reference = implicit dependency
  size                = local.is_prod ? "Standard_D2s_v5" : "Standard_B1s"
  # ...
}
```
- **Referencing another resource's attribute creates an implicit dependency**, so Terraform works out the creation order itself
- Use **locals** for values used in more than one place (DRY). Use **variables** for values the caller should be able to change
- Both results of a conditional must be the **same type**
- `count = cond ? 1 : 0` is the usual way to **create a resource only when a condition is true**

---

## 3. Using Locals to Avoid Code Duplication
A **local value** gives a name to an expression. Define it **once**, then reuse it everywhere. If it changes, you edit one line instead of every resource.

**Before (repeated values):**
```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-myapp-dev"
  location = "eastus"
  tags     = { project = "myapp", env = "dev", owner = "neesh" }
}

resource "azurerm_storage_account" "st" {
  name                = "stmyappdev"
  location            = "eastus"
  tags                = { project = "myapp", env = "dev", owner = "neesh" }
  # ...
}
```

**After (with locals):**
```hcl
locals {
  name_prefix = "${var.project}-${var.env}"
  location    = var.location
  common_tags = {
    project = var.project
    env     = var.env
    owner   = "neesh"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.name_prefix}"
  location = local.location
  tags     = local.common_tags
}

resource "azurerm_storage_account" "st" {
  name     = replace("st${local.name_prefix}", "-", "")   # storage names allow no hyphens
  location = local.location
  tags     = merge(local.common_tags, { tier = "data" })  # reuse + extend
  # ...
}
```

### Important Points (Exam)
1. The block is **`locals`** (plural). You reference a value as **`local.<name>`** (singular)
2. Locals **cannot be set from outside** (no CLI flag, no `.tfvars`, no env var). That is what makes them different from variables
3. A local can reference **variables, resources, data sources, functions and other locals**. Variables can't do that (their `default` must be a literal)
4. You can have **multiple `locals` blocks**, but every name must be unique within the module
5. Locals are **scoped to their module**. A child module can't see the parent's locals
6. **Circular references** between locals cause an error

### Locals vs Variables
| | `variable` | `locals` |
|---|---|---|
| Purpose | Input from the caller / user | Value computed inside the module |
| Set from outside? | Yes (`-var`, `.tfvars`, `TF_VAR_`) | No |
| Can use expressions / functions? | Only in `validation` (default must be a literal) | Yes |
| Analogy | Function **parameter** | Function's **local variable** |

> **Tip:** Don't overuse locals. Wrapping every single value in a local hides where it comes from. Use them for values that are **repeated** or **calculated**.

---

## 4. Meta-Arguments: `count` and `for_each`
**Meta-arguments** are special arguments built into Terraform. They work on **any resource** (and on modules) and change how Terraform handles that block, not how the provider configures the resource. The full list (`depends_on`, `provider`, `lifecycle`...) is in [01 › Meta-Arguments](01-Terraform_Configurations.md). This section covers the two **looping** ones: `count` (N copies) and `for_each` (one copy per map/set item).

### `count`
```hcl
variable "rg_names" { default = ["rg-web", "rg-app", "rg-db"] }

resource "azurerm_resource_group" "rg" {
  count    = length(var.rg_names)
  name     = var.rg_names[count.index]     # count.index = 0, 1, 2
  location = "eastus"
}
```
- Instances are addressed by **number**: `azurerm_resource_group.rg[0]`, `rg[1]` ...
- Get all of them with a **splat**: `azurerm_resource_group.rg[*].name`
- **Conditional resource:** `count = var.create_rg ? 1 : 0`

> **The `count` index problem:** if you remove `"rg-web"` (index 0) from the list, every item shifts down by one. Terraform then sees `rg[0]` change from rg-web to rg-app and `rg[1]` from rg-app to rg-db, so it **destroys and recreates** resources you never touched. Use `count` only for **identical** copies or on/off toggles.

### `for_each`
```hcl
# With a set of strings
resource "azurerm_resource_group" "rg" {
  for_each = toset(["rg-web", "rg-app", "rg-db"])
  name     = each.value                 # with a set, each.key == each.value
  location = "eastus"
}

# With a map (when each instance needs different settings)
variable "subnets" {
  default = {
    web = "10.0.1.0/24"
    db  = "10.0.2.0/24"
  }
}

resource "azurerm_subnet" "snet" {
  for_each             = var.subnets
  name                 = "snet-${each.key}"          # web, db
  address_prefixes     = [each.value]                 # 10.0.1.0/24, 10.0.2.0/24
  resource_group_name  = azurerm_resource_group.rg["rg-app"].name
  virtual_network_name = azurerm_virtual_network.vnet.name
}
```
- Instances are addressed by **key**: `azurerm_subnet.snet["web"]`
- Removing one key removes **only that instance**. The others stay as they are
- Get all of them with a **`for` expression** (splat doesn't work on maps): `[for s in azurerm_subnet.snet : s.id]` or `values(azurerm_subnet.snet)[*].id`

### `count` vs `for_each`
| | `count` | `for_each` |
|---|---|---|
| Input | A whole number | A **map** or a **set of strings** (not a list) |
| Iterator | `count.index` | `each.key`, `each.value` |
| Address | `res.name[0]` | `res.name["key"]` |
| Remove a middle item | Items after it shift → **recreated** | Only that item is destroyed |
| Best for | Identical copies, on/off toggle | Distinct items with their own settings |

### Important Points (Exam)
1. You **can't use `count` and `for_each` in the same block**
2. The value must be **known at plan time**. You can't base it on an attribute that only exists after apply (e.g. a generated resource ID)
3. `for_each` takes **only a map or a set of strings**, so wrap lists with `toset()`. With a set, `each.key` and `each.value` are the same
4. Both work on **modules** too (since TF 0.13): `module "vnet" { for_each = var.envs ... }`
5. Moving from `count` to `for_each` changes resource addresses. Use a **`moved` block** or `terraform state mv` so Terraform doesn't destroy and recreate them
6. Sensitive values can't be used as `for_each` keys

---

## 5. Refactoring Without Recreating (State Refactoring)
Making code reusable usually means **renaming resources, switching `count` → `for_each`, or moving code into modules**. Each of these **changes the resource address**. Terraform then sees the old address as gone and the new one as new, so it plans **destroy + create**, even though the real resource hasn't changed.

**The fix:** tell Terraform that the old address is now the new address, so it **updates state only** and changes no real infrastructure.
- **`moved` block** (TF 1.1+, preferred): declarative, shown in `plan`, reviewed in PRs, and works for every workspace/env
- **`terraform state mv`** (CLI): a one-off command, not reviewed, and you have to run it separately for each state

> Block details are in **section 6** below. This section covers the common **refactoring scenarios**.

### Common Scenarios
```hcl
# 1. Rename a resource
moved {
  from = azurerm_resource_group.rg
  to   = azurerm_resource_group.main
}

# 2. count → for_each (one moved block per instance)
moved {
  from = azurerm_subnet.snet[0]
  to   = azurerm_subnet.snet["web"]
}
moved {
  from = azurerm_subnet.snet[1]
  to   = azurerm_subnet.snet["db"]
}

# 3. Move a resource into a module
moved {
  from = azurerm_virtual_network.vnet
  to   = module.network.azurerm_virtual_network.vnet
}

# 4. Rename a module (moves everything inside it)
moved {
  from = module.net
  to   = module.network
}

# 5. Add for_each to an existing single resource/module
moved {
  from = module.network
  to   = module.network["dev"]
}
```

### Workflow
1. Change the code (rename, `for_each`, module...)
2. Add the `moved` blocks (keep them in a `moved.tf` file)
3. `terraform plan`: it should say **`has moved to`** and show **`0 to add, 0 to destroy`**
4. `terraform apply`: only the state is updated
5. **Keep the `moved` blocks** for a while. Other workspaces or other people's states may not have applied them yet. Remove them only once **every** state has been updated

### Important Points (Exam)
1. A refactor that changes a **resource address** without `moved`/`state mv` = **destroy + recreate**
2. `moved` only changes **state**. It never changes the real resource
3. Generally `from` and `to` must be the **same resource type**. You can't use `moved` to turn one type into another (only a few providers support cross-type moves, TF 1.8+)
4. Moving a whole module moves **everything inside it**
5. Related blocks: **`removed`** = stop managing a resource without destroying it. **`import`** = start managing an existing resource
6. **Always back up state first** for CLI refactors: `terraform state pull > backup.tfstate`

---

## 6. `moved`, `removed` and `import` Blocks
Three **config-driven** blocks that change **state** through the normal `plan` → `apply` workflow. Because they are code, they're reviewed in PRs, previewed in `plan`, and applied the same way to every environment. They replace the imperative CLI commands.

| Block | Version | Replaces | What it does | Real infra changed? |
|---|---|---|---|---|
| `moved` | 1.1+ | `terraform state mv` | Changes a resource's **address** in state | No |
| `removed` | 1.7+ | `terraform state rm` | **Stops managing** a resource (forgets it from state) | No (if `destroy = false`) |
| `import` | 1.5+ | `terraform import` | **Starts managing** an existing resource (adds it to state) | No |

### `moved` block
```hcl
moved {
  from = azurerm_resource_group.rg         # old address
  to   = azurerm_resource_group.main       # new address
}
```
- Arguments: only **`from`** and **`to`**
- Works on resources, resource instances (`[0]`, `["web"]`) and whole modules (`module.net`)
- Plan output: `azurerm_resource_group.rg has moved to azurerm_resource_group.main`
- **Chaining works:** if A → B and later B → C, keep both blocks, and states still at A will reach C
- `to` must **not already exist** in state, or you get an error
- `moved` does **not** support `for_each`. Write one block per instance

### `removed` block
```hcl
# 1. Delete the resource block from the config
# 2. Add this instead:
removed {
  from = azurerm_key_vault.kv

  lifecycle {
    destroy = false     # false = keep the real resource, only forget it from state
  }                     # true  = destroy it (same as just deleting the block)
}
```
- Use it to **hand a resource over** to another team or config, or to stop managing something without deleting it
- **The resource block must be removed** from the config, or you get an error (it can't be in both)
- `from` takes a **resource or module address without instance keys**: `azurerm_key_vault.kv` works, `azurerm_key_vault.kv[0]` doesn't. It applies to all instances
- Plan output: `azurerm_key_vault.kv will no longer be managed by Terraform`
- Can contain **destroy-time provisioners** (TF 1.9+) when `destroy = true`

### `import` block
```hcl
import {
  to = azurerm_resource_group.rg
  id = "/subscriptions/<sub-id>/resourceGroups/rg-existing"   # ID format depends on the provider/resource
}

resource "azurerm_resource_group" "rg" {        # write it yourself, or generate it (see below)
  name     = "rg-existing"
  location = "eastus"
}
```
```bash
# Let Terraform write the resource block for you
terraform plan -generate-config-out=generated.tf
```
- Arguments: **`to`** (address), **`id`** (cloud resource ID), optional **`provider`** (for an aliased provider)
- **`for_each` is supported** (TF 1.7+), so you can import many resources with one block:
  ```hcl
  import {
    for_each = var.existing_rgs                   # map: { web = "/subscriptions/.../rg-web", ... }
    to       = azurerm_resource_group.rg[each.key]
    id       = each.value
  }
  ```
- `id` can use expressions, but they must be **known at plan time** (TF 1.6+)
- Only allowed in the **root module**, but `to` can point inside a child module (`module.network.azurerm_virtual_network.vnet`)
- **Idempotent:** once a resource is imported, the block does nothing, so it's safe to leave in. Remove it in a follow-up PR
- `-generate-config-out` file **must not already exist**. Generated code is a starting point, so clean it up (use variables, remove default/computed values)
- Goal: `plan` shows **`N to import, 0 to add, 0 to change, 0 to destroy`**

### Import Workflow 1: `import` block + `-generate-config-out` (recommended)
Use this when you **don't have the resource code yet**. Terraform reads the real resource and writes the HCL for you.
```hcl
# imports.tf (just the import block, NO resource block)
import {
  to = azurerm_storage_account.st
  id = "/subscriptions/<sub-id>/resourceGroups/rg-app/providers/Microsoft.Storage/storageAccounts/stapp001"
}
```
```bash
terraform init
terraform plan -generate-config-out=generated.tf   # 1. writes the resource block into generated.tf
# 2. review / clean up generated.tf
terraform plan                                      # 3. check: "1 to import, 0 to add, 0 to change, 0 to destroy"
terraform apply                                     # 4. now the resource is in state
```
- Generates config **only for import blocks that don't have a resource block yet**
- `generated.tf` **must not already exist** (Terraform won't overwrite it)
- The generated code contains **every attribute**, including defaults. Clean it up: replace hardcoded values with variables/references, delete unneeded defaults, and move it into the right file
- If the generated config has **conflicting attributes**, the plan shows an error. Fix `generated.tf` and run `plan` again
- **Nothing is in state until `apply`.** `plan` only previews the import
- Config generation is **still marked experimental** and doesn't work with `for_each` import blocks

### Import Workflow 2: `terraform import` CLI (old way)
Use this for a **quick, one-off** import when the resource code already exists.
```bash
# 1. Write the resource block yourself first (the CLI does NOT generate it)
# 2. Import (writes to state IMMEDIATELY, no plan, no apply)
terraform import azurerm_resource_group.rg /subscriptions/<sub-id>/resourceGroups/rg-existing

# count / for_each instances need quotes
terraform import 'azurerm_subnet.snet[0]' <id>
terraform import 'azurerm_subnet.snet["web"]' <id>                 # bash
terraform import 'azurerm_subnet.snet[\"web\"]' <id>               # PowerShell

# Into a module
terraform import module.network.azurerm_virtual_network.vnet <id>

# 3. Check that the code matches the real resource
terraform plan    # should be "No changes". Fix the code until it is
```
- **The resource block must exist first**, or you get the error *"resource address does not exist in the configuration"*
- Imports **one resource per command** and **changes state right away**, with no review
- Has to be run again **by hand for each workspace/state**, so it isn't repeatable in CI/CD

### `import` block vs `terraform import`
| | `import` block | `terraform import` CLI |
|---|---|---|
| Generates config | Yes (`plan -generate-config-out`) | **No**, you write it first |
| Preview before state changes | Yes (`plan`) | **No**, state changes immediately |
| Many resources at once | Yes (`for_each`, TF 1.7+) | One per command |
| Code review / CI/CD | Yes, it's in the code | No |
| When state changes | On `apply` | When the command runs |

### Important Points (Exam)
1. **None of the three changes real infra** (except `removed` with `destroy = true`). They only change state
2. **Blocks vs CLI:** blocks are planned, reviewed and repeatable. CLI commands change state **immediately**, with no plan
3. `terraform import` (CLI) **doesn't generate config**. Only the `import` block + `-generate-config-out` can do that
4. `removed` needs the resource block **gone** from the config. `import` needs a resource block (written or generated)
5. `moved` → you renamed it. `removed` → you don't want to manage it any more. `import` → you want to start managing it

## Interview Quick Hits
- **Why `toset` with `for_each`?** `for_each` needs unique keys. Sets guarantee uniqueness, lists don't.
- **`lookup` vs `map[key]`?** `lookup` lets you set a default. `map[key]` errors if the key is missing (or use `try(map[key], default)`).
- **`file` vs `templatefile`?** `file` reads the file exactly as it is. `templatefile` fills in `${}` placeholders and `%{ for }` loops.
- **How do you avoid hardcoding subnet CIDRs?** Use `cidrsubnet(var.vnet_cidr, newbits, index)` with `count`/`for_each`, so changing the VNet range automatically recalculates every subnet.
- **Locals vs variables?** Variables are inputs the caller can override. Locals are internal values worked out from those inputs, and nobody outside the module can override them.
- **`count` or `for_each`?** Use `for_each` for anything that can be added or removed on its own. Use `count` only for identical copies or a `? 1 : 0` toggle, because removing an item from a `count` list shifts the indexes and recreates resources.
- **How do you move resources into a module without downtime?** Add `moved` blocks (old address → `module.x.<address>`), check that the plan shows only "has moved" with nothing destroyed, then apply. Prefer this over `state mv`, because it's reviewed in the PR and applies to every environment.
- **How do you hand a resource from one Terraform config to another?** In the old config, delete the block and add `removed { lifecycle { destroy = false } }`. In the new config, add an `import` block with the same resource ID. Apply old, then new. The real resource is never touched.
- **How do you bring 50 manually created Azure resources under Terraform?** Write one `import` block per resource, run `terraform plan -generate-config-out=generated.tf`, clean up the code (refactor repeated resources into `for_each` + `moved` blocks if needed), plan until it shows only imports with 0 changes, then apply. Don't run `terraform import` 50 times by hand.
- **Avoid `timestamp()` in tags.** It causes a permanent diff on every plan.
