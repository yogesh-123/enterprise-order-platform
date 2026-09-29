# Lesson 7 — Azure Fundamentals
## Complete Foundation Before We Start Building `enterprise-order-platform`

> **Goal of this lesson:** Understand the Azure concepts we will use in our project before creating resources in the Azure Portal.
>
> This is not a list of Azure commands. It is a mental model of Azure: what each concept means, why it exists, how the pieces connect, and where it will appear in our project.

---

# 1. Why Are We Learning Azure Fundamentals First?

We already understand a lot of the application side:

```text
Spring Boot
   ↓
Docker
   ↓
Kubernetes
   ↓
Helm
   ↓
Istio
```

Now we are moving from:

```text
LOCAL ENVIRONMENT
```

to:

```text
AZURE CLOUD
```

If we immediately start creating AKS, ACR, Key Vault, APIM, VNets, etc., you may learn the commands but not understand the architecture.

As someone preparing for an architect role, you should be able to answer:

> Why does this Azure resource exist?
>
> Who owns it?
>
> What does it communicate with?
>
> Is it public or private?
>
> How is it secured?
>
> How does it cost money?
>
> How do we monitor it?
>
> What happens if it fails?

That is the purpose of Lesson 7.

---

# 2. What Is Cloud Computing?

Before Azure, understand the cloud itself.

Imagine you want to run a production application.

Traditionally, your company might need:

```text
Physical server
Physical network
Storage
Firewall
Load balancer
Data center
Power
Cooling
Backup
Monitoring
```

Your company has to buy and maintain all of it.

Cloud computing changes the model.

Instead of buying physical infrastructure, you rent infrastructure/services from a cloud provider.

For us:

```text
Microsoft
   ↓
Azure
   ↓
Cloud services
   ↓
Our application
```

Azure provides services such as:

```text
Compute
Networking
Storage
Databases
Security
Identity
Monitoring
Containers
AI
Messaging
API Management
```

---

# 3. What Is Microsoft Azure?

Azure is Microsoft's cloud platform.

Think of Azure as a very large collection of managed infrastructure and platform services.

For example:

```text
Azure
 |
 +-- Compute
 |     +-- Virtual Machines
 |     +-- AKS
 |
 +-- Networking
 |     +-- VNet
 |     +-- Load Balancer
 |     +-- DNS
 |
 +-- Storage
 |
 +-- Database
 |
 +-- Security
 |     +-- Key Vault
 |     +-- Microsoft Entra ID
 |
 +-- Integration
 |     +-- APIM
 |
 +-- DevOps
 |     +-- Azure DevOps
 |
 +-- Monitoring
       +-- Azure Monitor
       +-- Log Analytics
```

Our project will use a subset of these.

---

# 4. Azure's Global Structure

One of the first Azure concepts you need to understand is:

```text
Geography
   ↓
Region
   ↓
Availability Zone
   ↓
Resources
```

Let's understand each.

---

# 5. Azure Region

A region is a geographic area where Microsoft operates Azure data centers.

Examples include regions around:

```text
Central India
South India
West Europe
East US
Southeast Asia
```

When you create many Azure resources, you choose a region.

Example:

```text
Resource Group
       |
       +-- Region: Central India
```

Why does region matter?

Because it affects:

- latency
- data residency
- service availability
- disaster recovery
- pricing

For our learning environment, we will choose a suitable India region based on the services we actually need and current Azure availability/pricing.

---

# 6. Availability Zones

An Azure region can contain multiple physically separate availability zones.

Conceptually:

```text
Region
|
+-- Zone 1
|
+-- Zone 2
|
+-- Zone 3
```

Each zone is designed to provide isolation from failures in another zone.

For example:

```text
Application
 |
 +-- Instance A → Zone 1
 |
 +-- Instance B → Zone 2
 |
 +-- Instance C → Zone 3
```

If one zone has a problem, other zones can continue serving traffic, depending on how the architecture is designed.

### Important

Availability Zones are a **high-availability concept**.

They are not the same thing as:

```text
multiple regions
```

Multiple regions are generally used for broader disaster recovery/geographic resilience.

---

# 7. Region vs Availability Zone

Think of:

```text
Region
= City/area

Availability Zone
= Separate protected data-center area within that region
```

