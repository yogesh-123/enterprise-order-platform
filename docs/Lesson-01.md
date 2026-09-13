                    Local Machine
                         │
                         ▼
                ┌─────────────────┐
                │ Istio Ingress   │
                │    Gateway      │
                └────────┬────────┘
                         │
                    VirtualService
                         │
                         ▼
                ┌─────────────────┐
                │  order-service  │
                │   Kubernetes    │
                │     Service     │
                └────────┬────────┘
                         │
                         ▼
                ┌─────────────────┐
                │ Order Service   │
                │      Pod        │
                │                 │
                │ Spring Boot     │
                │ + Istio Sidecar │
                └─────────────────┘



Absolutely. 👍 I’ll combine everything we discussed about the **Istio implementation so far** into one clean, structured `lesson1.md` document.

I’ve also corrected a few points so the document is technically accurate and suitable for your **project notes + interview preparation**.

You can **copy everything below directly into `docs/lessons/lesson1.md`**.

````markdown
# Lesson 1 — Istio Fundamentals and Initial Local Implementation

## 1. Objective

In this lesson, we learned the fundamentals of Istio and performed our first local Istio installation on Docker Desktop Kubernetes.

The objective is to understand:

- What Istio is
- Why Istio is required in a microservices architecture
- What a Service Mesh is
- Control Plane vs Data Plane
- What `istiod` does
- What Envoy does
- What an Istio Ingress Gateway does
- How requests flow with and without Istio
- How service-to-service communication works
- Why requests go through Envoy sidecars
- How mTLS fits into the architecture
- Why we are initially learning Istio independently of APIM and NGINX
- How Istio will be used in our Enterprise Order Platform

---

# 2. What is Istio?

Istio is a **service mesh** that manages communication between services in a distributed application.

In a microservices architecture, services need to communicate with each other.

For example:

```text
Order Service
      |
      v
Payment Service
````

As the number of services increases, many networking-related requirements appear:

* Traffic routing
* Service-to-service security
* TLS/mTLS
* Retries
* Timeouts
* Circuit breaking
* Load balancing
* Traffic splitting
* Canary deployments
* Metrics
* Distributed tracing
* Observability

If every Java microservice implements all these concerns itself, the application code becomes complicated and duplicated.

Istio provides infrastructure to handle many of these networking concerns outside the application business logic.

---

# 3. Why do we need Istio in our Enterprise Order Platform?

Our project is a production-oriented Enterprise Order Management Platform.

Eventually, our architecture will contain multiple services such as:

```text
Order Service
Payment Service
Product Service
Notification Service
```

For example:

```text
Order Service
      |
      v
Payment Service
```

The Order Service should primarily focus on business logic such as:

* Create order
* Validate order
* Save order
* Calculate order information
* Process order state

It should not have to contain large amounts of infrastructure logic for:

* Service-to-service encryption
* Retry policies
* Traffic routing
* Circuit breaking
* Canary traffic
* Service telemetry

Istio helps separate these concerns.

---

# 4. Main idea behind Istio

The most important concept is:

> Istio separates application business logic from many service-to-service networking concerns.

Without Istio:

```text
Order Service
|
├── Business Logic
├── Retry Logic
├── Timeout Logic
├── Circuit Breaker
├── TLS/security handling
├── Metrics
└── Tracing
```

With Istio:

```text
Order Service
|
├── Business Logic
|
└── Envoy Sidecar
      |
      ├── Traffic Management
      ├── Retry
      ├── Timeout
      ├── mTLS
      ├── Telemetry
      └── Routing
```

The application can remain focused primarily on business functionality while Istio manages network-level concerns.

---

# 5. What is a Service Mesh?

A service mesh is an infrastructure layer that manages communication between services.

Conceptually:

```text
              APPLICATION LAYER
     +-------------------------------+
     | Order | Payment | Product    |
     +-------------------------------+
                    |
                    v
              SERVICE MESH
     +-------------------------------+
     | Routing                       |
     | Security / mTLS               |
     | Retry                         |
     | Timeout                       |
     | Circuit Breaking              |
     | Observability                 |
     +-------------------------------+
                    |
                    v
                KUBERNETES
