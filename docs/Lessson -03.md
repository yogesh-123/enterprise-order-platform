Absolutely. Below is a **complete Lesson 3 document** written so you can directly replace the contents of:

```text
docs/lessons/lesson3.md
```

I’ve kept the language easy, but explained the **What + Why + How + Example + Interview angle** for each important concept. I’ve also included the troubleshooting issue we actually encountered, because that is valuable production/interview knowledge.

---

````markdown
# Lesson 3 — Kubernetes Fundamentals: Deploying the Order Service

## 1. Objective

In Lesson 2, we containerized the Order Service using Docker.

At the end of Lesson 2, our architecture was:

```text
Spring Boot Application
        |
        v
    Docker Container
        |
        v
   PostgreSQL Container
````

In this lesson, we move the application into Kubernetes.

The goal is to understand how Kubernetes:

* Runs our Docker image
* Creates and manages application Pods
* Exposes the application through a Kubernetes Service
* Provides internal networking
* Stores sensitive configuration using Secrets
* Performs health checks
* Restarts unhealthy containers
* Manages application lifecycle
* Provides a foundation for Istio

We intentionally use **plain Kubernetes first**.

Istio will be introduced in the next lesson.

This is important because we first want to understand what Kubernetes itself provides before adding a service mesh.

---

# 2. What is Kubernetes?

Kubernetes is a platform for running and managing containerized applications.

Docker can run a container.

Kubernetes manages containers at a larger level.

For example, suppose we have:

```text
Order Service
```

We could manually run:

```bash
docker run order-service:0.1.0
```

But in production, we don't want to manually:

* Start containers
* Restart crashed containers
* Keep track of IP addresses
* Decide where containers should run
* Scale applications
* Perform health checks
* Route traffic to healthy instances

Kubernetes handles these responsibilities.

A simplified view is:

```text
                 Kubernetes Cluster
                        |
          +-------------+-------------+
          |             |             |
          v             v             v
       Pod           Pod           Pod
       Order         Order         Order
       Service       Service       Service
```

Kubernetes continuously tries to make the actual state match the desired state.

For example:

```text
Desired state:
3 Order Service Pods
```

If one Pod crashes:

```text
Current state:
2 Pods
```

Kubernetes notices the difference and creates another Pod.

```text
Desired: 3
Current: 2
       |
       v
Kubernetes creates another Pod
       |
       v
Current: 3
```

This is one of the most important Kubernetes concepts.

---

# 3. Kubernetes Architecture — High Level

A Kubernetes cluster has two major logical parts:

```text
Kubernetes Cluster
│
├── Control Plane
│
└── Worker Nodes
```

## 3.1 Control Plane

The Control Plane is responsible for managing the cluster.

Important components include:

* API Server
* Scheduler
* Controller Manager
* etcd

We don't need to manage these manually in our Docker Desktop Kubernetes environment.

In managed Kubernetes such as Azure Kubernetes Service (AKS), Azure manages the control plane for us.

---

## 3.2 Worker Node

Worker nodes actually run our application workloads.

A simplified structure is:

```text
Worker Node
│
├── Pod
│   └── Order Service Container
│
├── Pod
│   └── Another Application
│
└── Pod
    └── Another Application
```

In our local environment, Docker Desktop provides the Kubernetes cluster.

---

# 4. Our Local Environment

Before starting this lesson, the following tools were already installed:

```text
Docker
kubectl
Helm
Istio CLI
Docker Desktop Kubernetes
```

Verify Kubernetes:

```powershell
kubectl version --client
```

Check nodes:

```powershell
kubectl get nodes
```

Expected result:

```text
NAME             STATUS   ROLES           AGE
docker-desktop   Ready    control-plane   ...
```

The important part is:

```text
STATUS = Ready
```

This means Kubernetes is available.

---

# 5. What is a Namespace?

A Kubernetes Namespace provides logical isolation inside a cluster.

Think of it like a folder.

For example:

```text
Kubernetes Cluster
│
├── istio-system
│
├── order-dev
│
├── order-qa
│
└── order-prod
```

Our application will initially run inside:

```text
order-dev
```

---

## Why use namespaces?

Without namespaces, everything would exist in one large shared environment.

Namespaces help separate:

* Development
* QA
* Production
* Platform components
* Teams
* Applications

For example:

```text
order-dev
    └── Order Service

order-qa
    └── Order Service

order-prod
    └── Order Service
```

The same application can therefore exist in different environments.

---

# 6. Creating the Namespace

File:

```text
kubernetes/namespaces/order-dev.yaml
```

Content:

```yaml
apiVersion: v1
kind: Namespace

metadata:
  name: order-dev
```

---

## Explanation

### apiVersion

```yaml
apiVersion: v1
```

This tells Kubernetes which API version is being used.

Namespace belongs to the core Kubernetes API, so:

```text
v1
```

is used.

---

### kind

```yaml
kind: Namespace
```

This tells Kubernetes what object we want to create.

Here we are creating a:

```text
Namespace
```

---

### metadata

```yaml
metadata:
  name: order-dev