Example:

```text
Azure Region
     |
     +-- Zone 1
     +-- Zone 2
     +-- Zone 3
```

For our initial learning environment, we will not automatically enable every high-availability feature.

Why?

Because:

> Learning resources should be proportional to the learning objective and our free-credit constraints.

---

# 8. Azure Subscription

A subscription is an important Azure management and billing boundary.

Think of it like:

```text
Company account
      |
      v
Azure Subscription
      |
      +-- Resources
      +-- Resource Groups
      +-- Billing
      +-- Access
```

Your Azure free-credit offer is associated with your Azure subscription/offer.

Therefore:

> The subscription is one of the most important places to understand cost and access.

---

# 9. Resource Group

A Resource Group is a logical container for Azure resources.

For our project we might have:

```text
rg-enterprise-order-dev
```

Inside it:

```text
rg-enterprise-order-dev
 |
 +-- VNet
 +-- AKS
 +-- ACR
 +-- Key Vault
 +-- APIM
 +-- Monitoring resources
```

The exact grouping will depend on the final architecture.

### Why use Resource Groups?

Because they make it easier to:

- organize resources
- manage permissions
- view related resources
- delete development resources
- manage lifecycle

---

# 10. Resource Group Is NOT a Network

This is a common beginner mistake.

A Resource Group does not mean:

```text
Resources can communicate automatically.
```

It is primarily a management/logical grouping concept.

Networking is handled by things such as:

```text
VNet
Subnet
Routing
NSG
Private Endpoint
DNS
```

So:

```text
Resource Group
    =
Management grouping

VNet
    =
Network boundary
```

Very different concepts.

---

# 11. Azure Resource

Almost everything you create in Azure is represented as a resource.

Examples:

```text
VNet
AKS cluster
Key Vault
ACR
APIM
Storage Account
Database
Public IP
Load Balancer
```

Conceptually:

```text
Subscription
   |
   +-- Resource Group
          |
          +-- Resource
          +-- Resource
          +-- Resource
```

---

# 12. Azure Resource Manager — ARM

Azure Resource Manager is the management layer for Azure resources.

Think of ARM as the control plane through which Azure manages resources.

Conceptually:

```text
Azure Portal
      |
Azure CLI
      |
Terraform / IaC
      |
      v
Azure Resource Manager
      |
      v
Azure Resources
```

When you create a VNet through the Azure Portal, Azure is ultimately managing that resource through Azure's resource-management system.

---

# 13. Control Plane vs Data Plane

This is an important architect concept.

## Control Plane

The control plane manages the resource.

Examples:

```text
Create AKS
Delete Key Vault
Change VNet configuration
Create subnet
```

## Data Plane

The data plane is where actual application/data operations happen.

For example:

```text
Application
   |
   v
Key Vault
   |
   v
Read secret
```

The first is resource management.

The second is using the resource.

This distinction becomes important for security permissions.

---

# 14. Azure Resource Naming

We will use consistent naming.

Example:

```text
Resource Group:
rg-enterprise-order-dev

VNet:
vnet-enterprise-order-dev

AKS:
aks-enterprise-order-dev

ACR:
acrenterpriseorderdev

Key Vault:
kv-enterprise-order-dev
```

Exact names may change based on Azure naming restrictions.

The important principle is:

> A production architecture should have predictable names.

---

# 15. Tags

Azure resources can have tags.

Example:

```text
Environment = Dev
Project     = EnterpriseOrder
Owner       = Engineering
Purpose     = Learning
```

Why?

Tags help with:

- cost analysis
- ownership
- resource organization
- automation
- governance

Example:

```text
Environment=Dev
Project=enterprise-order-platform
```

Later, when the subscription has many resources, tags become extremely useful.

---

# 16. Identity in Azure

Now we reach one of the most important areas:

```text
Microsoft Entra ID
```

Previously many developers know it as:

```text
Azure Active Directory / Azure AD
```

Microsoft Entra ID is Azure's cloud identity and access management system.

It manages identities such as:

```text
Users
Applications
Service principals
Managed identities
```

---

# 17. Authentication vs Authorization

These two words must be crystal clear.

## Authentication

Question:

> Who are you?

Example:

