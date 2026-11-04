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

## Interview Quick Hits
- **Why `toset` with `for_each`?** `for_each` needs unique keys. Sets guarantee uniqueness, lists don't.
- **`lookup` vs `map[key]`?** `lookup` lets you set a default. `map[key]` errors if the key is missing (or use `try(map[key], default)`).
- **`file` vs `templatefile`?** `file` reads the file exactly as it is. `templatefile` fills in `${}` placeholders and `%{ for }` loops.
- **How do you avoid hardcoding subnet CIDRs?** Use `cidrsubnet(var.vnet_cidr, newbits, index)` with `count`/`for_each`, so changing the VNet range automatically recalculates every subnet.
- **Locals vs variables?** Variables are inputs the caller can override. Locals are internal values worked out from those inputs, and nobody outside the module can override them.
- **Avoid `timestamp()` in tags.** It causes a permanent diff on every plan.
