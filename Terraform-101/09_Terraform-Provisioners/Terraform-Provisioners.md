# 9. Terraform Provisioners — *26:06*

| # | Topic | Duration |
|---|-------|----------|
| 1 | Introduction to AWS EC2 (optional) | 04:25 |
| 2 | Demo: Deploying an EC2 Instance (optional) | 05:52 |
| 3 | AWS EC2 with Terraform | 05:51 |
| 4 | Terraform Provisioners | 05:03 |
| 5 | Provisioner Behaviour | 02:23 |
| 6 | Lab: AWS EC2 and Provisioners | — |
| 7 | Considerations with Provisioners | 02:32 |

## Notes

### What are Terraform Provisioners?

Terraform provisioners are used to perform configuration management tasks on resources after they are created or before they are destroyed. They allow you to run scripts, commands, or other actions to configure instances, install software, or perform cleanup operations. Provisioners bridge the gap between Terraform and configuration management tools.

---

### Types of Provisioners

#### 1. **remote-exec**
- Executes commands **on the remote resource** (e.g., EC2 instance)
- Requires network connectivity to the resource (SSH or WinRM)
- Commonly used to:
  - Run setup scripts on instances
  - Install software packages
  - Start services
  - Configure applications
- Example use case: Install Docker on an EC2 instance after creation

#### 2. **local-exec**
- Executes commands **on the machine running Terraform** (local machine)
- Useful for running local scripts or tools
- Commonly used to:
  - Trigger local scripts or tools
  - Send notifications
  - Generate local files
  - Call APIs or webhooks
- Example use case: Run a local script to register the instance in a monitoring system

---

### Execution Timing

#### **Create-Time Provisioners** (Default)
- Provisioners run **after the resource is created**
- Most common and default behavior
- Useful for initial configuration and setup
- Example: Install and configure software immediately after instance creation

#### **Destroy-Time Provisioners**
- Provisioners run **before the resource is destroyed**
- Created by setting `when = destroy`
- Useful for cleanup operations
- Example: Gracefully shutdown an application or deregister an instance before termination
- If a destroy provisioner fails, the resource is marked as tainted (not destroyed)

---

### Use Cases

1. **Initial Configuration**: Install software, configure settings, run initialization scripts
2. **Integration**: Register instances with load balancers, monitoring systems, or service registries
3. **Cleanup**: Gracefully shutdown applications, deregister instances, cleanup resources
4. **Notifications**: Send alerts or notifications when resources are created/destroyed
5. **Local Actions**: Run local scripts that depend on resource creation

---

### Failure Behavior

- **If a provisioner fails during creation**:
  - The resource is created but marked as **tainted**
  - Terraform considers the configuration drift
  - The resource will be destroyed and recreated on the next `terraform apply`
  - This indicates that the resource creation completed but configuration failed

- **If a destroy provisioner fails**:
  - The resource is marked as **tainted**
  - The resource is **not destroyed** until the issue is resolved
  - Manual intervention may be required

---

### Pros and Cons

#### **Pros:**
- Simple to use for basic configuration tasks
- Works with any resource type
- No additional tools required for simple scripts
- Useful for one-off or procedural configurations

#### **Cons:**
- **Not idempotent by default**: Re-running the same provisioner may have unintended side effects
- **Not recommended by Terraform**: Official documentation suggests avoiding provisioners when possible
- **Difficult to debug**: Errors are harder to track and reproduce
- **Tainting creates drift**: Failed provisioners mark resources as tainted, requiring replacement
- **No state management**: Provisioners don't track their own state, making it hard to know what was applied
- **Can slow down deployments**: Running scripts during provisioning increases deployment time
- **Difficult to implement retries**: Limited error handling and retry mechanisms
- **Not suitable for complex configurations**: Better handled by dedicated configuration management tools

---

### Best Practice: Avoid Provisioners When Possible

**It's always better to avoid provisioners** for these reasons:

#### **1. Use Cloud Provider-Specific User Data/Initialization**

Different cloud providers offer native initialization options that are much better than provisioners:

| Provider | Resource | Option | Purpose |
|----------|----------|--------|---------|
| **AWS** | `aws_instance` | `user_data` | Pass initialization scripts to EC2 instances |
| **Azure** | `azurerm_virtual_machine` | `custom_data` | Pass initialization scripts to Azure VMs |
| **GCP** | `google_compute_instance` | `metadata` | Pass metadata and startup scripts to GCP instances |
| **VMware vSphere** | `vsphere_virtual_machine` | `user_data.txt` | Pass initialization data to vSphere VMs |

**Example - AWS with user_data:**
```hcl
resource "aws_instance" "webserver" {
  ami           = "ami-0edab43b6fa892279"
  instance_type = "t2.micro"
  
  tags = {
    Name        = "webserver"
    Description = "An NGINX WebServer on Ubuntu"
  }
  
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update
              sudo apt install nginx -y
              systemctl enable nginx
              systemctl start nginx
              EOF
}
```

**Example - Azure with custom_data:**
```hcl
resource "azurerm_virtual_machine" "example" {
  name                  = "example-vm"
  location              = azurerm_resource_group.example.location
  resource_group_name   = azurerm_resource_group.example.name
  vm_size               = "Standard_B2s"
  
  custom_data = base64encode(file("${path.module}/init-script.sh"))
}
```

**Benefits:**
- ✓ Runs during instance creation (not after)
- ✓ No separate SSH connection needed
- ✓ Cleaner separation of concerns
- ✓ Cloud-native approach

---

#### **2. Use Configuration Management Tools**

Leverage Ansible, Chef, Puppet, or other tools for complex configurations:
```bash
# After infrastructure is created with Terraform
terraform apply
ansible-playbook -i hosts.ini configure.yml
```

---

#### **3. Use Container Images**

Build Docker images with all configurations baked in:
```hcl
resource "aws_instance" "app" {
  ami           = "ami-with-docker-installed"
  instance_type = "t2.micro"
  
  user_data = <<-EOF
              #!/bin/bash
              docker pull myregistry/myapp:latest
              docker run -d myregistry/myapp:latest
              EOF
}
```

---

#### **4. Use Cloud-Init**

For cloud resources, cloud-init provides a standardized way to pass initialization data:
```hcl
user_data = <<-EOF
            #cloud-config
            packages:
              - nginx
              - git
            runcmd:
              - systemctl enable nginx
              - systemctl start nginx
            EOF
```

---

#### **5. Use Infrastructure as Code Properly**

Keep all configuration declarative, not procedural. Separate concerns:
- **Terraform**: Infrastructure provisioning
- **Ansible/Chef**: Configuration management
- **Docker**: Application containerization

---

### When Provisioners Might Be Necessary

- Quick troubleshooting or one-off deployments
- Legacy integrations that require specific script execution
- Simple, non-critical setup tasks (not production critical)
- When you absolutely need to run something on a resource after creation with no other option

**Summary**: Provisioners are a last resort. They add complexity, make debugging harder, and introduce state management issues. Always prefer declarative approaches like user data, container images, or configuration management tools.