```text
User → Login
```

## Authorization

Question:

> What are you allowed to do?

Example:

```text
Developer
   |
   +-- Can view AKS
   |
   +-- Cannot delete production
```

So:

```text
Authentication
= Who are you?

Authorization
= What can you do?
```

---

# 18. Azure RBAC

RBAC means:

> Role-Based Access Control

It controls what an identity can do to Azure resources.

Example:

```text
Developer
   |
   v
Resource Group
   |
   v
Contributor
```

Another user might have:

```text
Reader
```

Reader can view.

Contributor can generally manage resources but does not automatically mean unrestricted ownership of every permission scenario.

The exact effective permissions depend on role assignments and scope.

---

# 19. RBAC Scope

Roles can be assigned at different scopes.

Conceptually:

```text
Management Group
      |
Subscription
      |
Resource Group
      |
Resource
```

A permission assigned at a broader scope can flow down to child resources, subject to Azure's authorization model.

This is important for enterprise architecture.

---

# 20. Managed Identity

This is extremely important for our project.

Suppose:

```text
order-service
```

needs to read a secret from:

```text
Key Vault
```

Bad approach:

```text
username/password inside application code
```

Better approach:

```text
Azure Identity
      |
      v
Key Vault
```

A managed identity allows an Azure resource/workload to authenticate to Azure services without us embedding long-lived credentials in source code.

---

# 21. Workload Identity

For our AKS architecture, we will eventually learn Azure Workload Identity.

Conceptually:

```text
Spring Boot Pod
      |
      v
Kubernetes Service Account
      |
      v
Azure Workload Identity
      |
      v
Microsoft Entra ID
      |
      v
Key Vault
```

Then Key Vault decides:

```text
Is this identity allowed to read this secret?
```

This is much better than putting:

```text
KEY_VAULT_PASSWORD=...
```

inside the deployment.

---

# 22. Azure Key Vault

Key Vault is designed to protect sensitive information such as:

```text
Secrets
Keys
Certificates
```

For our project, examples could eventually include:

```text
Database credentials
Certificates
Application secrets
```

But our goal is not to put every configuration value in Key Vault.

We will distinguish:

```text
Normal configuration
        ↓
ConfigMap / application configuration

Sensitive configuration
        ↓
Key Vault
```

---

# 23. Networking — The Azure VNet

Now we move to Azure networking.

A VNet is Azure's private network boundary.

For our project:

```text
VNet
10.0.0.0/16
```

Conceptually:

```text
Azure
 |
 +---------------------------+
 | VNet                      |
 | 10.0.0.0/16              |
 |                           |
 |  +---------------------+  |
 |  | AKS subnet          |  |
 |  | 10.0.1.0/24         |  |
 |  +---------------------+  |
 |                           |
 |  +---------------------+  |
 |  | Private Endpoint    |  |
 |  | subnet              |  |
 |  | 10.0.2.0/24         |  |
 |  +---------------------+  |
 +---------------------------+
```

---

# 24. What Is a Subnet?

A subnet is a smaller network inside a VNet.

Think:

```text
VNet
10.0.0.0/16
 |
 +-- Subnet A
 |   10.0.1.0/24
 |
 +-- Subnet B
     10.0.2.0/24
```

Why?

Because different workloads can have different network boundaries and security requirements.

For our project:

```text
AKS subnet
        ↓
AKS networking

Private Endpoint subnet
        ↓
Private connectivity to Azure services
```

---

# 25. CIDR

CIDR is the notation used to describe IP address ranges.

Example:

```text
10.0.0.0/16
```

and:

```text
10.0.1.0/24
```

For this project we are planning:

```text
VNet:
10.0.0.0/16

AKS subnet:
10.0.1.0/24

Private Endpoint subnet:
10.0.2.0/24

Pod CIDR:
10.244.0.0/16

Service CIDR:
10.250.0.0/16
```

The key architectural rule:

> Network ranges that need to communicate should be planned so they do not unintentionally overlap.

---

# 26. Azure CNI Overlay

AKS needs networking for Pods.

We are planning to use:

```text
Azure CNI Overlay
```

Conceptually:

```text
Azure VNet
10.0.0.0/16
 |
 +-- AKS Nodes
     |
     +-- Pods
          |
          +-- Pod CIDR
              10.244.0.0/16
```

