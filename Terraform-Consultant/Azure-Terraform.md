# Terraform on Azure — Course Syllabus

**Focus:** Terraform state, remote state in Azure Storage, workspaces, and the CLI
**Instructor:** Rithin Skaria (Author | Speaker | Trainer, MCT)

| Modules | Lessons | Video | Labs | Quizzes |
|---|---|---|---|---|
| 22 | 129 | 7.83 hrs | 13 | 21 |

---

## Module Index

> **Est. Study Time** = video × 2 (pausing, notes, re-running demos) + 30 min per lab + 5 min per quiz, rounded to 5 min.

| # | Module | Lessons | Lab | Video | Est. Study Time |
|---|---|---|---|---|---|
| 01 | [Introduction](#01-introduction) | 2 | — | 02:21 | 5m |
| 02 | [Infrastructure as Code Fundamentals](#02-infrastructure-as-code-fundamentals) | 4 | — | 10:49 | 25m |
| 03 | [Terraform Cloud](#03-terraform-cloud) | 5 | — | 13:21 | 30m |
| 04 | [Setting up Environment](#04-setting-up-environment) | 7 | ✅ | 18:02 | 1h 10m |
| 05 | [Azure Context for Terraform](#05-azure-context-for-terraform) | 4 | — | 11:27 | 30m |
| 06 | [HashiCorp Configuration Language](#06-hashicorp-configuration-language) | 8 | ✅ | 44:40 | 2h 05m |
| 07 | [Terraform Providers](#07-terraform-providers) | 8 | ✅ | 36:26 | 1h 50m |
| 08 | [Variables](#08-variables) | 7 | ✅ | 34:59 | 1h 45m |
| 09 | [Outputs and Dependencies](#09-outputs-and-dependencies) | 6 | ✅ | 36:47 | 1h 50m |
| 10 | [Iteration and Logic](#10-iteration-and-logic) | 8 | ✅ | 36:07 | 1h 45m |
| 11 | [Advanced Constructs](#11-advanced-constructs) | 6 | ✅ | 14:35 | 1h 05m |
| 12 | [Terraform State Fundamentals](#12-terraform-state-fundamentals) | 5 | — | 15:21 | 35m |
| 13 | [Remote State](#13-remote-state) | 7 | ✅ | 18:39 | 1h 10m |
| 14 | [Terraform Workspaces](#14-terraform-workspaces) | 6 | ✅ | 14:50 | 1h 05m |
| 15 | [Terraform CLI](#15-terraform-cli) | 8 | ✅ | 17:54 | 1h 10m |
| 16 | [Lifecycle Meta-Arguments](#16-lifecycle-meta-arguments) | 7 | ✅ | 13:57 | 1h 05m |
| 17 | [Data Sources](#17-data-sources) | 4 | — | 12:54 | 30m |
| 18 | [Provisioners](#18-provisioners) | 6 | ✅ | 24:02 | 1h 25m |
| 19 | [Debugging Terraform](#19-debugging-terraform) | 3 | — | 06:39 | 20m |
| 20 | [Terraform Modules](#20-terraform-modules) | 7 | ✅ | 34:18 | 1h 45m |
| 21 | [Azure DevOps Integration](#21-azure-devops-integration) | 6 | — | 18:35 | 40m |
| 22 | [Azure Pipelines for Terraform](#22-azure-pipelines-for-terraform) | 5 | — | 33:40 | 1h 10m |
| | **Total** | **129** | **13** | **7h 50m** | **~24h** |

---

## 01. Introduction
- [ ] Course Introduction — 02:21
- [ ] How to Reach Out to KodeKloud and Engage with the Community

## 02. Infrastructure as Code Fundamentals
- [ ] Introduction — 01:12
- [ ] What is Infrastructure as Code? — 02:29
- [ ] Types of IaC Tools — 07:08
- [ ] Quiz: Infrastructure as Code Fundamentals

## 03. Terraform Cloud
- [ ] Introduction — 00:57
- [ ] What is Terraform Cloud? — 03:12
- [ ] Terraform Cloud Plans — 05:43
- [ ] Self-Hosted vs Terraform Cloud — 03:29
- [ ] Quiz: Terraform Cloud

## 04. Setting up Environment
- [ ] Introduction — 01:23
- [ ] Choose Your IDE — 01:53
- [ ] Installing Dependencies — 05:03
- [ ] Installing Terraform — 05:04
- [ ] Authenticating to Azure — 04:39
- [ ] Lab: Terraform Setup
- [ ] Quiz: Setting Up Environment

## 05. Azure Context for Terraform
- [ ] Introduction — 01:12
- [ ] Azure Concepts Terraform Operates On — 04:17
- [ ] Environment Separation in Azure — 05:58
- [ ] Quiz: Azure Context for Terraform

## 06. HashiCorp Configuration Language
- [ ] Introduction — 02:14
- [ ] HCL Syntax and Building Blocks — 07:05
- [ ] Writing HCL Code — 17:19
- [ ] Multiple Resources — 07:26
- [ ] Update and Destroy Infrastructure — 07:08
- [ ] Modular Structure — 03:28
- [ ] Lab: Azure Resources Terraform
- [ ] Quiz: HashiCorp Configuration Language

## 07. Terraform Providers
- [ ] Introduction — 01:51
- [ ] Handling Providers — 07:04
- [ ] Version Constraints — 07:44
- [ ] Azure Providers: azurerm vs azapi — 12:43
- [ ] When to Use azurerm vs azapi — 03:59
- [ ] Aliases — 03:05
- [ ] Lab: Terraform Providers
- [ ] Quiz: Terraform Providers

## 08. Variables
- [ ] Introduction — 01:37
- [ ] Defining Variables — 06:28
- [ ] Understanding Variable Block — 10:19
- [ ] Setting Variables — 10:07
- [ ] Variable Datatypes — 06:28
- [ ] Lab: Terraform Variables
- [ ] Quiz: Variables

## 09. Outputs and Dependencies
- [ ] Introduction — 00:53
- [ ] Resource Attributes and Dependencies — 20:14
- [ ] Resource Targeting — 07:52
- [ ] Output Variables — 07:48
- [ ] Lab: Terraform Outputs
- [ ] Quiz: Outputs and Dependencies

## 10. Iteration and Logic
- [ ] Introduction — 01:01
- [ ] Using count — 11:30
- [ ] Using for_each — 08:01
- [ ] count vs for_each — 02:20
- [ ] for Expressions — 04:24
- [ ] Conditional Expressions — 08:51
- [ ] Lab: tf Looping and Logic
- [ ] Quiz: Iteration and Logic

## 11. Advanced Constructs
- [ ] Introduction — 01:39
- [ ] Using locals — 02:34
- [ ] Dynamic Blocks — 07:10
- [ ] Built-in Functions — 03:12
- [ ] Lab: Advanced Constructs
- [ ] Quiz: Advanced Constructs

## 12. Terraform State Fundamentals
- [ ] Introduction — 01:23
- [ ] Terraform State Management — 03:12
- [ ] Security Considerations — 02:09
- [ ] Refreshing Infrastructure — 08:37
- [ ] Quiz: Terraform State Fundamentals

## 13. Remote State
- [ ] Introduction — 00:40
- [ ] What is Remote State? — 02:18
- [ ] Azure Storage Backend — 10:41
- [ ] Backend Initialization Lifecycle — 02:12
- [ ] Remote State Failure Modes — 02:48
- [ ] Lab: Remote State
- [ ] Quiz: Remote State

## 14. Terraform Workspaces
- [ ] Introduction — 00:40
- [ ] What Are Terraform Workspaces — 03:49
- [ ] Workspace Commands — 06:46
- [ ] Considerations — 03:35
- [ ] Lab: Terraform Workspaces
- [ ] Quiz: Terraform Workspaces

## 15. Terraform CLI
- [ ] Introduction — 01:04
- [ ] Terraform Validate and fmt — 03:39
- [ ] Terraform Show and Output — 03:27
- [ ] Terraform Providers and Graph — 03:31
- [ ] Terraform State and Refresh — 03:32
- [ ] Terraform Import — 02:41
- [ ] Lab: Terraform CLI
- [ ] Quiz: Terraform CLI

## 16. Lifecycle Meta-Arguments
- [ ] Introduction — 01:16
- [ ] What are lifecycle meta arguments? — 01:43
- [ ] create_before_destroy — 01:56
- [ ] prevent_destroy — 04:26
- [ ] ignore_changes — 04:36
- [ ] Lab: Terraform Lifecycle Meta args
- [ ] Quiz: Lifecycle Meta-Arguments

## 17. Data Sources
- [ ] Introduction — 01:22
- [ ] What are data sources? — 09:39
- [ ] Resources vs Data Sources — 01:53
- [ ] Quiz: Data Sources

## 18. Provisioners
- [ ] Introduction — 01:28
- [ ] Remote Provisioners — 14:48
- [ ] Local Provisioners — 05:25
- [ ] Considerations — 02:21
- [ ] Lab: Datasources and Provisioners
- [ ] Quiz: Provisioners

## 19. Debugging Terraform
- [ ] Introduction — 01:14
- [ ] Terraform Logging and Debugging — 05:25
- [ ] Quiz: Debugging Terraform

## 20. Terraform Modules
- [ ] Introduction — 01:32
- [ ] What is Terraform Module and why use it? — 04:58
- [ ] Module Structure explained — 11:10
- [ ] Calling the module — 12:39
- [ ] With and without modules — 03:59
- [ ] Lab: Terraform Modules
- [ ] Quiz: Terraform Modules

## 21. Azure DevOps Integration
- [ ] Introduction — 00:55
- [ ] Why CI/CD for Terraform — 04:48
- [ ] Terraform Workflow in CI/CD — 02:37
- [ ] Azure DevOps Service Connections — 05:57
- [ ] Remote Backend Usage in Pipelines — 04:18
- [ ] Quiz: Azure DevOps Integration

## 22. Azure Pipelines for Terraform
- [ ] Introduction — 00:45
- [ ] Initializing and Building Pipeline — 04:44
- [ ] Executing Pipelines — 21:04
- [ ] Advanced Pipeline Configuration — 07:07
- [ ] Quiz: Azure Pipelines for Terraform