```

Istio is a service mesh implementation.

---

# 6. Istio Architecture

Istio can be understood through two major concepts:

```text
                    ISTIO
                      |
          +-----------+-----------+
          |                       |
          v                       v
    CONTROL PLANE             DATA PLANE
          |                       |
        istiod                  Envoy
```

## Control Plane

The control plane manages and provides configuration and control information for the service mesh.

The main Istio control-plane component we installed is:

```text
istiod
```

## Data Plane

The data plane handles the actual application traffic.

Istio uses:


Envoy Proxy


as its data-plane proxy.

---

# 7. What is Envoy?

Envoy is a high-performance proxy used by Istio.

Istio uses Envoy to handle traffic for workloads participating in the mesh.

Eventually our Order Service Pod will look like:

+--------------------------------------+
|          Order Service Pod           |
|                                      |
|  +-------------------------------+   |
|  | Spring Boot Order Service     |   |
|  | Port 8080                     |   |
|  +---------------+---------------+   |
|                  |                   |
|                  |                   |
|  +---------------v---------------+   |
|  | Envoy Sidecar                 |   |
|  | istio-proxy                   |   |
|  +-------------------------------+   |
|                                      |
+--------------------------------------+
```

The Envoy proxy participates in the network traffic for the application.

---

# 8. Why does Istio use a Sidecar?

When a workload is added to the Istio mesh, an Envoy proxy can run alongside the application container in the same Pod.

For example:


Order Service Pod
|
+-- order-service container
|
+-- istio-proxy container
```

Therefore:

```text
+-----------------------------------+
| Order Pod                         |
|                                   |
| +-------------------------------+ |
| | Spring Boot Order Service      | |
| +-------------------------------+ |
|                                   |
| +-------------------------------+ |
| | Envoy / istio-proxy            | |
| +-------------------------------+ |
+-----------------------------------+
```

The application container and Envoy sidecar share the Pod's network namespace.

Istio configures traffic interception so that the Envoy proxy can participate in the workload's inbound and outbound traffic.

---

# 9. Request Flow Without Istio

Consider this example:

```text
User
 |
 | HTTPS
 v
Gateway
 |
 | HTTP/HTTPS
 v
Order Service
 |
 | HTTP
 v
Payment Service
```

Detailed flow:

```text
+--------+
|  User  |
+---+----+
    |
    | HTTPS Request
    v
+----------------+
|    Gateway     |
| NGINX / APIM   |
+-------+--------+
        |
        | Request
        v
+----------------------+
|   Order Service      |
|                      |
| Spring Boot          |
| Business Logic       |
+----------+-----------+
           |
           | HTTP Request
           v
+----------------------+
|   Payment Service    |
|                      |
| Spring Boot          |
| Business Logic       |
+----------------------+
```

In this architecture, networking concerns may need to be implemented or managed by the application or other infrastructure.

For example:

```text
Order Service
|
├── Call Payment Service
├── Retry failed request
├── Configure timeout
├── Handle failures
└── Implement security logic
```

If many services implement these features independently, the logic can become duplicated.

---

# 10. Request Flow With Istio

Now consider the same architecture with Istio.

```text
User
 |
 v
Gateway
 |
 v
Istio Ingress Gateway
 |
 v
Order Service Pod
 |
 v
Payment Service Pod
```

The important difference is that the application Pods have Envoy sidecars.

```text
                         ISTIO SERVICE MESH
+------------------------------------------------------------------+
|                                                                  |
|  +---------------------+       +-----------------------------+   |
|  | Order Service Pod   |       | Payment Service Pod         |   |
|  |                     |       |                             |   |
|  | +-----------------+ |       | +-------------------------+ |   |
|  | | Order Service   | |       | | Payment Service         | |   |
|  | +--------+--------+ |       | +------------+------------+ |   |
|  |          |          |       |              |              |   |
|  | +--------v--------+ |       | +------------v------------+ |   |
|  | | Envoy Sidecar   | | <---> | | Envoy Sidecar            | |   |
|  | | istio-proxy     | | mTLS  | | istio-proxy              | |   |
|  | +-----------------+ |       | +--------------------------+ |   |
|  +---------------------+       +-----------------------------+   |
|                                                                  |
+------------------------------------------------------------------+
```

The simplified request flow is:

```text
User
  |
  v