The important idea:

> Nodes use the Azure VNet network, while Pod IPs can come from the separate overlay Pod address space.

This can make IP planning more scalable than consuming VNet addresses directly for every Pod.

---

# 27. Kubernetes Service CIDR

Kubernetes Services also need virtual IPs.

We will use a separate range such as:

```text
10.250.0.0/16
```

Therefore:

```text
VNet CIDR
10.0.0.0/16

Pod CIDR
10.244.0.0/16

Service CIDR
10.250.0.0/16
```

These represent different networking purposes.

---

# 28. NSG — Network Security Group

An NSG is a network traffic filtering mechanism.

Think of it as a security guard.

```text
Traffic
   |
   v
+-------+
|  NSG  |
+-------+
   |
   +-- Allow
   |
   +-- Deny
```

Example:

```text
Internet
   |
   | HTTPS
   v
NSG
   |
   v
Allowed destination
```

NSGs operate at the network layer.

They do not replace:

```text
Application authentication
JWT validation
Key Vault authorization
Istio policies
```

Those solve different problems.

---

# 29. Public vs Private Networking

Public endpoint:

```text
Internet
   |
   v
Public endpoint
```

Private endpoint:

```text
Private VNet
   |
   v
Private IP
   |
   v
Azure service
```

Our architectural preference is:

> Keep internal infrastructure private wherever practical and expose only the required application entry points.

---

# 30. DNS

DNS translates names into network destinations.

Instead of:

```text
20.x.x.x
```

we use:

```text
api.example.com
```

Conceptually:

```text
Application
    |
    | DNS lookup
    v
 DNS
    |
    v
IP / destination
```

---

# 31. Private DNS

Private DNS is used for private network name resolution.

For example:

```text
order-service
      |
      v
Private DNS
      |
      v
Private IP
```

This becomes especially important with Private Endpoints.

---

# 32. Private Endpoint

Suppose our application needs Azure Key Vault.

Without private connectivity, the application may use a public endpoint.

With a Private Endpoint:

```text
AKS
 |
 v
VNet
 |
 v
Private Endpoint
 |
 v
Key Vault
```

The endpoint provides private network connectivity to the Azure service.

---

# 33. Private Endpoint + Private DNS + Identity

These three concepts solve different problems.

### Private Endpoint

> How do I reach the service privately?

### Private DNS

> How does the service name resolve to the private destination?

### Identity/RBAC

> Am I allowed to use the service?

Therefore:

```text
Private Endpoint
        +
Private DNS
        +
Workload Identity
        +
Key Vault authorization
```

creates a secure private-access pattern.

---

# 34. Azure Load Balancer

A Load Balancer distributes network traffic.

Conceptually:

```text
Client
  |
  v
Load Balancer
  |
  +---- Node 1
  +---- Node 2
  +---- Node 3
```

In AKS, a Kubernetes Service of type:

```text
LoadBalancer
```

can cause Azure networking infrastructure to expose a load-balanced endpoint.

We will use this concept carefully rather than exposing every service publicly.

---

# 35. Load Balancer vs Istio Gateway

These are different layers.

### Azure Load Balancer

```text
Azure infrastructure
        |
        v
Load Balancer
```

### Istio Gateway

```text
AKS
 |
 v
Istio Gateway
 |
 v
Application
```

The Load Balancer handles Azure-level network traffic distribution.

Istio handles service-mesh traffic management.

They can appear together in one request path.

---

# 36. API Management — APIM

Azure API Management is an API gateway/management platform.

Our eventual architecture is:

```text
Internet
   |
   v
APIM
   |
   v
AKS
   |
   v
Istio
   |
   v
order-service
```

APIM can provide capabilities such as:

- API publishing
- authentication integration
- authorization policies
- rate limiting
- transformations
- API versioning
- API monitoring

We will learn the detailed APIM configuration later.

---

# 37. ACR — Azure Container Registry

Our application is packaged as a Docker image.

Locally:

```text
order-service:0.1.6
```

In Azure:

```text
Developer / CI pipeline
        |
        v
Docker image
        |
        v
Azure Container Registry
        |
        v
AKS
```