```

Metadata provides information about the object.

The name of our namespace is:

```text
order-dev
```

---

## Apply the namespace

```powershell
kubectl apply -f kubernetes/namespaces/order-dev.yaml
```

Check it:

```powershell
kubectl get namespaces
```

Expected:

```text
order-dev   Active
```

---

# 7. What is a Pod?

A Pod is the smallest deployable unit in Kubernetes.

A common beginner mistake is to think:

```text
Pod = Container
```

They are related but not exactly the same.

A Pod is a wrapper around one or more containers.

For our application:

```text
Pod
└── Order Service Container
```

In more advanced scenarios:

```text
Pod
├── Application Container
└── Sidecar Container
```

This becomes very important when we introduce Istio.

With Istio:

```text
Order Service Pod
│
├── Order Service Container
│
└── Istio Envoy Sidecar
```

We will use this architecture later.

---

# 8. Why Don't We Create Pods Directly?

Technically, we can create a Pod directly.

But normally we don't.

Instead, we use a:

```text
Deployment
```

A Deployment manages Pods for us.

For example:

```text
Deployment
     |
     +---- Pod
     |
     +---- Pod
     |
     +---- Pod
```

If one Pod crashes:

```text
Deployment
     |
     +---- Pod
     |
     +---- Pod
     |
     +---- New Pod
```

The Deployment maintains the desired number of replicas.

---

# 9. What is a Deployment?

A Deployment is a Kubernetes object used to manage application Pods.

It describes the desired state.

For example:

```yaml
replicas: 3
```

means:

```text
I want 3 Pods running.
```

Kubernetes continuously tries to maintain that state.

---

# 10. Our Order Service Deployment

File:

```text
kubernetes/base/order-service/deployment.yaml
```

Current configuration:

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: order-service
  namespace: order-dev
  labels:
    app: order-service

spec:
  replicas: 1

  selector:
    matchLabels:
      app: order-service

  template:
    metadata:
      labels:
        app: order-service

    spec:
      containers:
        - name: order-service
          image: order-service:0.1.0
          imagePullPolicy: IfNotPresent

          ports:
            - name: http
              containerPort: 8080
              protocol: TCP

          env:
            - name: SPRING_DATASOURCE_URL
              value: jdbc:postgresql://host.docker.internal:5432/orderdb

            - name: SPRING_DATASOURCE_USERNAME
              valueFrom:
                secretKeyRef:
                  name: order-db-secret
                  key: SPRING_DATASOURCE_USERNAME

            - name: SPRING_DATASOURCE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: order-db-secret
                  key: SPRING_DATASOURCE_PASSWORD

          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: http
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3

          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: http
            initialDelaySeconds: 30
            periodSeconds: 20
            timeoutSeconds: 3
            failureThreshold: 3

          resources:
            requests:
              cpu: 100m
              memory: 256Mi

            limits:
              cpu: 500m
              memory: 512Mi
```

Let's understand every important section.

---

# 11. apiVersion

```yaml
apiVersion: apps/v1
```

Deployment belongs to the Kubernetes Apps API.

We use:

```text
apps/v1
```

---

# 12. kind

```yaml
kind: Deployment
```

This tells Kubernetes:

```text
Create/manage a Deployment.
```

---

# 13. metadata

```yaml
metadata:
  name: order-service
  namespace: order-dev
  labels:
    app: order-service
```

The Deployment is named:

```text
order-service
```

and exists inside:

```text
order-dev
```

---

# 14. Labels

Labels are key-value pairs attached to Kubernetes objects.

Example:

```yaml
labels:
  app: order-service
```

This is extremely important because Kubernetes uses labels to identify related objects.

For example, our Service will use:

```yaml
selector:
  app: order-service
```

That means:

```text
Find Pods with:
app = order-service
```

Therefore:

```text
Service
   |
   | selector: app=order-service
   |
   v
Pod
   |
   | label: app=order-service
```

Labels and selectors are fundamental Kubernetes concepts.

---

# 15. replicas

```yaml
replicas: 1
```

This means:

```text
Run one Pod.
```

For production we might use:

```yaml
replicas: 3
```

Then Kubernetes tries to maintain:

```text
3 Order Service Pods
```

For local learning, one replica is enough.

---

# 16. selector

```yaml
selector:
  matchLabels:
    app: order-service
```

This tells the Deployment which Pods it owns.

The selector must match the labels defined in:

```yaml
template:
  metadata:
    labels:
      app: order-service
```

So:

```text
Deployment selector
       |
       | app=order-service
       |
       v
Pod label
       |
       | app=order-service
```

---

# 17. Pod Template

This section:

```yaml
template:
  metadata:
    labels:
      app: order-service

  spec:
    containers:
      ...
```

describes how Pods should be created.

Think of it as a blueprint.

The Deployment says:

```text
Whenever I need a new Pod,
create it using this template.
```

---

# 18. Container Image

Our application uses:

```yaml
image: order-service:0.1.0
```

This is the Docker image created in Lesson 2.

We previously built:

```text
order-service:0.1.0
```

Kubernetes runs this image inside the Pod.

Therefore:

```text
Docker Image
     |
     v
Kubernetes Pod
     |
     v
Order Service Container
```

---

# 19. imagePullPolicy

We use:

```yaml
imagePullPolicy: IfNotPresent
```

This is useful for local development.

It means:

```text
If the image already exists locally,
use the local image.

Otherwise try to pull it.
```

This is important because our image:

```text
order-service:0.1.0
```

exists in our local Docker environment.

In a production environment, we will eventually use:

```text
Azure Container Registry (ACR)
```

For example:

```text
myregistry.azurecr.io/order-service:1.0.0
```