Gateway
  |
  v
Istio Ingress Gateway (Envoy)
  |
  v
Order Envoy Sidecar
  |
  v
Order Service
  |
  v
Order Envoy Sidecar
  |
  v
Payment Envoy Sidecar
  |
  v
Payment Service
```

---

# 11. Does the request from Istio Ingress Gateway go directly to Order Service?

No.

This is a very important concept.

When the Order Service participates in the Istio service mesh, the request is handled by the Order Pod's Envoy sidecar before reaching the application container.

Conceptually:

```text
Istio Ingress Gateway
        |
        v
Order Pod
        |
        v
Envoy Sidecar
        |
        v
Spring Boot Order Service
```

Therefore, remember:

```text
Istio Ingress Envoy
        |
        v
Order Envoy Sidecar
        |
        v
Order Spring Boot Application
```

The application is not the first network component inside the mesh-enabled Pod.

---

# 12. Why does the request go through the Envoy Sidecar?

Because Envoy is the Istio data-plane proxy.

The sidecar allows Istio to apply policies and participate in traffic handling.

For example:

```text
Incoming Request
       |
       v
Envoy Sidecar
       |
       +--> Routing
       |
       +--> Security
       |
       +--> Telemetry
       |
       +--> Traffic policies
       |
       v
Spring Boot Application
```

For outbound traffic:

```text
Spring Boot Application
       |
       v
Envoy Sidecar
       |
       +--> Retry
       |
       +--> Timeout
       |
       +--> Traffic policy
       |
       +--> mTLS
       |
       v
Destination Envoy
```

---

# 13. Order Service Calling Payment Service

Suppose the Order Service needs to call the Payment Service.

Without Istio:

```text
Order Service
      |
      | HTTP
      v
Payment Service
```

With Istio:

```text
+--------------------+              +----------------------+
| Order Pod          |              | Payment Pod          |
|                    |              |                      |
| Order Service      |              | Payment Service      |
|       |            |              |        ^             |
|       v            |              |        |             |
| Order Envoy        | -----------> | Payment Envoy        |
|       |            |    mTLS      |        |             |
+--------------------+              +--------+-------------+
                                             |
                                             v
                                      Payment Service
```

The simplified flow is:

```text
Order Spring Boot
       |
       v
Order Envoy
       |
       | Istio-managed traffic
       | mTLS when enabled
       v
Payment Envoy
       |
       v
Payment Spring Boot
```

This is the mental model to remember:

> Source Application → Source Envoy → Destination Envoy → Destination Application

---

# 14. What if Payment Service calls Order Service back?

Suppose Payment Service initiates a request to Order Service.

The direction simply reverses.

```text
Payment Service
       |
       v
Payment Envoy Sidecar
       |
       | mTLS / Istio-managed traffic
       v
Order Envoy Sidecar
       |
       v
Order Service
```

So:

```text
Payment Spring Boot
        |
        v
Payment Envoy
        |
        | mTLS
        v
Order Envoy
        |
        v
Order Spring Boot
```

There is no need to send this internal request back through the Istio Ingress Gateway.

---

# 15. Istio Ingress Gateway is NOT used for every request

This is another important concept.

The Istio Ingress Gateway primarily handles traffic entering the service mesh from outside.

For example:

```text
External Client
      |
      v
Istio Ingress Gateway
      |
      v
Order Service
```

But internal service-to-service traffic normally follows:

```text
Order Service
      |
      v
Order Envoy
      |
      v
Payment Envoy
      |
      v
Payment Service
```

Therefore:

```text
External Traffic:

User
 |
 v
Istio Ingress Gateway
 |
 v