ACR is where we will store container images.

---

# 38. AKS — Azure Kubernetes Service

AKS is Microsoft's managed Kubernetes service.

Locally we currently have:

```text
Docker Desktop Kubernetes
```

In Azure we will move toward:

```text
Azure
 |
 v
AKS
 |
 +-- Kubernetes control-plane management
 |
 +-- Worker nodes
 |
 +-- Pods
 |
 +-- Services
 |
 +-- Helm
 |
 +-- Istio
```

The key word is:

> Managed Kubernetes.

Azure manages important parts of the Kubernetes control plane for AKS.

We still need to understand and operate the workloads, networking, security, scaling, deployments, observability, and cost.

---

# 39. How Our Local Kubernetes Knowledge Transfers to AKS

What we learned locally is not wasted.

Local:

```text
Kubernetes
Helm
Istio
Service
Deployment
ConfigMap
Secret
```

Azure:

```text
AKS
Helm
Istio
Azure networking
Azure identity
Azure monitoring
Azure container registry
Azure Key Vault
```

So Azure is not replacing Kubernetes knowledge.

Azure is providing the cloud infrastructure around it.

---

# 40. Azure Storage

Azure provides managed storage services.

Examples include:

```text
Blob Storage
Files
Queues
Tables
Managed disks
```

For our current project, Blob Storage is not a core first step.

But you should understand the category:

```text
Object storage
File storage
Block/disk storage
Messaging/storage services
```

If our order platform later stores documents, exports, invoices, or files, Blob Storage could become relevant.

---

# 41. Azure Database Services

Azure provides managed database services.

Examples include managed relational and NoSQL offerings.

The important cloud concept is:

```text
Application
   |
   v
Managed Database
```

Instead of manually maintaining:

```text
OS
Database installation
Patching
Backups
```

Azure provides managed capabilities depending on the selected service.

For our project, we will later decide how PostgreSQL should be represented in Azure.

We are deliberately not making that decision before understanding the network and cost model.

---

# 42. Monitoring — Azure Monitor

Production applications must be observable.

Azure Monitor is the broader Azure monitoring platform.

Conceptually:

```text
Azure resources
      |
      v
Azure Monitor
      |
      +-- Metrics
      +-- Logs
      +-- Alerts
```

For our project we will eventually monitor:

```text
AKS
Application
Networking
Infrastructure
```

---

# 43. Log Analytics

Log Analytics provides a workspace for collecting and querying logs.

Conceptually:

```text
AKS
 |
 +-- logs
 |
 v
Log Analytics Workspace
 |
 v
Queries / dashboards / alerts
```

This becomes important when troubleshooting:

```text
Pod failure
Network failure
Application errors
Authentication problems
```

---

# 44. Application Insights

Application Insights focuses on application observability.

For a Spring Boot application, we eventually want visibility into things such as:

```text
Requests
Response time
Failures
Dependencies
Exceptions
```

Conceptually:

```text
Spring Boot
     |
     v
Application Insights
     |
     v
Observability
```

---

# 45. Metrics vs Logs vs Traces

As an architect, distinguish these.

## Metrics

Numerical measurements.

Example:

```text
CPU = 70%
Memory = 400 MB
Requests/sec = 120
```

## Logs

Events/messages.

Example:

```text
Order 123 failed
Database connection timeout
```

## Traces

Follow one request across components.

Example:

```text
APIM
 ↓
Istio
 ↓
order-service
 ↓
payment-service
 ↓
database
```

Tracing helps answer:

> Where did this request spend its time?

---

# 46. Azure Cost Management

This is extremely important for our learning project.

Azure resources can incur charges.

We therefore need to think about cost before creating resources.

Conceptually:

```text
Subscription
      |
      v
Cost Management
      |
      +-- Cost analysis
      +-- Budgets
      +-- Alerts
```

---

# 47. Budget vs Spending Limit

These are not exactly the same thing.

A budget is primarily a monitoring/alerting mechanism.

For example:

```text
Monthly budget
₹X
```

When spending approaches configured thresholds:

```text
80% → alert
100% → alert
```

This helps us detect unexpected spending.

But:

> A budget should NOT be treated as a guaranteed automatic shutdown of every Azure resource.

Therefore we still need disciplined cleanup.

