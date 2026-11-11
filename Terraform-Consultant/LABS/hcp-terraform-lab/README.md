# Lab: HCP Terraform – Hello World Python File
**Notes:** [06-HCP_Terraform.md](../../Notes/06-HCP_Terraform.md) · **Time:** ~20 min · **Cost:** free tier

### Goal
Use HCP Terraform (org `neesh7-org1`, workspace `neesh7-dev`) to manage a `hello.py` file created with the `local` provider, and **see the difference between Remote and Local execution mode**.

### Files
| File | Purpose |
|---|---|
| `providers.tf` | `cloud` block (org + workspace), `local` provider |
| `variables.tf` | `file_name` (must end in `.py`), `message` |
| `main.tf` | `local_file` resource that writes the Python script |
| `outputs.tf` | file path, SHA256, run command |

---

### Part 1: Connect and authenticate
```bash
terraform login          # browser opens → create token → paste it → stored in credentials.tfrc.json
terraform init           # connects to HCP Terraform, creates workspace neesh7-dev if it doesn't exist
```
✅ **Verify:** the workspace `neesh7-dev` appears in the HCP Terraform UI.

### Part 2: Remote execution (default)
```bash
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```
✅ **Verify:**
- The plan/apply **logs stream from HCP Terraform** (look for the run URL in the output)
- The run shows in the UI under **Runs**, and state appears under **States**
- ❓ **Is `hello.py` in your folder?** → **No.** The file was created on HCP Terraform's **disposable remote worker**, which is destroyed after the run. Only the **state** knows about it

> **Key lesson:** in Remote mode, Terraform runs on HCP's infrastructure. The `local` provider writes to *that* machine, not yours.

### Part 3: Switch to Local execution
1. UI → workspace `neesh7-dev` → **Settings → General → Execution Mode → Local** → Save
2. Run:
```bash
terraform apply
```
✅ **Verify:**
- Plan shows `local_file.hello_py` will be **created** (state says it exists, but it's missing on your disk → Terraform recreates it)
- `hello.py` now **exists in this folder**
- Run it:
```bash
python hello.py          # → Hello, World!
```
- HCP UI → **States**: a new state version was saved (state is still remote), but **no new Run** appears in Runs

### Part 4: Change a variable
```bash
terraform apply -var 'message=Hello from HCP Terraform!'
python hello.py
```
✅ **Verify:** the plan shows the file being **replaced** (`content` forces replacement), and the script prints the new message.
> In Local mode, **workspace variables set in the UI are ignored**. Pass them via `-var`, `*.auto.tfvars` or `TF_VAR_message`.

### Part 5: Clean up
```bash
terraform destroy
```
Optionally switch the workspace back to **Remote** for the next lab.

---

### Exam takeaways
| Question | Answer |
|---|---|
| Where does code execute in **Remote** mode? | HCP Terraform's managed, disposable workers |
| Where does it execute in **Local** mode? | Your machine. HCP stores **state only** |
| Is execution mode set per org or per workspace? | **Per workspace** (org can set a default) |
| How did the CLI authenticate? | `terraform login` → **user token** in `credentials.tfrc.json` |
| Non-interactive alternative? | `TF_TOKEN_app_terraform_io` env var |