Service


Internal Traffic:

Service
 |
 v
Source Envoy
 |
 v
Destination Envoy
 |
 v
Destination Service
```

---

# 16. Complete Example

Suppose a user creates an order.

The request is:

```text
POST /orders
```

The user sends:

```text
User
 |
 | HTTPS
 v
Gateway
```

The request enters the Istio mesh:

```text
Gateway
 |
 v
Istio Ingress Gateway
       |
       | Envoy
       v
Order Envoy Sidecar
       |
       v
Order Service
```

The Order Service processes the order and needs payment processing:

```text
Order Service
       |
       v
Order Envoy
       |
       | mTLS
       v
Payment Envoy
       |
       v
Payment Service
```

Suppose Payment Service then needs to update the Order Service:

```text
Payment Service
       |
       v
Payment Envoy
       |
       | mTLS
       v
Order Envoy
       |
       v
Order Service
```

Complete flow:

```text
                         EXTERNAL
                            |
                            v
                         User
                            |
                         HTTPS
                            |
                            v
                       Gateway
                            |
                            v
               Istio Ingress Gateway
                    [Envoy Proxy]
                            |
                            v
             +---------------------------+
             |       ORDER POD            |
             |                            |
             |  Order Service             |
             |       ^                    |
             |       |                    |
             |  Order Envoy               |
             +-------+--------------------+
                     |
                     | mTLS
                     v
             +---------------------------+
             |      PAYMENT POD           |
             |                            |
             |  Payment Envoy             |
             |       |                    |
             |       v                    |
             |  Payment Service           |
             +---------------------------+
```

If Payment calls Order back:

```text
Payment Service
       |
       v
Payment Envoy
       |
       | mTLS
       v
Order Envoy
       |
       v
Order Service
```

---

# 17. What is mTLS?

mTLS stands for:

> Mutual Transport Layer Security

It provides encryption and mutual authentication between workloads.

Without mTLS:

```text
Order Envoy ------------------> Payment Envoy
              Plain/ordinary
                traffic
```

With mTLS:

```text
Order Envoy ==================> Payment Envoy
              Encrypted +
              authenticated
```

Istio can manage workload identity and mTLS between participating workloads.

This means:

```text
Order Service
     |
     v
Order Envoy
     |
     | mTLS
     v
Payment Envoy
     |
     v
Payment Service
```

---

# 18. mTLS vs User Authentication

mTLS and user authentication solve different problems.

## User Authentication

Our project will use Microsoft Entra ID for user/application identity.

Conceptually:

```text
User
 |
 v
Microsoft Entra ID
 |
 v
JWT Access Token
 |
 v
API
```

## Service-to-Service Security

Istio mTLS is used for workload/service-to-service communication.

```text
Order Service
     |
     v
Order Envoy
     |
     | mTLS
     v
Payment Envoy
     |
     v
Payment Service
```

Therefore:

```text
Entra ID
    =
User/Application Identity


Istio mTLS
    =
Workload/Service Identity + Secure Service Communication
```

Istio does not replace Entra ID.

---

# 19. Example — Retry

Suppose:

```text
Order Service → Payment Service
```

Payment temporarily fails.

Without Istio, retry logic might be implemented inside Java:

```java
try {
    callPaymentService();
} catch (Exception e) {
    retry();
}
```

With Istio, retry behavior can be configured at the traffic-management layer.

Conceptually:

```text
Order Service
      |
      v
Order Envoy
      |
      | Request
      v
Payment Envoy
      |
      X Failure
      |
      v
Retry according to Istio policy
```

This allows networking behavior to be managed separately from business logic.

---

# 20. Example — Timeout

Suppose Payment Service becomes slow.

```text
Order Service
      |
      v
Payment Service
      |
      | 30 seconds...
```

A long-running dependency can cause resource exhaustion and cascading failures.

Istio can enforce a timeout policy.

Conceptually:

```text
Order Envoy
      |
      | timeout = 3 seconds
      v
Payment Envoy
      |
      v