Then AKS pulls the image from ACR.

---

# 20. Container Port

```yaml
ports:
  - name: http
    containerPort: 8080
    protocol: TCP
```

Our Spring Boot application runs on:

```text
8080
```

Therefore we declare:

```text
containerPort: 8080
```

Important:

`containerPort` does NOT publish the application outside Kubernetes.

It mainly documents the port used by the container and allows other Kubernetes configuration to refer to it.

Actual application exposure is handled by a:

```text
Service
```

---

# 21. Environment Variables

Our Spring Boot application expects:

```text
SPRING_DATASOURCE_URL
SPRING_DATASOURCE_USERNAME
SPRING_DATASOURCE_PASSWORD
```

Our application.yaml contains:

```yaml
spring:
  datasource:
    url: ${SPRING_DATASOURCE_URL}
    username: ${SPRING_DATASOURCE_USERNAME}
    password: ${SPRING_DATASOURCE_PASSWORD}
```

Therefore Kubernetes provides these values through environment variables.

---

# 22. Database URL

For local Kubernetes:

```yaml
- name: SPRING_DATASOURCE_URL
  value: jdbc:postgresql://host.docker.internal:5432/orderdb
```

This deserves special attention.

Our PostgreSQL database is currently running in Docker, not inside Kubernetes.

Therefore the architecture is:

```text
Kubernetes Pod
      |
      | host.docker.internal:5432
      |
      v
Docker PostgreSQL
```

`host.docker.internal` is a Docker Desktop-specific hostname that allows containers to reach services running on the host/Docker Desktop environment.

This is a **local development setup**.

We should NOT copy this into production Azure Kubernetes configuration.

Later the production architecture will look more like:

```text
AKS
 |
 | private network
 |
 v
Azure Database for PostgreSQL
```

---

# 23. Kubernetes Secret

Database username and password should not be hard-coded directly into the Deployment.

Instead, we created:

```text
order-db-secret
```

inside:

```text
order-dev
```

using:

```powershell
kubectl create secret generic order-db-secret `
  -n order-dev `
  --from-literal=SPRING_DATASOURCE_USERNAME=orderapp `
  --from-literal=SPRING_DATASOURCE_PASSWORD=orderapp_local_password
```

Check it:

```powershell
kubectl get secrets -n order-dev
```

Expected:

```text
order-db-secret
```

---

# 24. Why use Secrets?

Bad approach:

```yaml
env:
  - name: SPRING_DATASOURCE_PASSWORD
    value: mypassword
```

This creates a serious security problem.

The password can end up in:

* Git
* Pull requests
* Logs
* Developer machines
* Configuration history

Better:

```text
Deployment
     |
     v
Secret
     |
     v
Environment Variable
     |
     v
Spring Boot
```

Our Deployment uses:

```yaml
valueFrom:
  secretKeyRef:
    name: order-db-secret
    key: SPRING_DATASOURCE_PASSWORD
```

Meaning:

```text
Read the password from the Kubernetes Secret.
```

---

# 25. Important Secret Security Note

A Kubernetes Secret is better than putting a password directly in a Deployment, but it should NOT be treated as the final enterprise-grade secret-management solution.

In production Azure architecture, we will use:

```text
Azure Key Vault
        |
        v
Managed Identity / Workload Identity
        |
        v
AKS
```

The production design will avoid storing application secrets directly in Git.

This will be covered later.

---

# 26. Readiness Probe

Our application has:

```yaml
readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: http
```

Readiness answers:

> "Can this Pod receive traffic?"

This is different from:

> "Is the process alive?"

---

## Example

Suppose we have three Pods:

```text
Pod A → Ready
Pod B → Ready
Pod C → Not Ready
```

Kubernetes Service should send traffic only to:

```text
Pod A
Pod B
```

and not:

```text
Pod C
```

Once Pod C becomes Ready:

```text
Pod A → Ready
Pod B → Ready
Pod C → Ready
```

the Service can send traffic to all three.

---

# 27. Why Readiness Matters

Imagine our application is starting.

Spring Boot may need several seconds to:

* Start the JVM
* Initialize Spring
* Create beans
* Connect to the database
* Start the web server

If Kubernetes sends traffic immediately, requests could fail.

Readiness prevents this.

Flow:

```text
Pod starts
   |
   v
Application starting
   |
   v
Readiness = NOT READY
   |
   v
No application traffic
   |
   v
Application ready
   |
   v
Readiness = READY
   |
   v
Traffic allowed
```

---

# 28. Liveness Probe

Our Deployment also contains:

```yaml
livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: http
```

Liveness answers:

> "Is this application still alive?"

If the application becomes stuck or unhealthy in a way that means it should be restarted, Kubernetes can restart the container.

Example:

```text
Pod
 |
 v
Application becomes stuck
 |
 v
Liveness probe fails repeatedly
 |
 v
Kubernetes restarts container
 |
 v
Application starts again
```

---

# 29. Readiness vs Liveness

This is an important interview question.

### Readiness

Question:

```text
Can I send traffic to this Pod?
```

Failure means:

```text
Remove Pod from Service traffic.
```

It does NOT necessarily restart the container.

---

### Liveness

Question:

```text
Is this application alive?
```

Failure means:

```text
Kubernetes may restart the container.
```

---

## Easy way to remember

```text
Readiness = Should I send traffic?