---

# 48. Our Free-Credit Rule

This is a permanent rule for this project.

Before creating a resource:

```text
Why do we need it?
What does it cost?
Is there a free/low-cost alternative?
How long will it run?
How do we delete it?
```

After a practical session:

```text
Check resources
       ↓
Check running/chargeable services
       ↓
Delete/stop what is not needed
```

I will remind you about cleanup whenever we create resources where unnecessary runtime could consume your credits.

---

# 49. Azure Resource Lifecycle

Think about every resource in three phases:

```text
CREATE
  ↓
USE
  ↓
CLEAN UP
```

For a learning environment:

```text
Create VNet
Create AKS
Practice
Collect evidence
Delete expensive resources
```

This is much better than:

```text
Create everything
Leave everything running for weeks
Discover the bill later
```

---

# 50. Azure Security Model — Big Picture

Our application will eventually have multiple security layers.

```text
                     INTERNET
                         |
                         v
                       APIM
                         |
                 Network security
                         |
                         v
                        AKS
                         |
                 +-------+-------+
                 |               |
               Istio          Identity
                 |               |
                 v               v
          order-service      Entra ID
                 |               |
                 +-------+-------+
                         |
                         v
                     Key Vault
```

No single security feature is responsible for everything.

---

# 51. How the Pieces Fit Together

Now put the fundamental concepts together.

```text
Azure Subscription
        |
        +-- Resource Group
                |
                +-- VNet
                |    |
                |    +-- AKS Subnet
                |    |      |
                |    |      +-- AKS
                |    |             |
                |    |             +-- Istio
                |    |             |
                |    |             +-- order-service
                |    |
                |    +-- Private Endpoint Subnet
                |           |
                |           +-- Private Endpoint
                |
                +-- ACR
                |
                +-- Key Vault
                |
                +-- APIM
                |
                +-- Monitoring
```

Identity crosses these components:

```text
Microsoft Entra ID
       |
       +-- User authentication
       +-- Azure RBAC
       +-- Workload Identity
```

---

# 52. Complete Request Flow

Now imagine:

```text
GET /orders/123
```

The request can eventually follow this architecture:

```text
Customer
   |
   | HTTPS
   v
APIM
   |
   v
Azure networking
   |
   v
AKS entry point
   |
   v
Istio Gateway
   |
   v
order-service
   |
   +----> Database
   |
   +----> Other microservices
   |
   +----> Key Vault
```

Each layer has a responsibility.

---

# 53. Complete Key Vault Flow

When the application needs a secret:

```text
Spring Boot Pod
      |
      v
Kubernetes Service Account
      |
      v
Azure Workload Identity
      |
      v
Microsoft Entra ID
      |
      v
Key Vault authorization
      |
      v
Private DNS
      |
      v
Private Endpoint
      |
      v
Key Vault
```

Notice something important:

```text
Identity
```

and

```text
Networking
```

are separate concerns.

The application needs both:

```text
Can I reach it?
+
Am I allowed to use it?
```

---

# 54. Complete CI/CD Flow

Later our development pipeline will look approximately like:

```text
Git Repository
      |
      v
Azure DevOps Pipeline
      |
      +-- Compile
      +-- Unit tests
      +-- Build
      +-- Docker image
      |
      v
Azure Container Registry
      |
      v
AKS
      |
      v
Helm
      |
      v
order-service
```

This connects our existing Java/Kubernetes knowledge to Azure.

---

# 55. What We Will Build

Our learning architecture is:

```text
                    INTERNET
                       |
                       v
                     APIM
                       |
                       v
             +-------------------+
             |      Azure VNet   |
             |    10.0.0.0/16    |
             |                   |
             |  AKS Subnet       |
             |  10.0.1.0/24     |
             |       |           |
             |      AKS          |
             |       |           |
             |     Istio         |
             |       |           |
             | order-service     |
             |                   |
             | Private Endpoint  |
             | Subnet             |
             | 10.0.2.0/24       |
             +---------+---------+
                       |
                       v
                  Private Endpoint
                       |
                       v
                    Key Vault
```

Supporting services:

```text
ACR
 |
 v
Container images

Entra ID
 |
 +-- Users
 +-- RBAC
 +-- Workload Identity

Azure Monitor
 |
 +-- Metrics
 +-- Logs
 +-- Alerts

Log Analytics
 |
 +-- Centralized logs
```

---

# 56. What We Are NOT Going to Create Yet

We are intentionally not creating everything immediately.

We will introduce resources only when the project requires them.

We do not want to create:

```text
AKS
APIM
Database
Key Vault
Private Endpoints
Monitoring
```

all at once and then struggle to understand:

```text
What is generating cost?
What is communicating with what?
Why does this resource exist?
```

Instead:

```text
Fundamentals
   ↓
Cost protection
   ↓
Networking
   ↓
AKS
   ↓
ACR
   ↓
Application deployment
   ↓
Key Vault / Identity
   ↓
APIM
   ↓
Monitoring
   ↓
CI/CD
```

---

# 57. Azure Fundamentals We Have Covered

## Azure Core Concepts

- Cloud computing
- Azure
- Regions
- Availability Zones
- Subscriptions
- Resource Groups
- Resources
- Resource naming
- Tags
- Azure Resource Manager
- Control plane
- Data plane

## Identity & Security

- Microsoft Entra ID
- Authentication
- Authorization
- Azure RBAC
- RBAC scope
- Managed Identity
- Workload Identity
- Key Vault
- Layered security

## Networking

- VNet
- Subnet
- CIDR
- Private IP
- Public IP
- NSG
- DNS
- Private DNS
- Private Endpoint
- Load Balancer
- Azure CNI Overlay
- Pod CIDR
- Kubernetes Service CIDR

## Application Platform

- AKS
- ACR
- APIM
- Kubernetes
- Helm
- Istio

## Data

- Azure storage concepts
- Managed databases
- PostgreSQL architecture direction

## Observability

- Azure Monitor
- Log Analytics
- Application Insights
- Metrics
- Logs
- Traces
- Alerts

## Cost Management

- Cost Management
- Budgets
- Alerts
- Resource lifecycle
- Free-credit protection
- Cleanup discipline

---

# 58. What You Should Understand Before Practical Work

You do NOT need to memorize every Azure service.

You should be able to explain:

### Azure hierarchy

```text
Subscription
    ↓
Resource Group
    ↓
Resources
```

### Network hierarchy

```text
VNet
    ↓
Subnet
    ↓
Resource / workload
```

### Kubernetes networking

```text
VNet
    ↓
AKS nodes
    ↓
Pods
    ↓
Services
```

### Private Azure service access

```text
Application
    ↓
Private DNS
    ↓
Private Endpoint
    ↓
Azure service
```

### Identity

```text
Identity
    ↓
Authentication
    ↓
Authorization
    ↓
RBAC / permissions
```

### Application entry

```text
Internet
    ↓
APIM
    ↓
AKS
    ↓
Istio
    ↓
order-service
```

### Container delivery

```text
Git
    ↓
Azure DevOps
    ↓
Docker image
    ↓
ACR
    ↓
AKS
```

### Observability

```text
Application / Azure resources
    ↓
Azure Monitor
    ↓
Logs / Metrics / Traces / Alerts
```

### Cost

```text
Subscription
    ↓
Budget / alerts
    ↓
Resource monitoring
    ↓
Cleanup
```

---

# 59. The Most Important Architect Lesson

Do not think:

> "Azure is a list of services."

Think:

> "Azure is a collection of infrastructure, networking, identity, security, platform, data, observability, and management capabilities that I combine to solve a business problem."

For our project:

```text
Business application
       |
       v
Spring Boot
       |
       v
Containers
       |
       v
Kubernetes / AKS
       |
       +-- Networking
       +-- Identity
       +-- Security
       +-- Secrets
       +-- API gateway
       +-- Container registry
       +-- Monitoring
       +-- CI/CD
```

That is the architect mindset we are building.

---

# 60. Practical Azure Learning Sequence

Now that the fundamentals are understood, our practical sequence will be:

## Step 1 — Azure Account & Subscription

Understand:

```text
Subscription
Resource Group
Region
```

## Step 2 — Cost Protection

Configure:

```text
Budget
Alerts
Cost monitoring
```

## Step 3 — Resource Group

Create:

```text
rg-enterprise-order-dev
```

## Step 4 — VNet

Create:

```text
vnet-enterprise-order-dev
10.0.0.0/16
```

## Step 5 — Subnets

Create:

```text
AKS subnet
10.0.1.0/24

Private Endpoint subnet
10.0.2.0/24
```

## Step 6 — AKS

Create AKS using the networking design we have learned.

## Step 7 — ACR

Create the container registry and push our Docker image.

## Step 8 — Deploy order-service

Move our existing Helm/Kubernetes deployment into AKS.

## Step 9 — Istio

Bring our existing Istio knowledge into Azure.

## Step 10 — Key Vault + Workload Identity

Secure application secrets properly.

## Step 11 — Private Endpoint + Private DNS

Learn private connectivity to Azure services.

## Step 12 — APIM

Put the API gateway in front of our application.

## Step 13 — Monitoring

Add:

```text
Azure Monitor
Log Analytics
Application Insights
Alerts
```

## Step 14 — Azure DevOps

Build the production-style CI/CD pipeline.

---

# 61. Free-Credit Safety Checklist

Before every Azure practical session:

- [ ] Do I need this resource?
- [ ] Is it chargeable?
- [ ] What is the expected cost?
- [ ] Is there a cheaper learning option?
- [ ] Do I need it running continuously?
- [ ] What is the cleanup command/action?

After the session:

- [ ] Check Resource Group
- [ ] Check running resources
- [ ] Check cost/usage
- [ ] Stop/delete unnecessary resources

### Important

A budget is an early-warning mechanism, not a substitute for cleanup.

We will therefore make cleanup part of the project workflow.

---

# 62. Final Mental Map

If you remember only one diagram from Lesson 7, remember this:

```text
                         AZURE SUBSCRIPTION
                                |
                                v
                         RESOURCE GROUP
                                |
          +---------------------+---------------------+
          |                     |                     |
          v                     v                     v
        VNet                   ACR                 Key Vault
          |
          +-----------------------+
          |                       |
          v                       v
      AKS Subnet          Private Endpoint Subnet
          |                       |
          v                       v
         AKS              Private Endpoint
          |
          +----------------+
          |                |
          v                v
        Istio          Kubernetes
          |                |
          v                v
   order-service       Services/Pods
          |
          +------------------------+
                                   |
                                   v
                              Other services
```

Across the architecture:

```text
Entra ID
   ↓
Identity + RBAC + Workload Identity

APIM
   ↓
External API entry

DNS
   ↓
Name resolution

NSG
   ↓
Network filtering

Azure Monitor
   ↓
Metrics / Logs / Alerts

Cost Management
   ↓
Budget / Cost control
```

---

# 63. Lesson 7 Completion Criteria

Lesson 7 is complete when you can explain, in your own words:

1. What Azure is.
2. What a subscription is.
3. What a Resource Group is.
4. What a region is.
5. What an Availability Zone is.
6. What a VNet is.
7. What a subnet is.
8. What CIDR means.
9. What an NSG does.
10. What DNS does.
11. What a Private Endpoint does.
12. Why Private DNS is required in private connectivity scenarios.
13. What Microsoft Entra ID does.
14. What RBAC does.
15. What Managed Identity/Workload Identity solves.
16. What Key Vault does.
17. What AKS does.
18. What Azure CNI Overlay means.
19. What a Pod CIDR and Service CIDR are.
20. What ACR does.
21. What APIM does.
22. What Azure Load Balancer does.
23. What Istio does.
24. What Azure Monitor does.
25. What Log Analytics does.
26. What Application Insights does.
27. How cost budgets and alerts help.
28. Why cleanup is essential when using free credits.
29. How a request flows from Internet → APIM → AKS → Istio → order-service.
30. How order-service can privately access Key Vault.

---

# 64. End of Lesson 7

The purpose of this lesson was not to make you an Azure expert.

The purpose was to give you the **foundation required to understand the Azure architecture we are about to build**.

From the next practical lesson onward, every Azure resource we create should connect to something you already understand here.

The rule is:

> **We learn the concept first, then create the resource, then test it, then understand its cost, and finally clean it up when we no longer need it.**

This is the approach we will follow throughout the Azure portion of the architect learning journey.