Payment Service
```

If the configured timeout is exceeded, Istio can terminate the request according to the configured policy.

---

# 21. Example — Circuit Breaking

Suppose Payment Service is continuously failing.

Without protection:

```text
Order
  |
  +--> Payment ❌
  |
  +--> Payment ❌
  |
  +--> Payment ❌
  |
  +--> Payment ❌
```

This can contribute to cascading failures.

Istio can apply connection-pool and outlier-detection-related traffic policies to help protect services.

Conceptually:

```text
Order
  |
  v
Order Envoy
  |
  X Payment unhealthy
```

Traffic can be controlled according to the configured policy.

---

# 22. Example — Canary Deployment

Suppose we deploy:

```text
Order Service v1
Order Service v2
```

We want:

```text
90% → v1
10% → v2
```

Istio can control traffic distribution.

```text
                  Istio
                    |
           +--------+--------+
           |                 |
          90%               10%
           |                 |
           v                 v
       Order v1          Order v2
```

This allows us to introduce a new version gradually.

---

# 23. Kubernetes vs Istio

Kubernetes and Istio have different responsibilities.

## Kubernetes

Kubernetes manages:

```text
Pods
Deployments
Services
Scheduling
Scaling
ConfigMaps
Secrets
Workloads
```

Think:

> Kubernetes runs and manages the services.

## Istio

Istio manages service-to-service communication concerns such as:

```text
Traffic Routing
Retries
Timeouts
Circuit Breaking
mTLS
Traffic Splitting
Telemetry
```

Think:

> Istio manages communication between the services.

Therefore:

```text
             Kubernetes
       "Run my services"

                  +

                Istio
       "Manage communication
        between my services"
```

They complement each other.

---

# 24. Kubernetes vs Spring Boot vs Istio

These three layers have different responsibilities.

```text
+------------------------------------------+
| Spring Boot                              |
|                                          |
| Business Logic                           |
| REST APIs                                |
| Validation                               |
| Database Access                          |
| Order Processing                         |
+------------------------------------------+

+------------------------------------------+
| Istio / Envoy                            |
|                                          |
| Traffic Management                       |
| Retry                                    |
| Timeout                                  |
| mTLS                                     |
| Routing                                  |
| Telemetry                                |
+------------------------------------------+

+------------------------------------------+
| Kubernetes                               |
|                                          |
| Pods                                     |
| Deployments                              |
| Services                                 |
| Scheduling                               |
| Scaling                                  |
+------------------------------------------+
```

---

# 25. Why are we learning Istio separately from APIM and NGINX?

Our final architecture is planned to include:

```text
Client
  |
  v
Microsoft Entra ID
  |
  v
Azure API Management
  |
  v
NGINX Ingress
  |
  v
Istio
  |
  v
Order Service
```

However, we intentionally did NOT introduce APIM and NGINX during our first Istio lab.

The reason is learning isolation.

If we introduce:

```text
APIM
 |
 v
NGINX
 |
 v
Istio
 |
 v
Kubernetes
 |
 v
Spring Boot
```

at the beginning, troubleshooting becomes difficult.

If something fails, we wouldn't immediately know whether the problem is:

```text
APIM
NGINX
Istio
Kubernetes
Spring Boot
```

Instead, our first Istio lab uses a much simpler architecture:

```text
User
 |
 v
Istio Ingress Gateway
 |
 v