Liveness = Should I restart it?
```

---

# 30. Startup Probe

For production-grade Kubernetes applications, startup time should also be considered.

A Java/Spring Boot application may take some time to start.

A startup probe allows Kubernetes to give the application time to initialize before liveness checking becomes aggressive.

Conceptually:

```text
Container starts
       |
       v
Startup Probe
       |
       | SUCCESS
       v
Liveness + Readiness
```

Without an appropriate startup strategy:

```text
Application still starting
       |
       v
Liveness probe fails
       |
       v
Kubernetes restarts application
       |
       v
Application starts again
       |
       v
Liveness fails again
       |
       v
CrashLoopBackOff
```

This is especially important for JVM applications.

---

# 31. What Happened During Our Deployment?

We actually encountered this problem during Lesson 3.

Initially, PostgreSQL was not reachable from the Kubernetes Pod.

The application therefore could not initialize its database connection correctly.

The Pod started, but eventually the liveness probe failed because the application had not successfully reached a healthy running state.

Kubernetes restarted the container.

We saw:

```text
CrashLoopBackOff
```

and the Pod accumulated historical restarts.

The important lesson was:

> A probe failure can be a symptom of an underlying infrastructure or dependency problem. Do not immediately change application configuration to hide the symptom.

---

# 32. Why Hibernate Initially Reported a Dialect Error

The application produced an error similar to:

```text
Unable to determine Dialect without JDBC metadata
```

At first glance, this can look like a Hibernate configuration problem.

For example, someone might incorrectly add:

```properties
hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
```

just to make the error disappear.

That would not solve the real problem.

The actual issue was:

```text
Kubernetes Pod
       |
       X
PostgreSQL unreachable
```

Hibernate couldn't obtain JDBC metadata because it couldn't establish the database connection.

Therefore:

```text
Hibernate error
      ↓
Database connectivity problem
```

not:

```text
Hibernate configuration problem
```

This is an important production troubleshooting lesson.

---

# 33. How We Fixed the Database Connectivity Problem

We checked the PostgreSQL container:

```powershell
docker inspect enterprise-order-postgres --format '{{json .NetworkSettings.Ports}}'
```

The result showed that port 5432 was not mapped to the host.

The container was effectively showing:

```text
5432/tcp
```

instead of:

```text
0.0.0.0:5432->5432/tcp
```

We recreated PostgreSQL using:

```powershell
docker compose up -d --force-recreate postgres
```

After that:

```text
PostgreSQL
0.0.0.0:5432 -> 5432/tcp
```

The Kubernetes Pod could then connect successfully.

This demonstrates an important troubleshooting principle:

> Always verify the dependency before changing application configuration.

---

# 34. Resource Requests

Our Deployment contains:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
```

A request tells Kubernetes:

> "I need approximately this amount of resources to run."

For CPU:

```text
100m
```

means:

```text
100 millicpu
= 0.1 CPU
```

For memory:

```text
256Mi
```

means approximately:

```text
256 MiB
```

---

# 35. Why Resource Requests Matter

Kubernetes Scheduler uses resource requests when deciding where a Pod can run.

For example:

```text
Node has:
2 CPU
4 GiB memory
```

If a Pod requests:

```text
100m CPU
256Mi memory
```

the scheduler considers those requirements.

Without requests, Kubernetes has less information for proper scheduling.

---

# 36. Resource Limits

Our Deployment also contains:

```yaml
limits:
  cpu: 500m
  memory: 512Mi
```

This defines the maximum resources available to the container according to Kubernetes/container runtime behavior.

Our application therefore has:

```text
Request:
CPU    = 100m
Memory = 256Mi

Limit:
CPU    = 500m
Memory = 512Mi
```

---

# 37. Requests vs Limits

Easy way to remember:

```text
Request = What Kubernetes should reserve/plan for.

Limit = Maximum amount the container is allowed to consume.
```

Example:

```text
CPU request = 100m
CPU limit   = 500m
```

The application normally gets scheduled based on 100m, but can use more CPU up to the configured limit.

---

# 38. Applying the Deployment

Apply:

```powershell
kubectl apply -f kubernetes/base/order-service/deployment.yaml
```

Check the Deployment:

```powershell
kubectl get deployments -n order-dev
```

Expected:

```text
NAME            READY   UP-TO-DATE   AVAILABLE
order-service   1/1     1            1
```

---

# 39. Checking the Pod

Run:

```powershell
kubectl get pods -n order-dev
```

Example:

```text
NAME                            READY   STATUS    RESTARTS   AGE
order-service-xxxxxxxxxx-xxxxx  1/1     Running   0          ...
```

Important fields:

### READY

```text
1/1
```

Means:

```text
1 container expected
1 container ready
```

---

### STATUS

```text
Running
```

Means the Pod is running.

---

### RESTARTS

Shows how many times the container has restarted.

Our Pod had historical restarts during troubleshooting.

That does not mean it is currently unhealthy.

Always combine:

```text
STATUS
READY
RESTARTS
Events
Logs
```

when diagnosing a Pod.

---

# 40. Checking Pod Details

Use:

```powershell
kubectl describe pod <pod-name> -n order-dev
```

For example:

```powershell
kubectl describe pod order-service-xxxxxxxxxx-xxxxx -n order-dev
```

This provides:

* Pod details
* Node
* IP address
* Container information
* Environment variables
* Probes
* Resource configuration
* Events
* Restart information

One of the most useful sections during troubleshooting is:

```text
Events
```

---

# 41. Viewing Logs

Use:

```powershell
kubectl logs -n order-dev <pod-name>
```

Example:

```powershell
kubectl logs -n order-dev order-service-xxxxxxxxxx-xxxxx
```

This is usually the first place to look when a Spring Boot application fails.

---

# 42. What is a Kubernetes Service?

A Pod IP is temporary.

For example:

```text
Pod
IP = 10.1.0.63
```

If the Pod is deleted and recreated:

```text
Old Pod
10.1.0.63
```

could become:

```text
New Pod
10.1.0.91
```

Applications should not depend on changing Pod IPs.

A Kubernetes Service provides a stable network endpoint.

Architecture:

```text
Client
  |
  v
Service
  |
  +---- Pod
  |
  +---- Pod
  |
  +---- Pod
```

---

# 43. Our Kubernetes Service

File:

```text
kubernetes/base/order-service/service.yaml
```

Content:

```yaml
apiVersion: v1
kind: Service

metadata:
  name: order-service
  namespace: order-dev

spec:
  type: ClusterIP

  selector:
    app: order-service

  ports:
    - name: http
      protocol: TCP
      port: 8080
      targetPort: http
```

---

# 44. Service Type: ClusterIP

We use:

```yaml
type: ClusterIP
```

ClusterIP means:

> The Service is reachable inside the Kubernetes cluster.

It is not directly exposed to the public internet.

This is appropriate for our current architecture because we are first learning Kubernetes internally.

Later:

```text
Client
   |
   v
API Management
   |
   v
Ingress
   |
   v
Istio
   |
   v
Order Service
```

will provide controlled external access.

---

# 45. Service Selector

The Service contains:

```yaml
selector:
  app: order-service
```

This means:

```text
Find Pods with:

app = order-service
```

Our Pod has:

```yaml
labels:
  app: order-service
```

Therefore the Service finds it.

This relationship is critical:

```text
Service selector
       |
       | app=order-service
       v
Pod label
       |
       | app=order-service
       v
Pod
```

---

# 46. Service Port vs Target Port

This is another common interview question.

Our Service says:

```yaml
ports:
  - port: 8080
    targetPort: http
```

There are two concepts.

### port

```text
8080
```

This is the port exposed by the Service.

### targetPort

```text
http
```

This points to the Pod's container port named:

```yaml
name: http
```

which is:

```text
8080
```

So:

```text
Service :8080
      |
      v
Pod :8080
```

---

# 47. Applying the Service

Run:

```powershell
kubectl apply -f kubernetes/base/order-service/service.yaml
```

Check:

```powershell
kubectl get svc -n order-dev
```

Our Service looked like:

```text
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
order-service   ClusterIP   10.96.203.233   <none>        8080/TCP
```

The important point is:

```text
TYPE = ClusterIP
```

and:

```text
PORT = 8080
```

---

# 48. Checking Service Endpoints

Run:

```powershell
kubectl get endpoints -n order-dev order-service
```

Our result was:

```text
order-service   10.1.0.63:8080
```

This is very useful.

It tells us that the Service has discovered the Pod.

Conceptually:

```text
Service
order-service
     |
     | selector app=order-service
     |
     v
10.1.0.63:8080
```

If the endpoint list is empty:

```text
<none>
```

then traffic cannot reach a Pod through the Service.

Common reasons include:

* Wrong selector
* Wrong Pod labels
* Pod is not Ready
* Pod doesn't exist
* Wrong namespace

---

# 49. Kubernetes DNS

Kubernetes provides DNS for Services.

Our Service:

```text
order-service
```

inside:

```text
order-dev
```

can be referenced internally using Kubernetes DNS.

A fully qualified name follows this pattern:

```text
service.namespace.svc.cluster.local
```

Therefore:

```text
order-service.order-dev.svc.cluster.local
```

means:

```text
Service = order-service
Namespace = order-dev
Cluster domain = cluster.local
```

This becomes very important in microservices.

For example:

```text
Order Service
       |
       | HTTP
       v
Payment Service
```

could call:

```text
http://payment-service.order-prod.svc.cluster.local:8080
```

instead of using a Pod IP.

---

# 50. Port Forwarding

Because our Service is:

```text
ClusterIP
```

it is not directly accessible from our Windows browser.

For local testing we can use:

```powershell
kubectl port-forward -n order-dev svc/order-service 8080:8080
```

This creates a temporary tunnel:

```text
Windows localhost:8080
          |
          v
kubectl port-forward
          |
          v
Kubernetes Service
          |
          v
Order Service Pod
```

We saw:

```text
Forwarding from 127.0.0.1:8080 -> 8080
```

This does NOT expose the application permanently.

It is only a development/testing mechanism.

---

# 51. Testing the Application

With port forwarding running:

```powershell
curl.exe http://localhost:8080/actuator/health
```

We received:

```json
{
  "status": "UP",
  "groups": [
    "liveness",
    "readiness"
  ]
}
```

This confirms the application is healthy.

---

# 52. Kubernetes Liveness Endpoint

Test:

```powershell
curl.exe http://localhost:8080/actuator/health/liveness
```

Expected:

```json
{
  "status": "UP"
}
```

This confirms the application's liveness health group is working.