Order Service
```

After we understand Istio properly, we will introduce APIM and NGINX and discuss their roles and whether both are necessary in a particular production architecture.

---

# 26. Our Local Environment

Before installing Istio, we verified the following tools.

## Docker

```text
Docker version 28.2.2
```

## kubectl

```text
Client Version: v1.32.2
```

## Helm

```text
v4.3.0
```

## Kubernetes

Docker Desktop Kubernetes is running:

```text
NAME             STATUS   ROLES           VERSION
docker-desktop   Ready    control-plane   v1.32.2
```

## Istio CLI

We downloaded:

```text
istioctl-1.31.0-win-amd64.zip
```

and configured:

```text
C:\istio\bin
```

in the Windows PATH.

We verified:

```powershell
istioctl version
```

and received:

```text
client version: 1.31.0
```

Before installation, the command reported:

```text
Istio is not present in the cluster
```

This was expected because the CLI was installed but Istio had not yet been installed into Kubernetes.

---

# 27. Istio Installation

We installed Istio using:

```powershell
istioctl install --set profile=default
```

The `default` profile provides a baseline Istio installation suitable for our initial learning environment.

We are using the traditional sidecar-based architecture for this learning project.

We are intentionally learning:

```text
Application Pod
+
Envoy Sidecar
```

before exploring other Istio deployment models.

---

# 28. Verify Istio Installation

We checked:

```powershell
kubectl get pods -n istio-system
```

and received:

```text
NAME                                    READY   STATUS    RESTARTS   AGE
istio-ingressgateway-774674bf6f-whf4m   1/1     Running   0          ...
istiod-6df77cd54d-75hdp                 1/1     Running   0          ...
```

This confirms that the main Istio components are running.

---

# 29. Verify Istio Versions

We ran:

```powershell
istioctl version
```

and received:

```text
client version: 1.31.0
control plane version: 1.31.0
data plane version: 1.31.0
```

This confirmed that our Istio client and installed Istio components are aligned at version 1.31.0.

At that point, the reported data plane proxy was the Envoy proxy associated with the Istio Ingress Gateway.

Our application service had not yet been deployed into the mesh.

---

# 30. Istio System Namespace

Istio infrastructure components are running in:

```text
istio-system
```

Our future application namespaces will be:

```text
order-dev
order-qa
order-prod
```

Conceptually:

```text
Kubernetes
|
+-- istio-system
|   |
|   +-- istiod
|   |
|   +-- Istio Ingress Gateway
|
+-- order-dev
|   |
|   +-- Order Service
|
+-- order-qa
|   |
|   +-- Order Service
|
+-- order-prod
    |
    +-- Order Service
```

The separation helps distinguish platform infrastructure from application workloads.

---

# 31. Current Istio Architecture

At the end of this lesson, our local environment looks like:

```text
                 Docker Desktop
                      |
                      v
                 Kubernetes
                      |
                      v
                +-------------+
                |   Istio     |
                |             |
                |  istiod     |
                |     |       |
                |     v       |
                | Ingress GW  |
                |   Envoy     |
                +-------------+
```

Our Order Service is not yet part of the mesh.

That is the next implementation stage.

---

# 32. What We Have Completed

```text
Docker                         ✅
kubectl                        ✅
Helm                           ✅
Docker Desktop Kubernetes      ✅
Kubernetes Node Ready          ✅
istioctl                       ✅
Istio 1.31.0                   ✅
Istio Control Plane            ✅
istiod                          ✅
Istio Ingress Gateway           ✅
Order Service in Istio Mesh     ⏳
Envoy Sidecar                   ⏳
Istio Gateway Configuration     ⏳
VirtualService                  ⏳
DestinationRule                 ⏳
Retries                         ⏳
Timeouts                        ⏳
Circuit Breaking                ⏳
Canary Deployment               ⏳
mTLS                            ⏳
Observability                   ⏳
```

---

# 33. Our Next Implementation Stage

The next stage is:

```text
Dockerize Order Service
        |
        v
Create Kubernetes Namespace
        |
        v
Create Kubernetes Deployment
        |
        v
Create Kubernetes Service
        |
        v
Enable Istio Sidecar Injection
        |
        v
Deploy Order Service
        |
        v
Verify Pod
        |
        v
Spring Boot Container + Envoy Sidecar
```

Eventually we want to see:

```text
kubectl get pods -n order-dev
```

show something conceptually like:

```text
NAME                            READY
order-service-xxxxx-xxxxx       2/2
```

The `2/2` means the Pod contains two running containers:

```text
1. order-service
2. istio-proxy
```

This will be our first practical proof that the application has joined the Istio service mesh.

---

# 34. Important Mental Model

The most important request-flow model from this lesson is:

## External Request

```text
User
 |
 v
Gateway
 |
 v
Istio Ingress Gateway
 |
 v
Destination Envoy
 |
 v
Destination Application
```

## Service-to-Service Request

```text
Source Application
 |
 v
Source Envoy
 |
 | mTLS / Istio-managed traffic
 v
Destination Envoy
 |
 v
Destination Application
```

## Payment Calling Order Back

```text
Payment Service
 |
 v
Payment Envoy
 |
 | mTLS
 v
Order Envoy
 |
 v
Order Service
```

Remember:

> The Istio Ingress Gateway is for traffic entering the mesh. Internal service-to-service communication normally happens through the Envoy sidecars.

---

# 35. Key Takeaways

### Istio

Istio is a service mesh used to manage service-to-service communication.

### istiod

`istiod` is the primary Istio control-plane component.

### Envoy

Envoy is the data-plane proxy used by Istio.

### Sidecar

A sidecar Envoy runs alongside an application container in the same Kubernetes Pod.

### Ingress Gateway

The Istio Ingress Gateway provides an entry point for traffic coming from outside the service mesh.

### Internal communication

Internal communication follows:

```text
Source Application
      ↓
Source Envoy
      ↓
Destination Envoy
      ↓
Destination Application
```

### mTLS

Istio can provide encrypted and authenticated service-to-service communication using mTLS.

### Kubernetes

Kubernetes manages the workloads.

### Istio

Istio manages communication between those workloads.

### Application

Spring Boot contains our business logic.

---

# 36. Interview Summary

If asked:

## What is Istio?

> Istio is a service mesh that provides traffic management, security, and observability for service-to-service communication without requiring all of these networking concerns to be implemented directly in application code.

## What is the control plane?

> The control plane manages and distributes configuration and control information to the data-plane proxies.

## What is the data plane?

> The data plane consists of proxies that participate in handling application traffic.

## Which proxy does Istio use?

> Envoy.

## What is istiod?

> `istiod` is the primary Istio control-plane component.

## Does Istio replace Kubernetes?

> No. Kubernetes manages workloads and orchestration, while Istio manages service-to-service communication.

## Does Istio replace Entra ID?

> No. Entra ID provides identity and authentication for users/applications, while Istio mTLS provides workload identity and secure service-to-service communication.

## Does every internal request go through the Istio Ingress Gateway?

> No. The Ingress Gateway is primarily for traffic entering the mesh. Internal service-to-service traffic normally flows through the source and destination Envoy proxies.

## Does the request go directly from the Istio Ingress Gateway to the Spring Boot application?

> In a sidecar-based Istio mesh, the request is handled by the destination workload's Envoy sidecar before reaching the application container.

---

# 37. Learning Principle

For this project, we will not simply create Istio YAML files.

For every Istio feature, we will follow:

```text
Understand the problem
        ↓
Understand the Istio solution
        ↓
Design the configuration
        ↓
Implement it
        ↓
Create a real test scenario
        ↓
Observe the behavior
        ↓
Understand failure scenarios
        ↓
Document it
        ↓
Prepare interview questions
```

The objective is not just to know Istio commands.

The objective is to understand **why Istio is used, how traffic actually flows, how Envoy participates in the flow, and how to troubleshoot it in a production environment.**

````

### 📌 Where we are now

Your `lesson1.md` now covers **everything we've discussed from the beginning of the Istio implementation up to the current point**.

The next lesson/implementation checkpoint is:

```text
                    CURRENT
                       ↓
Istio installed and healthy
                       |
                       v
              Dockerize order-service
                       |
                       v
              Kubernetes Deployment
                       |
                       v
                Kubernetes Service
                       |
                       v
              Istio Sidecar Injection
                       |
                       v
                 Verify 2/2 Pod
````

**I recommend saving this as `docs/lessons/lesson1.md` now.** After you confirm it is saved, we'll continue with the **design review for Dockerizing `order-service`**—and, as you requested, I'll show you the files, naming, architecture and decisions **before** we create them.