---

# 53. Kubernetes Readiness Endpoint

Test:

```powershell
curl.exe http://localhost:8080/actuator/health/readiness
```

Expected:

```json
{
  "status": "UP"
}
```

This confirms that the application is ready to receive traffic.

---

# 54. Complete Kubernetes Request Flow

At this stage, our local request flow is:

```text
Browser / curl
      |
      | localhost:8080
      v
kubectl port-forward
      |
      v
Kubernetes Service
order-service:8080
      |
      | selector:
      | app=order-service
      v
Order Service Pod
      |
      v
Spring Boot :8080
      |
      v
PostgreSQL
```

This is our **plain Kubernetes architecture**.

No Istio is involved yet.

---

# 55. Why We Are Not Using Istio Yet

Istio provides additional capabilities such as:

* Service-to-service traffic management
* mTLS
* Retries
* Timeouts
* Circuit breaking
* Traffic splitting
* Canary deployments
* Service-level observability

But if we introduce Istio before understanding Kubernetes networking, it becomes difficult to understand which component is doing what.

Therefore our learning progression is:

```text
Step 1
Spring Boot
   ↓

Step 2
Docker
   ↓

Step 3
Plain Kubernetes
   ↓

Step 4
Istio
   ↓

Step 5
NGINX
   ↓

Step 6
API Management
   ↓

Step 7
Azure
```

This gives us a clean architectural progression.

---

# 56. Current Architecture

After Lesson 3:

```text
                    Local Kubernetes
┌──────────────────────────────────────────────┐
│                                              │
│  Namespace: order-dev                        │
│                                              │
│  ┌───────────────────────────┐               │
│  │ Service                   │               │
│  │ order-service             │               │
│  │ ClusterIP :8080           │               │
│  └─────────────┬─────────────┘               │
│                │                             │
│                ▼                             │
│  ┌───────────────────────────┐               │
│  │ Deployment                │               │
│  │ order-service             │               │
│  │                           │               │
│  │ ┌───────────────────────┐ │               │
│  │ │ Pod                   │ │               │
│  │ │                       │ │               │
│  │ │ Spring Boot           │ │               │
│  │ │ Order Service :8080   │ │               │
│  │ └───────────────────────┘ │               │
│  └───────────────────────────┘               │
│                                              │
└───────────────────┬──────────────────────────┘
                    │
                    │ host.docker.internal
                    ▼
          Docker PostgreSQL
```

---

# 57. Kubernetes Objects Created in Lesson 3

We created the following objects:

```text
Namespace
    |
    └── order-dev

Secret
    |
    └── order-db-secret

Deployment
    |
    └── order-service

Pod
    |
    └── Order Service

Service
    |
    └── order-service
```

---

# 58. Useful kubectl Commands

## Check cluster

```powershell
kubectl get nodes
```

---

## Check namespaces

```powershell
kubectl get namespaces
```

---

## Check Pods

```powershell
kubectl get pods -n order-dev
```

---

## Check Deployments

```powershell
kubectl get deployments -n order-dev
```

---

## Check Services

```powershell
kubectl get svc -n order-dev
```

---

## Check Endpoints

```powershell
kubectl get endpoints -n order-dev
```

---

## Describe a Pod

```powershell
kubectl describe pod <pod-name> -n order-dev
```

---

## View logs

```powershell
kubectl logs <pod-name> -n order-dev
```

---

## Follow logs

```powershell
kubectl logs -f <pod-name> -n order-dev
```

---

## Describe Deployment

```powershell
kubectl describe deployment order-service -n order-dev
```

---

## Describe Service

```powershell
kubectl describe service order-service -n order-dev
```

---

# 59. Troubleshooting Guide

## Problem 1 — Pod is Pending

Check:

```powershell
kubectl describe pod <pod-name> -n order-dev
```

Look at:

```text
Events
```

Possible reasons:

* Insufficient CPU
* Insufficient memory
* Scheduling problem
* Node unavailable

---

# 60. Problem 2 — ImagePullBackOff

Check:

```powershell
kubectl describe pod <pod-name> -n order-dev
```

Possible reasons:

* Image doesn't exist
* Wrong image name
* Wrong tag
* Registry authentication problem

For our local setup verify:

```powershell
docker images
```

Look for:

```text
order-service
0.1.0
```

---

# 61. Problem 3 — CrashLoopBackOff

First check logs:

```powershell
kubectl logs <pod-name> -n order-dev
```

Then:

```powershell
kubectl describe pod <pod-name> -n order-dev
```

Look at:

```text
Events
```

Possible reasons:

* Application startup failure
* Database unavailable
* Configuration problem
* Environment variable missing
* Liveness probe failure
* Memory problem

Do not immediately change the probe configuration.

First identify why the application is failing.

---

# 62. Problem 4 — Service Has No Endpoints

Run:

```powershell
kubectl get endpoints order-service -n order-dev
```

If you see:

```text
<none>
```

check:

```powershell
kubectl get pods -n order-dev --show-labels
```

Verify that the Pod contains:

```text
app=order-service
```

Then compare it with:

```yaml
selector:
  app: order-service
```

The label and selector must match.

---

# 63. Problem 5 — Application Cannot Connect to PostgreSQL

Check PostgreSQL:

```powershell
docker ps
```

Verify port mapping:

```text
0.0.0.0:5432->5432/tcp
```

Check the database container:

```powershell
docker logs enterprise-order-postgres
```

Check Pod logs:

```powershell
kubectl logs <pod-name> -n order-dev
```

Verify:

```text
SPRING_DATASOURCE_URL
SPRING_DATASOURCE_USERNAME
SPRING_DATASOURCE_PASSWORD
```

For our local setup:

```text
jdbc:postgresql://host.docker.internal:5432/orderdb
```

---

# 64. Problem 6 — localhost:8080 Gives Unexpected Results

Remember that another application/container may already be using port 8080.

Check Docker:

```powershell
docker ps
```

If the old standalone container is running:

```text
enterprise-order-service
```

it may be using:

```text
0.0.0.0:8080->8080/tcp
```

Stop it:

```powershell
docker stop enterprise-order-service
```

Then start Kubernetes port forwarding:

```powershell
kubectl port-forward -n order-dev svc/order-service 8080:8080
```

Now:

```text
localhost:8080
```

should clearly refer to the Kubernetes Service through port forwarding.

This was an important issue encountered during our actual Lesson 3 deployment.

---

# 65. Kubernetes vs Docker

Docker and Kubernetes are not competing technologies.

They solve different levels of the problem.

Docker:

```text
Build and run containers
```

Kubernetes:

```text
Manage containerized workloads
```

For example:

```text
Docker
  |
  | builds
  v
order-service:0.1.0
  |
  | runs through Kubernetes
  v
Pod
  |
  v
Deployment
  |
  v
Service
```

---

# 66. Kubernetes vs Istio

Kubernetes provides:

* Pods
* Deployments
* Services
* Scheduling
* Scaling
* Basic networking
* Health management

Istio provides service mesh capabilities:

* Traffic management
* mTLS
* Retries
* Timeouts
* Circuit breaking
* Traffic splitting
* Advanced observability

Therefore:

```text
Kubernetes
     +
Istio
```

is more powerful than Kubernetes alone for a large microservices platform.

---

# 67. Why We Need a Service Mesh

Imagine our future platform contains:

```text
Order Service
Payment Service
Inventory Service
Customer Service
Notification Service
```

The traffic may look like:

```text
Order
  |
  +----> Inventory
  |
  +----> Payment
  |
  +----> Customer
  |
  +----> Notification
```

If every service implements its own:

* Retry logic
* Timeout logic
* mTLS
* Circuit breaker
* Traffic routing
* Metrics

then every team has to implement and maintain the same infrastructure logic.

Istio moves many of these concerns into the platform layer.

Later:

```text
Application Container
        |
        v
Istio Envoy Sidecar
        |
        v
Network
        |
        v
Destination Envoy
        |
        v
Destination Application
```

This is the next major step in our project.

---

# 68. Interview Questions

## Q1. What is a Pod?

A Pod is the smallest deployable unit in Kubernetes and can contain one or more containers.

---

## Q2. Why use Deployment instead of creating Pods directly?

A Deployment manages Pods and maintains the desired number of replicas. It also supports rolling updates and replacement of failed Pods.

---

## Q3. What is a Kubernetes Service?

A Service provides a stable network endpoint for accessing a set of Pods.

---

## Q4. Why do we need a Service?

Pod IPs are temporary. A Service provides stable networking and load balancing across matching Pods.

---

## Q5. What is ClusterIP?

ClusterIP is the default Kubernetes Service type. It exposes the Service internally within the cluster.

---

## Q6. What is the difference between port and targetPort?

`port` is the port exposed by the Service.

`targetPort` is the port on the selected Pod/container where traffic is sent.

---

## Q7. What is a Namespace?

A Namespace provides logical isolation and organization of Kubernetes resources within a cluster.

---

## Q8. What are labels and selectors?

Labels identify Kubernetes objects.

Selectors are used by Kubernetes resources such as Deployments and Services to find objects with matching labels.

---

## Q9. What is a readiness probe?

A readiness probe determines whether a Pod is ready to receive traffic.

---

## Q10. What is a liveness probe?

A liveness probe determines whether an application is still alive. Repeated failure can cause Kubernetes to restart the container.

---

## Q11. What is a startup probe?

A startup probe allows an application time to initialize before liveness and readiness behavior becomes fully active.

It is particularly useful for applications with slow startup.

---

## Q12. What happens if readiness fails?

The Pod is removed from Service endpoints and stops receiving traffic.

The container is not necessarily restarted.

---

## Q13. What happens if liveness fails?

Kubernetes can restart the affected container.

---

## Q14. Why shouldn't liveness depend on PostgreSQL?

Liveness should generally answer whether the application itself is alive.

If PostgreSQL temporarily fails, restarting every application Pod can make the situation worse.

Readiness is generally more appropriate for determining whether the application should receive traffic when dependencies affect request handling.

---

## Q15. What is a Kubernetes Secret?

A Secret is a Kubernetes object designed to store sensitive configuration such as passwords, tokens, and credentials.

---

## Q16. Is Kubernetes Secret equivalent to Azure Key Vault?

No.

Kubernetes Secrets provide Kubernetes-native secret storage, but enterprise Azure environments often use Azure Key Vault with identity-based access for stronger centralized secret management.

---

## Q17. Why use resource requests?

Requests help Kubernetes scheduler determine whether a node has sufficient resources for a Pod.

---

## Q18. Why use resource limits?

Limits restrict the maximum resource consumption configured for a container.

---

## Q19. What is CrashLoopBackOff?

It means Kubernetes is repeatedly restarting a container that is failing to start or remain healthy, with increasing backoff between restart attempts.

---

## Q20. How do you troubleshoot CrashLoopBackOff?

Start with:

```powershell
kubectl logs <pod-name> -n order-dev
```

Then:

```powershell
kubectl describe pod <pod-name> -n order-dev
```

Check:

* Application logs
* Events
* Environment configuration
* Database connectivity
* Probe failures
* Resource limits

---

# 69. Production Evolution

Our current local architecture is intentionally simplified.

```text
Local:

Kubernetes
   |
   v
Order Service
   |
   v
Docker PostgreSQL
```

Eventually, production will become:

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
Istio Ingress Gateway
   |
   v
Order Service
   |
   v
Azure Database for PostgreSQL
```

Supporting services:

```text
Azure Key Vault
       |
       v
Managed Identity / Workload Identity

Application Insights
       |
       v
Azure Monitor
       |
       v
Log Analytics

Azure Container Registry
       |
       v
AKS
```

---

# 70. Important Local vs Production Differences

| Local Development         | Production Azure                |
| ------------------------- | ------------------------------- |
| Docker Desktop Kubernetes | AKS                             |
| Local Docker PostgreSQL   | Azure Database for PostgreSQL   |
| `host.docker.internal`    | Private Azure networking        |
| Local image               | Azure Container Registry        |
| Kubernetes Secret         | Azure Key Vault + identity      |
| Port-forward              | Ingress/API Management          |
| Plain Kubernetes          | Kubernetes + Istio              |
| Local Docker environment  | Azure VNet/network architecture |

The local environment is not intended to exactly reproduce production infrastructure.

Its purpose is to understand the concepts safely and cheaply before moving them to Azure.

---

# 71. Lesson 3 Final Verification

The following components have been verified successfully:

```text
Kubernetes Cluster
        ✅

order-dev Namespace
        ✅

order-db-secret
        ✅

Order Service Deployment
        ✅

Order Service Pod
        ✅

Spring Boot Container
        ✅

PostgreSQL Connectivity
        ✅

Order Service ClusterIP
        ✅

Service Endpoint
        ✅

Readiness Probe
        ✅

Liveness Probe
        ✅

Actuator Health
        ✅

kubectl Port Forward
        ✅
```

Health checks:

```text
/actuator/health
        → UP

/actuator/health/liveness
        → UP

/actuator/health/readiness
        → UP
```

---

# 72. Final Mental Model

The most important thing to remember from Lesson 3 is:

```text
Docker Image
     |
     v
Deployment
     |
     v
Pod
     |
     v
Container
     |
     v
Spring Boot Application
```

For networking:

```text
Client
   |
   v
Service
   |
   v
Pod
```

For health:

```text
Pod
 |
 +---- Readiness
 |       |
 |       +---- Should traffic be sent?
 |
 +---- Liveness
         |
         +---- Should container be restarted?
```

For secrets:

```text
Kubernetes Secret
       |
       v
Environment Variable
       |
       v
Spring Boot
```

For future production:

```text
Client
   |
   v
Entra ID
   |
   v
API Management
   |
   v
NGINX
   |
   v
Istio
   |
   v
Kubernetes Service
   |
   v
Order Service Pod
   |
   v
Managed PostgreSQL
```

---

# 73. Lesson 3 Completion

Lesson 3 successfully introduced the Order Service to Kubernetes.

We now understand:

* Kubernetes fundamentals
* Namespaces
* Pods
* Deployments
* Services
* ClusterIP
* Labels
* Selectors
* Service endpoints
* Kubernetes DNS
* Secrets
* Environment variables
* Readiness probes
* Liveness probes
* Startup probes
* Resource requests
* Resource limits
* Port forwarding
* Kubernetes troubleshooting
* Docker vs Kubernetes
* Kubernetes vs Istio
* Local vs production architecture

The Order Service is now successfully running in Kubernetes.

The next lesson will introduce **Istio service mesh**.

The first Istio flow will intentionally be:

```text
Client
   |
   v
Istio Ingress Gateway
   |
   v
Istio VirtualService
   |
   v
Order Service
```

We will initially exclude API Management and NGINX so that the Istio behavior can be understood independently.

Later, the complete production-style request path will be built:

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
Istio Ingress Gateway
   |
   v
Order Service
```

---

# End of Lesson 3

````

### Before committing

One small but important point: **I have deliberately not changed your current Deployment YAML yet to add `startupProbe`**, because the current deployment is already verified and I don't want to introduce a code/config change just before your commit without testing it.

So for now, your Lesson 3 documentation accurately records `startupProbe` as the **production improvement we identified**, rather than pretending we implemented and verified it.

Your current Git work should therefore be:

```powershell
git status
````

Then review:

```text
docs/lessons/lesson3.md
kubernetes/namespaces/order-dev.yaml
kubernetes/base/order-service/deployment.yaml
kubernetes/base/order-service/service.yaml
```

**Do not commit the actual Kubernetes Secret/password file**—we created that with `kubectl create secret`, which is the correct approach for this local lab.

Once you've pasted the document and run `git status`, send me the output. I'll review the changed files with you **before the commit**, then we'll make the Lesson 3 commit cleanly.
